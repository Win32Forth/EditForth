//
//  AskForthWindowController.swift
//  EditForth
//
//  Floating Ask Forth inspector when Undock is pressed. Same AIAssistantModel
//  as the trailing docked panel. Red close hides Ask Forth (⌥⌘A shows it again
//  in the last docked/undocked mode); Dock embeds the panel in the editor.
//

import AppKit
import SwiftUI

/// Hosts `AIAssistantPanel` in a separate titled window while undocked.
final class AskForthWindowController: NSObject, NSWindowDelegate {
    static let shared = AskForthWindowController()

    private var window: NSWindow?
    private var hosting: NSHostingController<UndockedAskForthRoot>?
    /// When true, `windowWillClose` must not call `onRequestHide` (programmatic close / quit).
    private var suppressHideOnClose = false
    /// User closed the floating window with the red traffic light — hide Ask Forth.
    var onRequestHide: (() -> Void)?

    private override init() {
        super.init()
    }

    var isVisible: Bool { window?.isVisible == true }

    /// Call before app quit so tearing down the floating window does not clear
    /// the persisted `showAIAssistant` preference.
    func prepareForAppTermination() {
        suppressHideOnClose = true
        closeQuietly()
    }

    func show(model: AIAssistantModel, workspace: WorkspaceModel) {
        let root = UndockedAskForthRoot(model: model, workspace: workspace)
        if let hosting {
            hosting.rootView = root
        } else {
            let host = NSHostingController(rootView: root)
            hosting = host

            let win = NSWindow(
                contentRect: NSRect(x: 160, y: 100, width: 380, height: 640),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            win.title = "Ask Forth"
            win.minSize = NSSize(width: 280, height: 360)
            win.contentViewController = host
            win.delegate = self
            win.isReleasedWhenClosed = false
            win.setFrameAutosaveName("EditForthUndockedAskForth")
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
        // Keep suppressHideOnClose true through any deferred willClose; show() clears it.
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        hosting = nil
        guard !suppressHideOnClose else { return }
        onRequestHide?()
    }
}

/// Root view for the undocked Ask Forth window.
struct UndockedAskForthRoot: View {
    @ObservedObject var model: AIAssistantModel
    @ObservedObject var workspace: WorkspaceModel
    @AppStorage("askForthDocked") private var askForthDocked = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Floating")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Dock") {
                    askForthDocked = true
                }
                .help("Return Ask Forth to the trailing inspector beside the editor.")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))

            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.55))
                .frame(height: 1)

            AIAssistantPanel(model: model)
                .environmentObject(workspace)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 280, minHeight: 360)
    }
}
