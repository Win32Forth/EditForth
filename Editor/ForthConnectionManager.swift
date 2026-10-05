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
    /// Bumps on successful VIEW so the console transcript can refresh even when
    /// `consoleLines` are unchanged (editor open/layout left the clip view blank).
    @Published private(set) var consoleRefreshSeq: UInt = 0
    /// BREAK table slots from the host (pale-red wash uses enabled names).
    @Published private(set) var breakpointEntries: [BreakpointEntry] = []
    /// User preference: console under Ping (true) vs floating undocked window (false).
    @Published var preferDocked: Bool {
        didSet {
            UserDefaults.standard.set(preferDocked, forKey: Self.preferDockedKey)
            isForthDocked = preferDocked
        }
    }
    /// True while the console is embedded under Ping (false = floating undocked window).
    @Published private(set) var isForthDocked = true
    /// Bumps when companion console text arrives (DockedConsoleView drains via takeConsoleEmit).
    @Published private(set) var consoleEmitSeq: UInt = 0
    /// Durable full transcript for remount / Show Forth Console (not cleared by takeConsoleEmit).
    @Published private(set) var consoleTranscript: String = ""
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
    /// Cancels an in-flight Ping launch reconnect when Ping is pressed again.
    private var launchConnectGeneration: UInt = 0
    /// Raw companion emit stream for DockedConsoleView (not line-split).
    private var consoleEmitBuffer = ""
    /// Bundle URL of 64Forth launched via Ping this session (lifecycle terminate).
    private var launchedForthURL: URL?
    /// Retained so Process deinit does not SIGTERM the companion.
    private var companionProcess: Process?

    override init() {
        if UserDefaults.standard.object(forKey: Self.preferDockedKey) == nil {
            preferDocked = true
        } else {
            preferDocked = UserDefaults.standard.bool(forKey: Self.preferDockedKey)
        }
        super.init()
        isForthDocked = preferDocked
        ForthConsoleWindowController.shared.onRequestDock = { [weak self] in
            self?.dockForth()
        }
    }

    /// Embed the companion console under Ping; close the floating window.
    func dockForth() {
        preferDocked = true
        ForthConsoleWindowController.shared.closeQuietly()
    }

    /// Move the companion console into a floating titled window.
    func undockForth() {
        preferDocked = false
        ForthConsoleWindowController.shared.show(forth: self)
    }

    /// Keep floating window in sync after connect / preference changes.
    private func syncUndockedWindow() {
        if preferDocked {
            ForthConsoleWindowController.shared.closeQuietly()
        } else if isConnected {
            ForthConsoleWindowController.shared.show(forth: self)
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
        isForthDocked = preferDocked
        lastError = nil
        syncUndockedWindow()

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
                if self.isConnected { return }
                if self.fd >= 0 { self.stop() }
                self.start()
                if self.isConnected {
                    self.lastError = nil
                    return
                }
                if i == delays.count - 1 {
                    self.lastError = self.lastError ?? "64Forth launched but edit.sock not ready"
                    self.appendConsole("ping: launched 64Forth, still not connected\n")
                }
            }
        }
    }

    func stop() {
        readSource?.cancel()
        readSource = nil
        fd = -1
        isConnected = false
        isForthDocked = preferDocked
        isDebugSessionArmed = false
        debugLocation = nil
        breakpointEntries = []
    }

    func stepOver() { send(.stepOver) }
    func stepInto() { send(.stepInto) }
    func stepOut() { send(.stepOut) }
    func resumeDebug() { send(.resume) }
    func stopDebug() { send(.stop) }

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
        if fd >= 0, !isConnected {
            stop()
        }
        if fd < 0 {
            start()
        }
        if isConnected {
            lastError = nil
            return
        }

        #if DEBUG
        let missingHint = "64Forth Debug not found — Product → Build (EditForth scheme builds 64Forth too)"
        #else
        let missingHint = "64Forth not found — install beside EditForth or in /Applications"
        #endif
        guard locateSixtyFourForthApp() != nil else {
            lastError = missingHint
            appendConsole("ping: \(missingHint)\n")
            return
        }

        appendConsole("Launching companion 64Forth…\n")
        lastError = nil
        guard launchSixtyFourForth() else {
            lastError = "failed to launch companion 64Forth"
            appendConsole("ping: failed to launch companion 64Forth\n")
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
                self.isForthDocked = self.preferDocked
                self.isDebugSessionArmed = false
                self.debugLocation = nil
                self.breakpointEntries = []
                self.lastError = "64Forth connection closed"
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
            lastError = message
            appendConsole("Error: \(message)")
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
        case .dockState:
            // Legacy window-dock ack — editor owns dock/undock via preferDocked.
            isForthDocked = preferDocked
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
        consoleEmitSeq &+= 1
        var lines = consoleLines
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
        consoleLines = lines
    }
}
