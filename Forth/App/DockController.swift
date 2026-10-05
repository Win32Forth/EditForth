//
//  DockController.swift
//  64Forth (EditForth)
//
//  Positions the console window into the editor’s Ping dock slot (separate process).
//

import AppKit

/// Window-dock helper for EditForth: borderless frame matching the editor slot.
final class DockController {
    static let shared = DockController()

    private(set) var isDocked = false
    private var savedStyleMask: NSWindow.StyleMask?
    private var savedFrame: NSRect?
    private var savedMovable = true
    private var savedHasShadow = true
    private var savedTitleVisibility: NSWindow.TitleVisibility = .visible
    private var savedTitlebarAppearsTransparent = false

    private init() {}

    /// Main console window (SwiftUI WindowGroup). Skips panels and App Output–style extras when possible.
    private func consoleWindow() -> NSWindow? {
        if let key = NSApp.keyWindow, isConsoleCandidate(key) { return key }
        if let main = NSApp.mainWindow, isConsoleCandidate(main) { return main }
        return NSApp.windows.first { $0.isVisible && isConsoleCandidate($0) }
    }

    private func isConsoleCandidate(_ window: NSWindow) -> Bool {
        if window.level != .normal { return false }
        if window.styleMask.contains(.nonactivatingPanel) { return false }
        // Prefer the primary titled/borderless content window with a reasonable size.
        return window.frame.width >= 200 && window.frame.height >= 120
    }

    /// Enter or update dock mode. `rect` is Cocoa screen coordinates.
    @MainActor
    func applyDock(rect: CGRect) {
        guard rect.width >= 40, rect.height >= 40 else { return }
        guard let window = consoleWindow() else { return }

        if !isDocked {
            savedStyleMask = window.styleMask
            savedFrame = window.frame
            savedMovable = window.isMovable
            savedHasShadow = window.hasShadow
            savedTitleVisibility = window.titleVisibility
            savedTitlebarAppearsTransparent = window.titlebarAppearsTransparent
            isDocked = true
        }

        var mask: NSWindow.StyleMask = [.borderless, .fullSizeContentView]
        if window.styleMask.contains(.resizable) {
            mask.insert(.resizable)
        }
        window.styleMask = mask
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovable = false
        window.hasShadow = false
        window.setFrame(rect, display: true, animate: false)
        window.orderFrontRegardless()
    }

    @MainActor
    func undock() {
        guard isDocked else { return }
        guard let window = consoleWindow() else {
            isDocked = false
            return
        }
        if let mask = savedStyleMask {
            window.styleMask = mask
        }
        window.titleVisibility = savedTitleVisibility
        window.titlebarAppearsTransparent = savedTitlebarAppearsTransparent
        window.isMovable = savedMovable
        window.hasShadow = savedHasShadow
        if let frame = savedFrame {
            window.setFrame(frame, display: true, animate: false)
        }
        isDocked = false
        savedStyleMask = nil
        savedFrame = nil
    }
}
