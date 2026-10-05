//
//  CompanionChannel.swift
//  64Forth (EditForth)
//
//  Headless companion for EditForth: kernel + edit.sock, no console window.
//  Activation: argv `--companion` / `--editforth`, or FORTH64_COMPANION=1.
//

import Foundation
#if os(macOS)
import AppKit
#endif

enum CompanionChannel {

    static var isRequested: Bool {
        let env = ProcessInfo.processInfo.environment
        if env["FORTH64_COMPANION"] == "1" || env["64FORTH_COMPANION"] == "1" {
            return true
        }
        let args = ProcessInfo.processInfo.arguments
        return args.contains("--companion") || args.contains("--editforth")
    }

    /// Run companion session (does not return until the app quits).
    static func run() {
        #if os(macOS)
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        #endif

        ForthEditorServer.shared.start()

        let kernel = KernelBridge.shared
        kernel.onEmit = { chunk in
            ForthEditorServer.shared.broadcast(.consoleOutput(text: chunk))
        }
        kernel.onCommandLineDone = {
            let n = kernel.dataStackDepth
            ForthEditorServer.shared.broadcast(.consoleOutput(text: "ok(\(n))> "))
        }
        kernel.onHostClearConsole = {
            ForthEditorServer.shared.broadcast(.consoleOutput(text: "\u{0c}")) // form-feed = clear hint
        }
        kernel.forceFlushEmitSync()

        // Match GUI startup: AutoLoad then prompt.
        DispatchQueue.main.async {
            _ = kernel.runAutoLoadIfPresent()
            kernel.forceFlushEmitSync()
            let n = kernel.dataStackDepth
            ForthEditorServer.shared.broadcast(.consoleOutput(text: "ok(\(n))> "))
        }

        #if os(macOS)
        NSApp.run()
        #else
        dispatchMain()
        #endif
    }
}
