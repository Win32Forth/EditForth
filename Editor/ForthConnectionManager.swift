//
//  ForthConnectionManager.swift
//  64Edit
//
//  Created by Tom's MacBook Air on 9/30/26.
//

import Foundation
import Combine
import AppKit

final class ForthConnectionManager: NSObject, ObservableObject {
    static var socketURL: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return root.appendingPathComponent("64Forth", isDirectory: true)
            .appendingPathComponent("edit.sock")
    }

    struct DebugLocation: Equatable {
        var path: String
        /// 1-based line from the word's VIEW stamp.
        var line: Int
        /// Peek token name for editor highlight (empty when unknown).
        var name: String
        /// File-relative UTF-8 byte offset from dbg-map (0 = use name search).
        var off: Int
        /// Span length in bytes (0 = use name search).
        var len: Int
        /// Monotonic per sock message so SwiftUI onChange fires even when
        /// path/line/name/off/len repeat (e.g. consecutive 0/0 name fallbacks).
        var seq: UInt
    }

    @Published private(set) var isConnected = false
    @Published private(set) var lastError: String?
    @Published private(set) var consoleLines: [String] = []
    /// True while 64Forth ITC DEBUG / TDBG is waiting for step/continue/abort.
    @Published private(set) var isDebugSessionArmed = false
    /// Latest paused-word VIEW location from 64Forth (nil when not debugging).
    @Published private(set) var debugLocation: DebugLocation?
    /// Bumps when VIEW miss should fall back to in-editor find (`viewMissWord`).
    @Published private(set) var viewMissSeq: UInt = 0
    /// Token from the last `viewResult(opened: false)` (empty when none).
    @Published private(set) var viewMissWord: String = ""
    /// Bumps when companion bare EDIT asks EditForth to show its Open panel.
    @Published private(set) var editOpenRequestSeq: UInt = 0
    /// Bumps when companion bare FLOAD/INCLUDE asks EditForth for the Load panel.
    @Published private(set) var floadOpenRequestSeq: UInt = 0
    /// Bumps when companion bare CHDIR asks EditForth for the folder panel.
    @Published private(set) var chdirOpenRequestSeq: UInt = 0
    /// Companion logical working directory (CHDIR / boot). Used as NSOpenPanel start.
    @Published private(set) var forthWorkingDirectory: String = ""
    /// Pending panel start directory from the latest request*Open (may be FROMLIB Library).
    private(set) var pendingPanelStartDirectory: String = ""
    /// Bumps on successful VIEW so the console transcript can refresh even when
    /// `consoleLines` are unchanged (editor open/layout left the clip view blank).
    @Published private(set) var consoleRefreshSeq: UInt = 0
    /// Bumps when RUN / F5 family wants the console input line replaced (see `consoleFillText`).
    @Published private(set) var consoleFillSeq: UInt = 0
    /// Text for the editable console tail (no trailing newline — user presses Return).
    @Published private(set) var consoleFillText: String = ""
    /// BREAK table slots from the host (pale-red wash uses enabled names).
    @Published private(set) var breakpointEntries: [BreakpointEntry] = []

    /// How F5 / ⌘F5 / ⌘⇧F5 / RUN should fill the console from LAST.
    enum RunLineKind {
        /// `NAME` — user may prepend stack args, then Return.
        case execute
        /// `DEBUG NAME`
        case debug
        /// `BPGO NAME`
        case bpgo
    }

    private var pendingRunKind: RunLineKind?

    /// F5 keyCode 96 → run-line kind from chords. Nil if not F5 or Option/Control held.
    /// Unions `NSEvent.modifierFlags` because some F-key deliveries omit ⌘/⇧ on the event.
    static func runLineKind(from event: NSEvent) -> RunLineKind? {
        guard event.keyCode == 96 else { return nil }
        var flags = event.modifierFlags
        flags.formUnion(NSEvent.modifierFlags)
        let mods = flags.intersection(.deviceIndependentFlagsMask)
        if mods.contains(.option) || mods.contains(.control) { return nil }
        if mods.contains(.command), mods.contains(.shift) { return .bpgo }
        if mods.contains(.command) { return .debug }
        return .execute
    }

    /// RUN button click — read chords at click time (⌘ → DEBUG, ⌘⇧ → BPGO).
    static func runLineKindFromCurrentModifiers() -> RunLineKind {
        let mods = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if mods.contains(.command), mods.contains(.shift) { return .bpgo }
        if mods.contains(.command) { return .debug }
        return .execute
    }
    /// User preference: console under the status strip (true) vs floating window (false).
    /// `isForthDocked` is updated by dock/undock/hide/connect — not here — so
    /// init and preference writes do not nest a second `@Published` set.
    @Published var preferDocked: Bool {
        didSet {
            UserDefaults.standard.set(preferDocked, forKey: Self.preferDockedKey)
        }
    }
    /// True while the console is embedded under the status strip.
    @Published private(set) var isForthDocked = true
    /// Floating console was closed with the red traffic light — companion still runs.
    @Published private(set) var consoleHidden = false
    /// Bumps when companion console text arrives (DockedConsoleView drains via takeConsoleEmit).
    @Published private(set) var consoleEmitSeq: UInt = 0
    /// Durable full transcript for remount / Show Forth Console (not cleared by takeConsoleEmit).
    /// Not `@Published`: only `DockedConsoleView`’s coordinator reads it. Seeding from
    /// `makeNSView` must not publish or SwiftUI warns about view-update mutations.
    private(set) var consoleTranscript: String = ""
    /// Enabled BREAK names (pale-red wash).
    var breakpointNames: [String] {
        breakpointEntries.filter(\.enabled).map(\.name)
    }
    /// All BREAK names including disabled (panel list).
    var allBreakpointNames: [String] {
        breakpointEntries.map(\.name)
    }

    private static let preferDockedKey = "forthDocked"
    private var fd: Int32 = -1
    private var readSource: DispatchSourceRead?
    private let ioQueue = DispatchQueue(label: "com.Win32Forth.SixtyFourForth.edit-client")
    private var incoming = Data()
    private var debugLocationSeq: UInt = 0
    private var viewMissSeqCounter: UInt = 0
    /// Cancels an in-flight Start Forth launch reconnect when pressed again.
    private var launchConnectGeneration: UInt = 0
    /// True between launch and first successful sock connect (blocks re-entrant ping chatter).
    private var companionLaunchInFlight = false
    /// Raw companion emit stream for DockedConsoleView (not line-split).
    private var consoleEmitBuffer = ""
    /// Bundle URL of 64Forth launched via Start Forth this session (lifecycle terminate).
    private var launchedForthURL: URL?
    /// Retained so Process deinit does not SIGTERM the companion.
    private var companionProcess: Process?

    override init() {
        let docked: Bool = {
            if UserDefaults.standard.object(forKey: Self.preferDockedKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: Self.preferDockedKey)
        }()
        // Published(initialValue:) avoids @Published writes during @StateObject setup
        // ("Publishing changes from within view updates is not allowed").
        _preferDocked = Published(initialValue: docked)
        _isForthDocked = Published(initialValue: docked)
        super.init()
        ForthConsoleWindowController.shared.onRequestHide = { [weak self] in
            self?.hideForthConsole()
        }
    }

    /// Embed the companion console under the status strip; close the floating window.
    func dockForth() {
        consoleHidden = false
        preferDocked = true
        isForthDocked = true
        ForthConsoleWindowController.shared.closeQuietly()
    }

    /// Move the companion console into a floating titled window.
    func undockForth() {
        consoleHidden = false
        preferDocked = false
        isForthDocked = false
        ForthConsoleWindowController.shared.show(forth: self)
    }

    /// Red traffic light on the floating console — hide UI, keep companion running.
    func hideForthConsole() {
        guard isConnected else { return }
        consoleHidden = true
        preferDocked = false
        isForthDocked = false
        ForthConsoleWindowController.shared.closeQuietly()
    }

    /// Show the floating console again after a red-ball hide.
    func unhideForthConsole() {
        guard isConnected else { return }
        consoleHidden = false
        preferDocked = false
        isForthDocked = false
        ForthConsoleWindowController.shared.show(forth: self)
    }

    /// Keep floating window in sync after connect / preference changes.
    /// While a companion launch is in flight, keep the undocked window up so the
    /// EditForth banner and "Starting…" are visible before edit.sock connects.
    private func syncUndockedWindow() {
        if preferDocked || consoleHidden {
            ForthConsoleWindowController.shared.closeQuietly()
        } else if isConnected || companionLaunchInFlight {
            ForthConsoleWindowController.shared.show(forth: self)
        } else {
            ForthConsoleWindowController.shared.closeQuietly()
        }
    }

    /// Drain companion emit text since `lastSeq`. Updates `lastSeq` to `consoleEmitSeq`.
    func takeConsoleEmit(since lastSeq: inout UInt) -> String {
        guard consoleEmitSeq != lastSeq else { return "" }
        lastSeq = consoleEmitSeq
        let chunk = consoleEmitBuffer
        consoleEmitBuffer = ""
        return chunk
    }

    /// Forth menu CLS: wipe the embedded/floating console transcript (form-feed).
    func clearConsoleDisplay() {
        consoleTranscript = ""
        consoleLines = [""]
        consoleEmitBuffer = "\u{0c}"
        consoleEmitSeq &+= 1
        consoleRefreshSeq &+= 1
    }

    /// Editor-side refusal (no open tab, debugger armed, …) — sticky strip + console.
    /// Directory for EditForth NSOpenPanel: pending request path, else cached cwd, else Documents/EditForth.
    var panelStartURL: URL {
        let pending = pendingPanelStartDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        if !pending.isEmpty {
            return URL(fileURLWithPath: pending, isDirectory: true)
        }
        let cwd = forthWorkingDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cwd.isEmpty {
            return URL(fileURLWithPath: cwd, isDirectory: true)
        }
        return ForthMenuSupport.userTreeURL
    }

    func rememberWorkingDirectory(_ path: String) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        forthWorkingDirectory = trimmed
    }

    func noteUserError(_ message: String) {
        lastError = message
        appendConsole("Error: \(message)\n")
    }

    /// Non-error console note (e.g. Emitting…) — no red status strip.
    func noteInfo(_ message: String) {
        appendConsole("\(message)\n")
    }

    /// Query LAST and put `NAME` / `DEBUG NAME` / `BPGO NAME` on the console input line.
    /// Does not submit — user edits (e.g. stack args) and presses Return.
    func prepareRunLine(_ kind: RunLineKind) {
        guard isConnected else {
            noteUserError("Forth is not connected")
            return
        }
        guard !isDebugSessionArmed else {
            noteUserError("debugger paused — use Step/Continue")
            return
        }
        pendingRunKind = kind
        send(.queryLastName)
    }

    /// First paint of the empty console — keep banner in durable transcript too.
    func seedConsoleBannerIfEmpty(_ banner: String = EditForthConsoleBanner.text) {
        guard consoleTranscript.isEmpty, !banner.isEmpty else { return }
        consoleTranscript = banner
    }

    /// Drop buffered emit that is already reflected in `consoleTranscript` (remount).
    func discardPendingConsoleEmit(syncing lastSeq: inout UInt) {
        consoleEmitBuffer = ""
        lastSeq = consoleEmitSeq
    }

    func start() {
        guard fd < 0 else { return }

        let path = Self.socketURL.path
        guard FileManager.default.fileExists(atPath: path) else {
            lastError = "64Forth is not listening (\(path))"
            isConnected = false
            return
        }

        let cfd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard cfd >= 0 else {
            lastError = "socket() failed"
            return
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        path.withCString { cstr in
            withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
                let raw = UnsafeMutableRawPointer(ptr)
                _ = strncpy(raw.assumingMemoryBound(to: CChar.self), cstr, 104)
            }
        }

        let ok = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(cfd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        if ok != 0 {
            Darwin.close(cfd)
            lastError = "connect failed — start 64Forth first"
            isConnected = false
            return
        }

        fd = cfd
        isConnected = true
        companionLaunchInFlight = false
        isForthDocked = preferDocked && !consoleHidden
        lastError = nil
        // Defer: sock connect often lands during a SwiftUI update from ping().
        DispatchQueue.main.async { [weak self] in
            self?.syncUndockedWindow()
        }

        let src = DispatchSource.makeReadSource(fileDescriptor: cfd, queue: ioQueue)
        src.setEventHandler { [weak self] in
            self?.readAvailable()
        }
        src.setCancelHandler {
            Darwin.close(cfd)
        }
        src.resume()
        readSource = src
    }

    /// Companion `64Forth.app` matching this editor’s build flavor.
    /// Prefers the **EditForth** project’s 64Forth target (same Products / EditForth DerivedData),
    /// not the standalone Win32Forth/64Forth tree.
    /// **Debug:** sibling Products, then newest `EditForth-*` DerivedData Debug,
    /// then project-local `DerivedData/*/Build/Products/Debug/64Forth.app`.
    /// **Release:** sibling, then `/Applications/64Forth.app` (never Debug DerivedData).
    private func locateSixtyFourForthApp() -> URL? {
        let fm = FileManager.default

        func existsApp(_ url: URL) -> URL? {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
                return nil
            }
            return url
        }

        let sibling = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("64Forth.app", isDirectory: true)
        let applications = URL(fileURLWithPath: "/Applications/64Forth.app", isDirectory: true)

        func newestApp(inRoots roots: [URL], config: String) -> URL? {
            var candidates: [(url: URL, date: Date)] = []
            for root in roots {
                guard let dirs = try? fm.contentsOfDirectory(
                    at: root,
                    includingPropertiesForKeys: [.contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                ) else { continue }
                for dir in dirs {
                    let name = dir.lastPathComponent
                    // EditForth project DerivedData (Xcode default or -derivedDataPath folder).
                    guard name.hasPrefix("EditForth") else { continue }
                    let app = dir
                        .appendingPathComponent("Build/Products/\(config)/64Forth.app", isDirectory: true)
                    guard let url = existsApp(app) else { continue }
                    let vals = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                    candidates.append((url, vals?.contentModificationDate ?? .distantPast))
                }
            }
            return candidates.sorted(by: { $0.date > $1.date }).first?.url
        }

        func libraryDerivedDataCandidate(config: String) -> URL? {
            let home = fm.homeDirectoryForCurrentUser
            let dd = home.appendingPathComponent("Library/Developer/Xcode/DerivedData", isDirectory: true)
            return newestApp(inRoots: [dd], config: config)
        }

        /// Custom `-derivedDataPath DerivedData/...` under the EditForth repo.
        func projectLocalDerivedDataCandidate(config: String) -> URL? {
            var dir = Bundle.main.bundleURL
            for _ in 0..<12 {
                dir = dir.deletingLastPathComponent()
                let dd = dir.appendingPathComponent("DerivedData", isDirectory: true)
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: dd.path, isDirectory: &isDir), isDir.boolValue else {
                    continue
                }
                if let hit = newestApp(inRoots: [dd], config: config) {
                    return hit
                }
            }
            return nil
        }

        #if DEBUG
        if let s = existsApp(sibling) { return s }
        if let dd = libraryDerivedDataCandidate(config: "Debug") { return dd }
        if let local = projectLocalDerivedDataCandidate(config: "Debug") { return local }
        #else
        if let s = existsApp(sibling) { return s }
        if let a = existsApp(applications) { return a }
        #endif
        return nil
    }

    /// Launch this project’s 64Forth.app in headless companion mode (`--companion`).
    @discardableResult
    private func launchSixtyFourForth() -> Bool {
        guard let app = locateSixtyFourForthApp() else { return false }
        let exe = app.appendingPathComponent("Contents/MacOS/64Forth")
        guard FileManager.default.isExecutableFile(atPath: exe.path) else {
            // Fallback: Launch Services with arguments.
            let config = NSWorkspace.OpenConfiguration()
            config.arguments = ["--companion"]
            config.activates = false
            config.environment = ["FORTH64_COMPANION": "1"]
            NSWorkspace.shared.openApplication(at: app, configuration: config) { _, _ in }
            launchedForthURL = app
            return true
        }
        // Terminate a prior Ping companion before relaunch.
        terminateLaunchedCompanion()
        let task = Process()
        task.executableURL = exe
        task.arguments = ["--companion"]
        var env = ProcessInfo.processInfo.environment
        env["FORTH64_COMPANION"] = "1"
        task.environment = env
        do {
            try task.run()
            companionProcess = task
            launchedForthURL = app
            return true
        } catch {
            companionProcess = nil
            return false
        }
    }

    /// Quit the 64Forth we launched via Ping (EditForth lifecycle tie).
    func terminateLaunchedCompanion() {
        ForthConsoleWindowController.shared.closeQuietly()
        if let proc = companionProcess, proc.isRunning {
            proc.terminate()
            companionProcess = nil
        }
        guard let launched = launchedForthURL else { return }
        let matches = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == "com.win32forth.SixtyFourForth"
                && $0.bundleURL?.standardizedFileURL == launched.standardizedFileURL
        }
        for app in matches {
            app.terminate()
        }
        launchedForthURL = nil
        companionProcess = nil
    }

    /// After launching Forth, retry `start()` until sock connects or attempts run out.
    private func scheduleLaunchConnectRetries() {
        launchConnectGeneration &+= 1
        let gen = launchConnectGeneration
        let delays: [TimeInterval] = [0.4, 0.8, 1.2, 1.6, 2.0, 2.5, 3.0, 4.0, 5.0]
        for (i, delay) in delays.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.launchConnectGeneration == gen else { return }
                if self.isConnected {
                    self.companionLaunchInFlight = false
                    return
                }
                // Tear down a half-open sock without closing the undocked console window
                // (remount would race Autoload emit and drop the EditForth banner).
                if self.fd >= 0 { self.disconnectSock(closeUndockedWindow: false) }
                self.start()
                if self.isConnected {
                    self.lastError = nil
                    self.companionLaunchInFlight = false
                    return
                }
                if i == delays.count - 1 {
                    self.companionLaunchInFlight = false
                    self.lastError = self.lastError ?? "64Forth launched but edit.sock not ready"
                    self.appendConsole("Start Forth: launched 64Forth, still not connected\n")
                    self.syncUndockedWindow()
                }
            }
        }
    }

    /// Drop the edit.sock client without terminating the companion process.
    private func disconnectSock(closeUndockedWindow: Bool) {
        readSource?.cancel()
        readSource = nil
        fd = -1
        isConnected = false
        isDebugSessionArmed = false
        debugLocation = nil
        breakpointEntries = []
        if closeUndockedWindow {
            ForthConsoleWindowController.shared.closeQuietly()
        }
    }

    func stop() {
        companionLaunchInFlight = false
        launchConnectGeneration &+= 1
        disconnectSock(closeUndockedWindow: true)
        consoleHidden = false
        isForthDocked = preferDocked
    }

    func stepOver() { send(.stepOver) }
    func stepInto() { send(.stepInto) }
    func stepOut() { send(.stepOut) }
    func resumeDebug() { send(.resume) }
    func stopDebug() { send(.stop) }

    /// Break Now: pause at the next ITC token whose enclosing colon is at/above
    /// DEBUGGER-END. Works while free-running or during Continue/BPGO/Run-to.
    func breakAsap() {
        if fd < 0 { start() }
        guard fd >= 0 else {
            lastError = lastError ?? "64Forth is not listening — start 64Forth first"
            return
        }
        lastError = nil
        send(.breakAsap)
    }

    /// Remove a BREAK slot (works while paused).
    func removeBreakpoint(_ word: String) {
        let name = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              name.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
        else { return }
        if fd < 0 { start() }
        guard fd >= 0 else {
            lastError = lastError ?? "64Forth is not listening — start 64Forth first"
            return
        }
        lastError = nil
        send(.removeBreakpoint(name: name))
    }

    /// Enable or disable a BREAK without removing it (works while paused).
    func setBreakpointEnabled(_ word: String, enabled: Bool) {
        let name = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              name.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
        else { return }
        if fd < 0 { start() }
        guard fd >= 0 else {
            lastError = lastError ?? "64Forth is not listening — start 64Forth first"
            return
        }
        lastError = nil
        send(.setBreakpointEnabled(name: name, enabled: enabled))
    }

    /// Idle: `BPGO <name>`. Paused: set go-until-break and Continue.
    func armBreakGo(runWord: String? = nil) {
        if fd < 0 { start() }
        guard fd >= 0 else {
            lastError = lastError ?? "64Forth is not listening — start 64Forth first"
            appendConsole("Arm: not connected\n")
            return
        }
        lastError = nil
        if isDebugSessionArmed {
            send(.armBreakGo)
            return
        }
        let name = (runWord ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              name.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
        else {
            lastError = "Arm needs a word to BPGO while idle"
            appendConsole("Arm: pick a breakpoint or type BPGO <word>\n")
            return
        }
        send(.breakGo(name: name))
    }

    /// Paused Run to Here: UTF-8 file-relative byte offset of the clicked token.
    /// Host resolves via dbg-map; map miss replies with `.error` (alert in UI).
    func runTo(offset: Int) {
        guard isDebugSessionArmed else {
            lastError = "debugger not armed"
            appendConsole("Run to: debugger not armed\n")
            return
        }
        guard offset >= 0 else {
            lastError = "runto: invalid offset"
            return
        }
        if fd < 0 { start() }
        guard fd >= 0 else {
            lastError = lastError ?? "64Forth is not listening — start 64Forth first"
            return
        }
        lastError = nil
        send(.runTo(offset: offset))
    }

    /// F9 / ⌘\: toggle BREAK on a dictionary word via `TOGGLE-BREAK` on the host.
    /// Refuses while DEBUG is paused (host cannot evaluate then).
    func toggleBreakpoint(_ word: String) {
        let name = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              name.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
        else { return }
        if isDebugSessionArmed {
            lastError = "debugger paused — use Step/Continue"
            appendConsole("BREAK \(name): debugger paused\n")
            return
        }
        if fd < 0 {
            start()
        }
        guard fd >= 0 else {
            lastError = lastError ?? "64Forth is not listening — start 64Forth first"
            appendConsole("BREAK: not connected\n")
            return
        }
        lastError = nil
        send(.toggleBreakpoint(name: name))
    }

    /// ⌘-click goto-source: `viewWord` over edit.sock → `viewResult`.
    /// On miss (`opened: false`) or when disconnected, bumps `viewMissSeq` so the
    /// UI searches the editor. Refuses while DEBUG is paused (host rejects evaluate).
    func viewWord(_ word: String) {
        let name = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              name.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
        else { return }
        if isDebugSessionArmed {
            lastError = "debugger paused — use Step/Continue"
            appendConsole("VIEW \(name): debugger paused\n")
            return
        }
        if fd < 0 {
            start()
        }
        guard fd >= 0 else {
            lastError = lastError ?? "64Forth is not listening — start 64Forth first"
            // Local note needs a CR so later console lines do not smash onto it.
            appendConsole("Hyper: not connected\n")
            // No Forth dictionary — fall back to in-file find for the clicked token.
            viewMissWord = name
            viewMissSeqCounter &+= 1
            viewMissSeq = viewMissSeqCounter
            return
        }
        lastError = nil
        send(.viewWord(name: name))
    }

    /// Reconnect only — never evaluates Forth (safe while DEBUG is paused).
    /// If edit.sock is down, launches this EditForth project’s 64Forth.app
    /// (Debug→sibling / EditForth DerivedData; Release→sibling or `/Applications`)
    /// and retries connect.
    func ping() {
        // Banner before any "Starting…" so undocked (window mounts later) still
        // restores `=== EditForth … ===` from consoleTranscript.
        seedConsoleBannerIfEmpty()

        if fd >= 0, !isConnected {
            disconnectSock(closeUndockedWindow: false)
        }
        if fd < 0 {
            start()
        }
        if isConnected {
            companionLaunchInFlight = false
            lastError = nil
            return
        }
        // SwiftUI may call onAppear/onChange twice — one launch, one "Starting…".
        if companionLaunchInFlight {
            return
        }

        #if DEBUG
        let missingHint = "64Forth Debug not found — Product → Build (EditForth scheme builds 64Forth too)"
        #else
        let missingHint = "64Forth not found — install beside EditForth or in /Applications"
        #endif
        guard locateSixtyFourForthApp() != nil else {
            lastError = missingHint
            appendConsole("Start Forth: \(missingHint)\n")
            return
        }

        companionLaunchInFlight = true
        lastError = nil
        consoleHidden = false
        appendConsole("Starting EditForth…\n")
        // Defer hosting the undocked window so we are not creating SwiftUI
        // views in the same turn as the appendConsole @Published bump.
        DispatchQueue.main.async { [weak self] in
            self?.syncUndockedWindow()
        }
        guard launchSixtyFourForth() else {
            companionLaunchInFlight = false
            lastError = "failed to launch 64Forth"
            appendConsole("Start Forth: failed to launch 64Forth\n")
            DispatchQueue.main.async { [weak self] in
                self?.syncUndockedWindow()
            }
            return
        }
        scheduleLaunchConnectRetries()
    }

    func send(_ request: EditorRequest) {
        if fd < 0 {
            start()
        }
        guard fd >= 0 else { return }

        do {
            var data = try IPCCodec.encodeRequest(request)
            data.append(0x0A)
            let n = data.withUnsafeBytes { raw in
                Darwin.write(self.fd, raw.baseAddress, data.count)
            }
            if n < 0 {
                DispatchQueue.main.async {
                    self.lastError = "write failed"
                    self.isConnected = false
                }
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func readAvailable() {
        var buf = [UInt8](repeating: 0, count: 16_384)
        let n = Darwin.read(fd, &buf, buf.count)
        if n <= 0 {
            DispatchQueue.main.async {
                self.isConnected = false
                self.consoleHidden = false
                self.isForthDocked = self.preferDocked
                self.isDebugSessionArmed = false
                self.debugLocation = nil
                self.breakpointEntries = []
                self.lastError = "64Forth connection closed"
                ForthConsoleWindowController.shared.closeQuietly()
            }
            readSource?.cancel()
            readSource = nil
            fd = -1
            return
        }
        incoming.append(contentsOf: buf.prefix(Int(n)))
        while let range = incoming.firstIndex(of: 10) {
            let line = incoming.subdata(in: incoming.startIndex..<range)
            incoming.removeSubrange(incoming.startIndex...range)
            guard !line.isEmpty else { continue }
            handleIncoming(line)
        }
    }

    private func handleIncoming(_ data: Data) {
        do {
            let response = try IPCCodec.decodeResponse(data)
            DispatchQueue.main.async {
                self.apply(response)
            }
        } catch {
            DispatchQueue.main.async {
                self.lastError = error.localizedDescription
                self.appendConsole("Bad response: \(error.localizedDescription)")
            }
        }
    }

    private func apply(_ response: ForthResponse) {
        switch response {
        case .consoleOutput(let text):
            // Empty payload is the executeCommand success/BYE ack from the
            // companion — clear a sticky red strip after a clean Return.
            if text.isEmpty {
                lastError = nil
            }
            appendConsole(text)
        case .breakpointHit(let line, let stackTrace):
            appendConsole("BREAK line \(line)")
            stackTrace.forEach { appendConsole("  \($0)") }
        case .variableChanged(let name, let value):
            appendConsole("\(name) = \(value)")
        case .executionFinished(let exitCode):
            appendConsole("Finished (\(exitCode))")
        case .error(let message):
            // Late duplicate step/resume after disarm is a race, not a connection
            // failure — keep it out of the sticky red status line.
            if message == "debugger not armed" {
                return
            }
            // Forth evaluate faults (status=-1, etc.) already print the real
            // message in the console ("memory access error"). Do not pin the
            // opaque status=N string under "Engine connected".
            if message.hasPrefix("status=") || message.hasPrefix("load status=") {
                appendConsole("Error: \(message)")
                return
            }
            lastError = message
            // Ensure Run to errors end with a newline in the console transcript.
            if message.hasSuffix("\n") {
                appendConsole("Error: \(message)")
            } else {
                appendConsole("Error: \(message)\n")
            }
        case .debugSession(let armed):
            isDebugSessionArmed = armed
            if !armed {
                debugLocation = nil
                if lastError == "debugger not armed" {
                    lastError = nil
                }
            }
        case .debugLocation(let path, let line, let name, let off, let len):
            // A pause location implies the stepper is live; arm immediately so
            // letter keys do not race the debugSession poll / paint notify.
            isDebugSessionArmed = true
            if lastError == "debugger not armed" {
                lastError = nil
            }
            debugLocationSeq &+= 1
            debugLocation = DebugLocation(
                path: path,
                line: line,
                name: name,
                off: off,
                len: len,
                seq: debugLocationSeq
            )
        case .viewResult(let word, let opened):
            if opened {
                lastError = nil
                // Editor/tab layout after EDIT-AT can leave the transcript unpainted
                // until a scroll event — force ConsoleTranscriptView to refresh.
                consoleRefreshSeq &+= 1
            } else {
                // Expected miss (undefined or no VIEW stamp) — search the editor.
                lastError = nil
                appendConsole("VIEW \(word): no source — searching editor\n")
                viewMissWord = word
                viewMissSeqCounter &+= 1
                viewMissSeq = viewMissSeqCounter
            }
        case .breakpoints(let entries):
            breakpointEntries = entries
        case .lastName(let name):
            guard let kind = pendingRunKind else { return }
            pendingRunKind = nil
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                noteUserError("LAST has no name")
                return
            }
            let line: String
            switch kind {
            case .execute: line = trimmed
            case .debug: line = "DEBUG \(trimmed)"
            case .bpgo: line = "BPGO \(trimmed)"
            }
            // Ensure a console can receive the fill (hidden floating → show).
            if consoleHidden {
                unhideForthConsole()
            }
            consoleFillText = line
            consoleFillSeq &+= 1
        case .dockState:
            // Legacy window-dock ack — editor owns dock/undock via preferDocked.
            isForthDocked = preferDocked
        case .requestEditOpen(let startDirectory):
            rememberWorkingDirectory(startDirectory)
            pendingPanelStartDirectory = startDirectory
            editOpenRequestSeq &+= 1
        case .requestFloadOpen(let startDirectory):
            rememberWorkingDirectory(startDirectory)
            pendingPanelStartDirectory = startDirectory
            floadOpenRequestSeq &+= 1
        case .requestChdirOpen(let startDirectory):
            rememberWorkingDirectory(startDirectory)
            pendingPanelStartDirectory = startDirectory
            chdirOpenRequestSeq &+= 1
        case .cwdChanged(let path):
            rememberWorkingDirectory(path)
        case .requestQuit:
            // BYE from companion: same path as Cmd-Q (dirty Save sheets, then
            // terminateLaunchedCompanion via AppDelegate).
            lastError = nil
            NSApp.activate(ignoringOtherApps: true)
            NSApp.terminate(nil)
        }
    }

    /// Stream console text like 64Forth's ConsoleView: mid-line chunks stay on the
    /// current line, and BS (0x08) erases the DEBUG block cursor (U+2588).
    /// Also feeds the raw emit buffer for DockedConsoleView.
    private func appendConsole(_ text: String) {
        guard !text.isEmpty else { return }
        if text.contains("\u{0c}") {
            consoleTranscript = text.replacingOccurrences(of: "\u{0c}", with: "")
        } else {
            consoleTranscript.append(text)
        }
        consoleEmitBuffer.append(text)
        // Defer @Published bumps so SwiftUI is not mid-update (e.g. ping from
        // onAppear nesting DockedConsoleView makeNSView).
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.consoleEmitSeq &+= 1
            var lines = self.consoleLines
            if lines.isEmpty {
                lines.append("")
            }
            for ch in text {
                if ch == "\u{8}" {
                    if !lines[lines.count - 1].isEmpty {
                        lines[lines.count - 1].removeLast()
                    }
                } else if ch == "\n" || ch == "\r" {
                    lines.append("")
                } else {
                    lines[lines.count - 1].append(ch)
                }
            }
            self.consoleLines = lines
        }
    }
}
