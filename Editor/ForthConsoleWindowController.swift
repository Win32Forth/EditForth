//
//  ForthConsoleWindowController.swift
//  EditForth
//
//  Floating companion console when Undock is pressed. Same edit.sock session;
//  the red close button hides the console (companion keeps running); Dock embeds
//  it under the editor status strip again.
//

import AppKit
import SwiftUI

/// Hosts `DockedConsoleView` in a separate titled window while undocked.
final class ForthConsoleWindowController: NSObject, NSWindowDelegate {
    static let shared = ForthConsoleWindowController()

    private var window: NSWindow?
    private var hosting: NSHostingController<UndockedConsoleRoot>?
    /// When true, `windowWillClose` must not call `onRequestHide` (programmatic close).
    private var suppressHideOnClose = false
    /// User closed the floating window with the red traffic light — hide, do not dock.
    var onRequestHide: (() -> Void)?

    private override init() {
        super.init()
    }

    var isVisible: Bool { window?.isVisible == true }

    func show(forth: ForthConnectionManager) {
        if let hosting {
            hosting.rootView = UndockedConsoleRoot(forth: forth)
        }
        if window == nil {
            let root = UndockedConsoleRoot(forth: forth)
            let host = NSHostingController(rootView: root)
            hosting = host

            let win = NSWindow(
                contentRect: NSRect(x: 120, y: 120, width: 640, height: 380),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            win.title = "64Forth"
            win.minSize = NSSize(width: 320, height: 160)
            win.contentViewController = host
            win.delegate = self
            win.isReleasedWhenClosed = false
            win.setFrameAutosaveName("EditForthUndockedConsole")
            win.isExcludedFromWindowsMenu = false
            window = win
        }
        suppressHideOnClose = false
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Close without treating it as “user wants Hide”.
    func closeQuietly() {
        suppressHideOnClose = true
        window?.orderOut(nil)
        window?.delegate = nil
        window?.close()
        window = nil
        hosting = nil
        suppressHideOnClose = false
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        hosting = nil
        guard !suppressHideOnClose else { return }
        onRequestHide?()
    }
}

/// Root view for the undocked console window.
struct UndockedConsoleRoot: View {
    @ObservedObject var forth: ForthConnectionManager

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(forth.isConnected ? "Engine connected" : "Engine down")
                    .font(.system(size: 12, design: .monospaced))
                if forth.isDebugSessionArmed {
                    Text("· debugging")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.orange)
                }
                Spacer()
                Button("Dock") {
                    forth.dockForth()
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))

            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.55))
                .frame(height: 1)

            DockedConsoleView(forth: forth)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 320, minHeight: 160)
    }
}
