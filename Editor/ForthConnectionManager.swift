//
//  ForthConnectionManager.swift
//  64Edit
//
//  Created by Tom's MacBook Air on 9/30/26.
//

import Foundation
import Combine
import AppKit

extension Notification.Name {
    /// Restart replaced `consoleTranscript`. Consoles copy it into the text view now.
    static let editForthConsoleReset = Notification.Name("EditForthConsoleReset")
}

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
    /// Transient line under "Engine connected". Cleared after a short delay.
    @Published private(set) var statusNote: String?
    private var statusNoteToken: UInt = 0
    @Published private(set) var consoleLines: [String] = []
    /// True while 64Forth ITC DEBUG / TDBG is waiting for step/continue/abort.
    @Published private(set) var isDebugSessionArmed = false
    /// True only while the stepper is sitting at a pause. Run-to / Continue clear it
    /// so Space and Return go to the program (GCLOCK) instead of Step Over.
    @Published private(set) var isDebugPaused = false
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

    /// How F5 / ⌘F5 / ⌘⇧F5 / RUN should fill the console.
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
        guard event.keyCode == 96 else { return nil } // F5
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
    /// Bumps when Restart replaces the whole console. The text view copies
    /// `consoleTranscript` itself; a form-feed in the emit buffer is not enough,
    /// because a later chunk can be drained without the clear ever painting.
    @Published private(set) var consoleResetSeq: UInt = 0
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
    /// Bumped when the sock client is dropped, so a late read cannot mark the next connection down.
    private var sockGeneration: UInt = 0
    /// True between launch and first successful sock connect (blocks re-entrant ping chatter).
    private var companionLaunchInFlight = false
    /// Raw companion emit stream for DockedConsoleView (not line-split).
    private var consoleEmitBuffer = ""
    /// Bundle URL of 64Forth launched via Start Forth this session (lifecycle terminate).
    private var launchedForthURL: URL?
    /// Retained so Process deinit does not SIGTERM the companion.
    private var companionProcess: Process?
    /// BYE started an editor quit. The sock close that follows must not
    /// show a connection error. Cleared if the user cancels the dirty-file sheets.
    private var forthQuitExpected = false
    /// Console line was BYE. If the companion then dies without requestQuit
    /// (a load fault can leave BYE exiting the process), quit the editor too.
    private var consoleByeOutstanding = false
    /// Editor asked the child to stop. Its exit must not start another quit.
    private var companionStopRequested = false
    /// Restart button: after the child exits, launch a fresh companion.
    private var relaunchAfterStop = false
    /// Sock drop during Restart is not a lost connection and not BYE.
    private var sockCloseIsRestart = false
    /// Restart already printed "Restarting Forth…". Skip "Starting EditForth…".
    private var omitStartingLine = false
    private var showConsoleOnNextConnect = false

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

    /// Replace the visible console with `text`. Docked and floating consoles
    /// copy this immediately; later emit only appends.
    private func replaceConsoleDisplay(_ text: String) {
        consoleTranscript = text
        consoleEmitBuffer = ""
        var lines = [""]
        for ch in text {
            if ch == "\n" || ch == "\r" {
                lines.append("")
            } else if ch != "\u{8}" {
                lines[lines.count - 1].append(ch)
            }
        }
        consoleLines = lines
        consoleEmitSeq &+= 1
        consoleResetSeq &+= 1
        consoleRefreshSeq &+= 1
        NotificationCenter.default.post(name: .editForthConsoleReset, object: self)
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

    /// Put `NAME` / `DEBUG NAME` / `BPGO NAME` on the console input line.
    /// `name` is a highlighted word. Empty uses LAST. Does not submit — Return runs the line.
    func prepareRunLine(_ kind: RunLineKind, name overrideName: String? = nil) {
        guard isConnected else {
            noteUserError("Forth is not connected")
            return
        }
        guard !isDebugSessionArmed else {
            noteUserError("debugger paused — use Step/Continue")
            return
        }
        if let raw = overrideName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.isEmpty,
           raw.rangeOfCharacter(from: .whitespacesAndNewlines) == nil {
            applyRunLine(kind, name: raw)
            return
        }
        pendingRunKind = kind
        send(.queryLastName)
    }

    private func applyRunLine(_ kind: RunLineKind, name: String) {
        let line: String
        switch kind {
        case .execute: line = name
        case .debug: line = "DEBUG \(name)"
        case .bpgo: line = "BPGO \(name)"
        }
        if consoleHidden {
            unhideForthConsole()
        }
        consoleFillText = line
        consoleFillSeq &+= 1
    }

    /// First paint of the empty console — keep banner in durable transcript too.
    func seedConsoleBannerIfEmpty(_ banner: String = EditForthConsoleBanner.text) {
        guard consoleTranscript.isEmpty, !banner.isEmpty else { return }
        consoleTranscript = banner
    }

    /// Drop buffered emit that is already reflected in `consoleTranscript` (remount / Restart).
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
        if showConsoleOnNextConnect {
            showConsoleOnNextConnect = false
            consoleHidden = false
        }
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

    /// Launch this same executable in headless companion mode (`--companion`).
    @discardableResult
    private func launchSixtyFourForth() -> Bool {
        guard let exe = SixtyFourForthLocator.locateBinary() else { return false }
        // Terminate a prior Ping companion before relaunch.
        terminateLaunchedCompanion()
        let task = Process()
        task.executableURL = exe
        task.arguments = ["--companion"]
        var env = ProcessInfo.processInfo.environment
        env["FORTH64_COMPANION"] = "1"
        task.environment = env
        task.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async {
                self?.companionExited(proc)
            }
        }
        do {
            companionStopRequested = false
            try task.run()
            companionProcess = task
            launchedForthURL = Bundle.main.bundleURL
            return true
        } catch {
            companionProcess = nil
            return false
        }
    }

    /// Companion left on its own (BYE's process exit). A crash keeps the editor.
    private func companionExited(_ proc: Process) {
        let requested = companionStopRequested
        let relaunch = relaunchAfterStop
        if companionProcess === proc {
            companionProcess = nil
            launchedForthURL = nil
        }
        if relaunch {
            relaunchAfterStop = false
            companionStopRequested = false
            companionLaunchInFlight = false
            ping()
            return
        }
        guard !requested else { return }
        guard proc.terminationReason == .exit else { return }
        forthQuitExpected = true
        consoleByeOutstanding = false
        NSApp.terminate(nil)
    }

    /// Fresh Forth image. Relaunches the companion this editor started.
    /// Does not close the editor, the file list, or open tabs.
    func restartCompanion() {
        guard !relaunchAfterStop else { return }
        sockCloseIsRestart = true
        forthQuitExpected = false
        consoleByeOutstanding = false
        launchConnectGeneration &+= 1
        pendingRunKind = nil
        lastError = nil
        isDebugSessionArmed = false
        isDebugPaused = false
        debugLocation = nil
        breakpointEntries = []
        disconnectSock(closeUndockedWindow: false)
        // Paint the wipe before the child is signaled, so shutdown is obvious
        // even while the new image is still launching.
        omitStartingLine = true
        replaceConsoleDisplay(EditForthConsoleBanner.text + "Restarting Forth…\n")

        companionStopRequested = true
        let dying = companionProcess
        companionProcess = nil
        launchedForthURL = nil
        if let dying, dying.isRunning {
            relaunchAfterStop = true
            dying.terminate()
            return
        }
        companionStopRequested = false
        companionLaunchInFlight = false
        ping()
    }

    /// Dirty-file Cancel after BYE. Forth stays up, so a later sock drop is a real error.
    func noteTerminateCancelled() {
        forthQuitExpected = false
        consoleByeOutstanding = false
    }

    /// Console Return. A bare BYE is remembered so a companion exit still quits
    /// the editor when requestQuit never arrives (after a load memory fault).
    func sendConsoleLine(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let first = trimmed.split(whereSeparator: { $0 == " " || $0 == "\t" }).first.map(String.init) ?? ""
        if first.caseInsensitiveCompare("bye") == .orderedSame {
            consoleByeOutstanding = true
        }
        send(.executeCommand(command: line))
    }

    /// Quit the companion process this editor launched.
    /// The companion is the same EditForth.app, so do not terminate by bundle id
    /// (that would quit the editor).
    func terminateLaunchedCompanion() {
        ForthConsoleWindowController.shared.closeQuietly()
        companionStopRequested = true
        if let proc = companionProcess, proc.isRunning {
            proc.terminate()
        }
        companionProcess = nil
        launchedForthURL = nil
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
                    self.lastError = self.lastError ?? "companion launched but edit.sock not ready"
                    self.appendConsole("Start Forth: launched companion, still not connected\n")
                    self.syncUndockedWindow()
                }
            }
        }
    }

    /// Drop the edit.sock client without terminating the companion process.
    private func disconnectSock(closeUndockedWindow: Bool) {
        sockGeneration &+= 1
        readSource?.cancel()
        readSource = nil
        fd = -1
        // Drop a partial line so the next companion does not parse it.
        // `incoming` is only appended on ioQueue; this runs after the in-flight read.
        ioQueue.async { [weak self] in
            self?.incoming.removeAll()
        }
        isConnected = false
        isDebugSessionArmed = false
        isDebugPaused = false
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

    func stepOver() {
        isDebugPaused = false
        send(.stepOver)
    }
    func stepInto() {
        isDebugPaused = false
        send(.stepInto)
    }
    func stepOut() {
        isDebugPaused = false
        send(.stepOut)
    }
    func resumeDebug() {
        isDebugPaused = false
        send(.resume)
    }
    func stopDebug() { send(.stop) }

    /// While Run-to / Continue is in progress, send a key to the program
    /// (graphics KEY if a window is open) instead of the stepper.
    /// `code` is the character the program sees: 13 Return, 32 Space, 27 Esc.
    func forwardProgramKey(_ code: Int32) {
        send(.pushKey(code: code))
    }

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
            isDebugPaused = false
            send(.armBreakGo)
            return
        }
        let explicit = (runWord ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let enabled = breakpointEntries.first(where: \.enabled)?.name
        let name = !explicit.isEmpty ? explicit : (enabled ?? "")
        guard !name.isEmpty,
              name.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
        else {
            lastError = "Arm needs a word to BPGO while idle"
            appendConsole("Arm: set a breakpoint, or put the caret on a word, or type BPGO <word>\n")
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
        isDebugPaused = false
        send(.runTo(offset: offset))
    }

    /// F9 / ⌘\: toggle BREAK on a dictionary word. Works while DEBUG is paused.
    func toggleBreakpoint(_ word: String) {
        let name = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              name.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
        else { return }
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
    /// If edit.sock is down, launches this same executable with `--companion`
    /// and retries connect.
    func ping() {
        let omitStarting = omitStartingLine
        omitStartingLine = false
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

        guard SixtyFourForthLocator.locateBinary() != nil else {
            lastError = "EditForth companion binary missing"
            appendConsole("Start Forth: companion binary missing\n")
            return
        }

        companionLaunchInFlight = true
        lastError = nil
        consoleHidden = false
        if !omitStarting {
            appendConsole("Starting EditForth…\n")
        }
        // Defer hosting the undocked window so we are not creating SwiftUI
        // views in the same turn as the appendConsole @Published bump.
        DispatchQueue.main.async { [weak self] in
            self?.syncUndockedWindow()
        }
        guard launchSixtyFourForth() else {
            companionLaunchInFlight = false
            lastError = "failed to launch Forth companion"
            appendConsole("Start Forth: failed to launch companion\n")
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
        let gen = sockGeneration
        var buf = [UInt8](repeating: 0, count: 16_384)
        let n = Darwin.read(fd, &buf, buf.count)
        if n <= 0 {
            DispatchQueue.main.async {
                guard self.sockGeneration == gen else { return }
                if self.sockCloseIsRestart {
                    self.sockCloseIsRestart = false
                    self.isConnected = false
                    self.isDebugSessionArmed = false
                    self.isDebugPaused = false
                    self.debugLocation = nil
                    self.breakpointEntries = []
                    self.lastError = nil
                    return
                }
                let expected = self.forthQuitExpected
                self.forthQuitExpected = false
                self.isConnected = false
                self.isDebugSessionArmed = false
                self.isDebugPaused = false
                self.debugLocation = nil
                self.breakpointEntries = []
                if expected || self.consoleByeOutstanding {
                    // App quit is in progress, or BYE killed the companion
                    // before requestQuit arrived. Do not show a connection error.
                    self.lastError = nil
                    if !expected {
                        self.forthQuitExpected = true
                        self.consoleByeOutstanding = false
                        NSApp.terminate(nil)
                    }
                } else {
                    self.consoleHidden = false
                    self.isForthDocked = self.preferDocked
                    self.lastError = "64Forth connection closed"
                }
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
            handleIncoming(line, generation: gen)
        }
    }

    private func handleIncoming(_ data: Data, generation: UInt) {
        do {
            let response = try IPCCodec.decodeResponse(data)
            DispatchQueue.main.async {
                // Restart bumps the generation before the child dies. Output
                // already queued from that socket must not refill the console.
                guard self.sockGeneration == generation else { return }
                self.apply(response)
            }
        } catch {
            DispatchQueue.main.async {
                guard self.sockGeneration == generation else { return }
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
        case .statusNote(let text):
            showStatusNote(text)
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
            if !armed { isDebugPaused = false }
            isDebugSessionArmed = armed
            if !armed {
                debugLocation = nil
                if lastError == "debugger not armed" {
                    lastError = nil
                }
            }
        case .debugLocation(let path, let line, let name, let off, let len):
            isDebugPaused = true
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
            applyRunLine(kind, name: trimmed)
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
            // BYE quits EditForth the same way as Cmd-Q, including dirty-file sheets.
            // Do not stop the companion here: Cancel must leave Forth running.
            // A confirmed quit stops that child from applicationShouldTerminate.
            lastError = nil
            forthQuitExpected = true
            consoleByeOutstanding = false
            isDebugSessionArmed = false
            isDebugPaused = false
            debugLocation = nil
            breakpointEntries = []
            NSApp.terminate(nil)
        }
    }

    /// Show `text` under "Engine connected" for 3 seconds. A newer note wins.
    private func showStatusNote(_ text: String) {
        let trimmed = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        statusNoteToken &+= 1
        let token = statusNoteToken
        statusNote = trimmed
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self, self.statusNoteToken == token else { return }
            self.statusNote = nil
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
