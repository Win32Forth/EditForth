//
//  ForthEditorServer.swift
//  64Forth
//
//  Created by Tom's MacBook Air on 9/30/26.
//

import Foundation
import CoreGraphics

final class ForthEditorServer {
    static let shared = ForthEditorServer()
    static let socketFileName = "edit.sock"

    static var socketURL: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return root.appendingPathComponent("64Forth", isDirectory: true)
            .appendingPathComponent(socketFileName)
    }

    private init() {}

    private var serverFD: Int32 = -1
    private var source: DispatchSourceRead?
    private let queue = DispatchQueue(label: "com.64forth.editor-server")
    private var clients: [Int32] = []
    private var clientSources: [Int32: DispatchSourceRead] = [:]
    private var debugPoll: DispatchSourceTimer?
    private var lastDebugArmed = false
    /// Tail of console text for late sock clients (DEBUG often opens 64Edit after first prints).
    private var recentConsole = ""
    private let recentConsoleMax = 32_768
    /// Last broadcast console chunk ended with CR/LF (or clear). Used so `ok(n)>` starts on its own line after bare TYPE (e.g. `.`).
    /// Updated on the calling thread (under lock) so `broadcastOkPrompt` sees TYPE before the async sock write.
    private let emitLock = NSLock()
    private var emitEndsWithNewline = true
    /// Bumped in `noteConsoleEmit` so executeCommand can tell “Forth printed” vs silence.
    private var emitGeneration: UInt = 0

    /// True when at least one 64Edit sock client is connected (edit.sock).
    /// Used to skip `open -a` on DEBUG/EDIT when the editor can take pending-goto
    /// or `debugLocation` without a Launch Services reactivation flash.
    var hasConnectedClients: Bool {
        queue.sync { !clients.isEmpty }
    }

    func start() {
        // Belt-and-suspenders with SO_NOSIGPIPE on each client: a write to a
        // closed 64Edit sock must never kill 64Forth (DEBUG abort after editor quit).
        signal(SIGPIPE, SIG_IGN)

        let dir = Self.socketURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = Self.socketURL.path
        try? FileManager.default.removeItem(atPath: path)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        path.withCString { cstr in
            withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
                let raw = UnsafeMutableRawPointer(ptr)
                _ = strncpy(raw.assumingMemoryBound(to: CChar.self), cstr, 104)
            }
        }

        let bindOk = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindOk == 0, Darwin.listen(fd, 4) == 0 else {
            Darwin.close(fd)
            return
        }

        serverFD = fd
        let src = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        src.setEventHandler { [weak self] in
            self?.acceptClient()
        }
        src.resume()
        source = src

        let kernel = KernelBridge.shared
        let previous = kernel.onEmit
        kernel.onEmit = { chunk in
            previous?(chunk)
            ForthEditorServer.shared.broadcast(.consoleOutput(text: chunk))
        }

        startDebugSessionPoll()
    }

    /// Watch `kernel_any_debug_armed` and push `.debugSession` on edges.
    private func startDebugSessionPoll() {
        debugPoll?.cancel()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + .milliseconds(100), repeating: .milliseconds(100))
        t.setEventHandler { [weak self] in
            self?.pollDebugSession()
        }
        t.resume()
        debugPoll = t
    }

    private func pollDebugSession() {
        let armed = KernelBridge.shared.isAnyDebugArmed
        guard armed != lastDebugArmed else { return }
        lastDebugArmed = armed
        if !armed {
            DispatchQueue.main.async {
                FileHost.shared.clearDebugReveal()
            }
        }
        for fd in clients {
            writeResponse(.debugSession(armed: armed), to: fd)
        }
    }

    /// Push `debugSession(armed: true)` as soon as a pause paints, so 64Edit
    /// letter keys do not wait on the 100ms poll edge (first `i` / Switch to Edit).
    func notifyDebugSessionArmed() {
        queue.async {
            guard KernelBridge.shared.isAnyDebugArmed else { return }
            guard !self.lastDebugArmed else { return }
            self.lastDebugArmed = true
            for fd in self.clients {
                self.writeResponse(.debugSession(armed: true), to: fd)
            }
        }
    }

    private func acceptClient() {
        let cfd = Darwin.accept(serverFD, nil, nil)
        guard cfd >= 0 else { return }

        // Writing to a closed 64Edit sock must not SIGPIPE-kill 64Forth (e.g. quit
        // editor while DEBUG is still paused, then abort from the console).
        var on: Int32 = 1
        _ = setsockopt(cfd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout.size(ofValue: on)))

        clients.append(cfd)

        let src = DispatchSource.makeReadSource(fileDescriptor: cfd, queue: queue)
        src.setEventHandler { [weak self] in
            self?.readClient(cfd)
        }
        src.setCancelHandler {
            Darwin.close(cfd)
        }
        src.resume()
        clientSources[cfd] = src
        NSLog("64Forth editor server: client fd=%d", cfd)

        // Replay recent console so a late connect (e.g. DEBUG open) sees the pause banner.
        if !recentConsole.isEmpty {
            writeResponse(.consoleOutput(text: recentConsole), to: cfd)
        }
        // Sync current stepper state so a late connect sees an active session.
        let armed = KernelBridge.shared.isAnyDebugArmed
        lastDebugArmed = armed
        writeResponse(.debugSession(armed: armed), to: cfd)
        // Sync BREAK table so pale-red wash matches the host.
        writeResponse(.breakpoints(entries: KernelBridge.shared.breakEntries()), to: cfd)
        // Sync logical cwd so EditForth Open/FLOAD/CHDIR panels start there.
        writeResponse(.cwdChanged(path: FileHost.shared.logicalCurrentDirectory), to: cfd)
    }

    private func dropClient(_ fd: Int32) {
        clients.removeAll { $0 == fd }
        if let src = clientSources.removeValue(forKey: fd) {
            src.cancel()
        }
    }

    private func readClient(_ fd: Int32) {
        var buf = [UInt8](repeating: 0, count: 16_384)
        let n = Darwin.read(fd, &buf, buf.count)
        if n <= 0 {
            dropClient(fd)
            return
        }

        NSLog("64Forth editor server: read %d bytes", n)
        let data = Data(buf.prefix(Int(n)))
        for line in data.split(separator: 10) where !line.isEmpty {
            handleLine(Data(line), fd: fd)
        }
    }

    private func handleLine(_ data: Data, fd: Int32) {
        NSLog("64Forth editor server: request %s", String(data: data, encoding: .utf8) ?? "?")
        let request: EditorRequest
        do {
            request = try IPCCodec.decodeRequest(data)
        } catch {
            writeResponse(.error(message: error.localizedDescription), to: fd)
            return
        }

        let kernel = KernelBridge.shared

        // Stepper keys must not wait behind a blocking evaluate on the main queue.
        // DEBUG started from the editor console holds main inside evaluate()'s pump;
        // pushKey is lock-safe from this I/O queue and wakes the Forth KEY wait.
        switch request {
        case .stepOver:
            if !kernel.debugStepOver() {
                writeResponse(.error(message: "debugger not armed"), to: fd)
            }
            return
        case .stepInto:
            if !kernel.debugStepInto() {
                writeResponse(.error(message: "debugger not armed"), to: fd)
            }
            return
        case .stepOut:
            if !kernel.debugStepOut() {
                writeResponse(.error(message: "debugger not armed"), to: fd)
            }
            return
        case .resume:
            if !kernel.debugResume() {
                writeResponse(.error(message: "debugger not armed"), to: fd)
            }
            return
        case .stop:
            // Abort while paused (pushKey q). If not in a live pause KEY wait
            // (e.g. Break ASAP fault left armed=1 but evaluate already ended),
            // force-disarm so the editor does not stay stuck on "debugging".
            if !kernel.debugAbort() {
                kernel.debugForceDisarm()
                writeResponse(.debugSession(armed: false), to: fd)
            }
            return
        case .armBreakGo:
            // Paused: set go-until-break then Continue (no evaluate).
            if !kernel.debugArmBreakGo() {
                writeResponse(.error(message: "debugger not armed"), to: fd)
            }
            return
        case .runTo(let offset):
            // Paused Run to Here: resolve on pause thread (key 135); no evaluate.
            if let err = kernel.debugRunTo(offset: offset) {
                writeResponse(.error(message: err), to: fd)
            }
            return
        case .breakAsap:
            // Break Now: set sticky flag; Forth NEXT seeks past DEBUGGER-END.
            // Must run on this I/O queue while evaluating (not executeCommand).
            if let err = kernel.debugBreakAsap() {
                writeResponse(.error(message: err), to: fd)
            }
            return
        case .removeBreakpoint(let name):
            let word = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if word.isEmpty || word.contains(where: { $0.isWhitespace || $0.isNewline }) {
                writeResponse(.error(message: "BREAK needs a single token"), to: fd)
            } else if !kernel.breakClear(named: word) {
                writeResponse(.error(message: "BREAK \(word) not set"), to: fd)
            } else {
                let entries = kernel.breakEntries()
                broadcast(.breakpoints(entries: entries))
                writeResponse(.breakpoints(entries: entries), to: fd)
            }
            return
        case .setBreakpointEnabled(let name, let enabled):
            let word = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if word.isEmpty || word.contains(where: { $0.isWhitespace || $0.isNewline }) {
                writeResponse(.error(message: "BREAK needs a single token"), to: fd)
            } else if !kernel.breakSetEnabled(named: word, enabled: enabled) {
                writeResponse(.error(message: "BREAK \(word) not set"), to: fd)
            } else {
                let entries = kernel.breakEntries()
                broadcast(.breakpoints(entries: entries))
                writeResponse(.breakpoints(entries: entries), to: fd)
            }
            return
        case .dock:
            // EditForth embeds the console; ignore legacy window-dock requests.
            writeResponse(.dockState(docked: true), to: fd)
            return
        case .undock:
            writeResponse(.dockState(docked: false), to: fd)
            return
        case .pushKey(let code):
            // GRAPHICS KEY/KEY? read AppOutputHost's queue. Only while App Output
            // is open — idle console typing must not fill that queue or KEY?
            // returns true immediately and demos freeze after one frame.
            if AppOutputHost.shared.isOpened {
                AppOutputHost.shared.enqueueKey(Int64(code))
            }
            if !kernel.pushKey(code) {
                // Not waiting for console KEY — ignore quietly when idle.
            }
            return
        case .queryLastName:
            writeResponse(.lastName(name: kernel.lastDefinedName() ?? ""), to: fd)
            return
        case .updateUserTree:
            // FileHost copies from this app's Resources into Documents/EditForth.
            DispatchQueue.main.async {
                FileHost.shared.installUserTree(replaceExisting: false)
            }
            return
        case .restoreUserTree(let renameFirst):
            // Confirm alerts run in EditForth; companion only performs the copy.
            FileHost.shared.restoreUserTreeFromEditor(renameFirst: renameFirst)
            return
        case .executeCommand, .loadSource, .viewWord, .toggleBreakpoint, .breakGo:
            break
        }

        // Do not queue another evaluate behind a long-running one on the main
        // queue (e.g. IMAGEVIEW / KEY loop). main.async is FIFO, so a second
        // executeCommand would sit silently until the first returns — EMIT and
        // console lines look dead. Reject now from the I/O thread.
        if kernel.isEvaluating {
            let msg = "busy — finish current command first (Esc/Q in the graphics window, or Stop Forth)"
            writeResponse(.error(message: msg), to: fd)
            return
        }

        // evaluate / loadFile need the main-thread AppKit pump while KEY waits.
        DispatchQueue.main.async {
            let response: ForthResponse
            switch request {
            case .executeCommand(let command):
                // Kernel holds evalLock while DEBUG waits for KEY; reject with a clear message.
                if kernel.isAnyDebugArmed {
                    response = .error(message: "debugger paused — use Step/Continue")
                } else if kernel.isEvaluating {
                    response = .error(message: "busy — finish current command first")
                } else {
                    // Editor submitLine always appends \n after the input line before
                    // results stream. If Forth emits nothing, that client newline already
                    // ended the line — forcing another \n before ok made blank lines
                    // between prompts (empty Return / silent words like `1`).
                    self.emitLock.lock()
                    let genBefore = self.emitGeneration
                    self.emitLock.unlock()
                    let st = kernel.evaluate(command)
                    kernel.forceFlushEmitSync()
                    if st == 0 {
                        self.emitLock.lock()
                        if self.emitGeneration == genBefore {
                            self.emitEndsWithNewline = true
                        }
                        self.emitLock.unlock()
                        // Mirror GUI ConsoleView: newline before ok when TYPE left mid-line.
                        self.broadcastOkPrompt()
                        response = .consoleOutput(text: "")
                    } else if st == 1 {
                        // BYE — ask EditForth to quit (dirty review); do not
                        // report status=1 as an error or exit the companion here.
                        self.broadcast(.requestQuit)
                        response = .consoleOutput(text: "")
                    } else {
                        response = .error(message: "status=\(st)")
                    }
                }
            case .viewWord(let name):
                // Soft (VIEW): no ' abort. opened ⇔ EDIT-AT ran (stamp → 64Edit).
                let word = name.trimmingCharacters(in: .whitespacesAndNewlines)
                if word.isEmpty || word.contains(where: { $0.isWhitespace || $0.isNewline }) {
                    response = .error(message: "VIEW needs a single token")
                } else if kernel.isAnyDebugArmed {
                    response = .error(message: "debugger paused — use Step/Continue")
                } else {
                    let before = FileHost.shared.editAtOpenCount
                    // VIEW uses PARSE-NAME (VIEW) DROP — miss prints "undefined: name" depth-clean.
                    let st = kernel.evaluate("VIEW \(word)")
                    kernel.forceFlushEmitSync()
                    if st != 0 {
                        response = .error(message: "status=\(st)")
                    } else {
                        let opened = FileHost.shared.editAtOpenCount > before
                        response = .viewResult(word: word, opened: opened)
                    }
                }
            case .toggleBreakpoint(let name):
                // TOGGLE-BREAK via ' — undefined aborts evaluate (status ≠ 0).
                let word = name.trimmingCharacters(in: .whitespacesAndNewlines)
                if word.isEmpty || word.contains(where: { $0.isWhitespace || $0.isNewline }) {
                    response = .error(message: "BREAK needs a single token")
                } else if kernel.isAnyDebugArmed {
                    response = .error(message: "debugger paused — use Step/Continue")
                } else {
                    let st = kernel.evaluate("TOGGLE-BREAK \(word)")
                    kernel.forceFlushEmitSync()
                    if st != 0 {
                        response = .error(message: "status=\(st)")
                    } else {
                        let entries = kernel.breakEntries()
                        // Broadcast so every connected editor refreshes pale-red wash.
                        self.broadcast(.breakpoints(entries: entries))
                        response = .breakpoints(entries: entries)
                    }
                }
            case .breakGo(let name):
                // Idle Arm: BPGO <name> (runs that word until an enabled BREAK hits).
                let word = name.trimmingCharacters(in: .whitespacesAndNewlines)
                if word.isEmpty || word.contains(where: { $0.isWhitespace || $0.isNewline }) {
                    response = .error(message: "BPGO needs a single token")
                } else if kernel.isAnyDebugArmed {
                    response = .error(message: "debugger paused — use Arm on the debug bar")
                } else {
                    let st = kernel.evaluate("BPGO \(word)")
                    kernel.forceFlushEmitSync()
                    response = st == 0
                        ? .consoleOutput(text: "ok(\(kernel.dataStackDepth))")
                        : .error(message: "status=\(st)")
                }
            case .loadSource(let path):
                if kernel.isAnyDebugArmed {
                    response = .error(message: "debugger paused — use Step/Continue")
                } else {
                    let st = kernel.loadFile(named: path)
                    kernel.forceFlushEmitSync()
                    response = st == 0 ? .consoleOutput(text: "ok") : .error(message: "load status=\(st)")
                }
            default:
                return
            }
            self.queue.async {
                self.writeResponse(response, to: fd)
            }
        }
    }

    @discardableResult
    private func writeResponse(_ response: ForthResponse, to fd: Int32) -> Bool {
        guard clients.contains(fd) || clientSources[fd] != nil else { return false }
        guard let data = try? IPCCodec.encodeResponse(response) else { return false }
        var line = data
        line.append(0x0A)
        let n = line.withUnsafeBytes { raw -> Int in
            Darwin.write(fd, raw.baseAddress, line.count)
        }
        if n < 0 {
            dropClient(fd)
            return false
        }
        return true
    }

    func broadcast(_ response: ForthResponse) {
        var response = response
        if case .consoleOutput(let text) = response, !text.isEmpty {
            // NSTextView treats \r and \n as separate line breaks — collapse to \n.
            let normalized = text
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
            response = .consoleOutput(text: normalized)
            emitLock.lock()
            noteConsoleEmit(normalized)
            emitLock.unlock()
        }
        queue.async {
            if case .consoleOutput(let text) = response, !text.isEmpty {
                self.appendRecentConsole(text)
            }
            for fd in self.clients {
                self.writeResponse(response, to: fd)
            }
        }
    }

    /// Append `ok(depth)> ` for the editor console, starting a new line when needed.
    func broadcastOkPrompt() {
        let n = KernelBridge.shared.dataStackDepth
        emitLock.lock()
        let prefix = emitEndsWithNewline ? "" : "\n"
        let text = "\(prefix)ok(\(n))> "
        emitLock.unlock()
        // `broadcast` notes emit + recentConsole once (avoid double noteConsoleEmit).
        broadcast(.consoleOutput(text: text))
    }

    private func noteConsoleEmit(_ text: String) {
        emitGeneration &+= 1
        if text.contains("\u{0c}") {
            emitEndsWithNewline = true
            return
        }
        if let last = text.last {
            emitEndsWithNewline = (last == "\n")
        }
    }

    private func appendRecentConsole(_ text: String) {
        recentConsole.append(text)
        guard recentConsole.count > recentConsoleMax else { return }
        let overflow = recentConsole.count - recentConsoleMax
        recentConsole.removeFirst(overflow)
        if let nl = recentConsole.firstIndex(of: "\n") {
            recentConsole.removeSubrange(..<recentConsole.index(after: nl))
        }
    }
}
