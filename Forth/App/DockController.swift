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
    private weak var dockedWindow: NSWindow?
    private var savedStyleMask: NSWindow.StyleMask?
    private var savedFrame: NSRect?
    private var savedMovable = true
    private var savedHasShadow = true
    private var savedTitleVisibility: NSWindow.TitleVisibility = .visible
    private var savedTitlebarAppearsTransparent = false
    private var savedMinSize = NSSize(width: 0, height: 0)
    private var savedMaxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    private var savedContentMinSize = NSSize(width: 0, height: 0)
    private var savedContentMaxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    private var savedContentAspectRatio = NSSize.zero

    private init() {}

    /// Main console window (SwiftUI WindowGroup). Skips panels and App Output–style extras when possible.
    private func consoleWindow() -> NSWindow? {
        if let dockedWindow, dockedWindow.isVisible || isDocked {
            return dockedWindow
        }
        if let key = NSApp.keyWindow, isConsoleCandidate(key) { return key }
        if let main = NSApp.mainWindow, isConsoleCandidate(main) { return main }
        return NSApp.windows.first { $0.isVisible && isConsoleCandidate($0) }
    }

    private func isConsoleCandidate(_ window: NSWindow) -> Bool {
        if window.level != .normal { return false }
        if window.styleMask.contains(.nonactivatingPanel) { return false }
        // Allow small frames once we may already be docking.
        return window.frame.width >= 80 && window.frame.height >= 40
    }

    /// Enter or update dock mode. `rect` is Cocoa screen coordinates.
    @MainActor
    func applyDock(rect: CGRect) {
        guard rect.width >= 40, rect.height >= 40 else { return }
        guard let window = consoleWindow() else { return }

        let firstDock = !isDocked
        if firstDock {
            savedStyleMask = window.styleMask
            savedFrame = window.frame
            savedMovable = window.isMovable
            savedHasShadow = window.hasShadow
            savedTitleVisibility = window.titleVisibility
            savedTitlebarAppearsTransparent = window.titlebarAppearsTransparent
            savedMinSize = window.minSize
            savedMaxSize = window.maxSize
            savedContentMinSize = window.contentMinSize
            savedContentMaxSize = window.contentMaxSize
            savedContentAspectRatio = window.contentAspectRatio
            dockedWindow = window
            isDocked = true
        }

        // Fixed size while docked — SwiftUI WindowGroup min sizes otherwise ignore setFrame.
        window.styleMask = [.borderless, .fullSizeContentView]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovable = false
        window.hasShadow = false
        window.contentAspectRatio = .zero
        window.minSize = NSSize(width: 40, height: 40)
        window.contentMinSize = NSSize(width: 40, height: 40)
        window.maxSize = NSSize(width: rect.width, height: rect.height)
        window.contentMaxSize = NSSize(width: rect.width, height: rect.height)
        window.setFrame(rect, display: true, animate: false)
        // Second pass: AppKit/SwiftUI sometimes keeps the old min size for one turn.
        if !framesMatch(window.frame, rect) {
            window.setFrame(rect, display: true, animate: false)
        }
        if firstDock {
            window.orderFront(nil)
        }
    }

    @MainActor
    func undock() {
        guard isDocked else { return }
        let window = dockedWindow ?? consoleWindow()
        isDocked = false
        dockedWindow = nil
        guard let window else { return }

        window.minSize = savedMinSize
        window.maxSize = savedMaxSize
        window.contentMinSize = savedContentMinSize
        window.contentMaxSize = savedContentMaxSize
        window.contentAspectRatio = savedContentAspectRatio
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
        savedStyleMask = nil
        savedFrame = nil
    }

    private func framesMatch(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.origin.x - b.origin.x) < 1
            && abs(a.origin.y - b.origin.y) < 1
            && abs(a.width - b.width) < 1
            && abs(a.height - b.height) < 1
    }
}
