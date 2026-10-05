//
//  DockController.swift
//  64Forth (EditForth)
//
//  Positions the console window into the editor’s Ping dock slot (separate process).
//

import AppKit

/// Window-dock helper for EditForth: framed window matching the editor slot.
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
    private var savedLevel: NSWindow.Level = .normal
    private var savedMinSize = NSSize(width: 0, height: 0)
    private var savedMaxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    private var savedContentMinSize = NSSize(width: 0, height: 0)
    private var savedContentMaxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    private var savedContentAspectRatio = NSSize.zero
    private var targetRect: CGRect = .null
    private var isApplying = false
    private var moveObserver: NSObjectProtocol?
    private var onDragOut: (() -> Void)?

    private init() {}

    /// Called when the user drags the docked window away from the slot.
    func setDragOutHandler(_ handler: @escaping () -> Void) {
        onDragOut = handler
    }

    private func consoleWindow() -> NSWindow? {
        if let dockedWindow, dockedWindow.isVisible || isDocked {
            return dockedWindow
        }
        if let key = NSApp.keyWindow, isConsoleCandidate(key) { return key }
        if let main = NSApp.mainWindow, isConsoleCandidate(main) { return main }
        return NSApp.windows.first { $0.isVisible && isConsoleCandidate($0) }
    }

    private func isConsoleCandidate(_ window: NSWindow) -> Bool {
        if window.styleMask.contains(.nonactivatingPanel) { return false }
        return window.frame.width >= 80 && window.frame.height >= 40
    }

    /// Enter or update dock mode. `rect` is Cocoa screen coordinates for the slot.
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
            savedLevel = window.level
            savedMinSize = window.minSize
            savedMaxSize = window.maxSize
            savedContentMinSize = window.contentMinSize
            savedContentMaxSize = window.contentMaxSize
            savedContentAspectRatio = window.contentAspectRatio
            dockedWindow = window
            isDocked = true
            installMoveWatcher(on: window)
        }

        targetRect = rect
        isApplying = true
        defer { isApplying = false }

        // Titled + thin chrome so the user can drag the window out to undock.
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.title = "64Forth"
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
        window.isMovable = true
        window.hasShadow = true
        // Stay above the editor while following it (same app space, not always-on-top for others).
        window.level = NSWindow.Level(rawValue: NSWindow.Level.normal.rawValue + 1)
        window.contentAspectRatio = .zero
        window.minSize = NSSize(width: 40, height: 40)
        window.contentMinSize = NSSize(width: 40, height: 40)
        window.maxSize = NSSize(width: max(rect.width, 40), height: max(rect.height, 40))
        window.contentMaxSize = window.maxSize
        window.setFrame(rect, display: true, animate: false)
        if !framesMatch(window.frame, rect) {
            window.setFrame(rect, display: true, animate: false)
        }
        // Keep above the editor on every follow update (dragging the editor steals z-order).
        window.orderFront(nil)
    }

    @MainActor
    func undock(restoreFrame: Bool = true) {
        guard isDocked else { return }
        let window = dockedWindow ?? consoleWindow()
        removeMoveWatcher()
        isDocked = false
        dockedWindow = nil
        targetRect = .null
        guard let window else { return }

        window.level = savedLevel
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
        if restoreFrame, let frame = savedFrame {
            window.setFrame(frame, display: true, animate: false)
        }
        savedStyleMask = nil
        savedFrame = nil
    }

    private func installMoveWatcher(on window: NSWindow) {
        removeMoveWatcher()
        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.handleUserMovedDockedWindow()
        }
    }

    private func removeMoveWatcher() {
        if let moveObserver {
            NotificationCenter.default.removeObserver(moveObserver)
            self.moveObserver = nil
        }
    }

    @MainActor
    private func handleUserMovedDockedWindow() {
        guard isDocked, !isApplying else { return }
        guard let window = dockedWindow ?? consoleWindow() else { return }
        guard !targetRect.isNull else { return }
        // Ignore tiny follow noise; a real drag jumps well past a few points.
        let dx = abs(window.frame.origin.x - targetRect.origin.x)
        let dy = abs(window.frame.origin.y - targetRect.origin.y)
        guard dx > 12 || dy > 12 else { return }
        // Keep the dragged frame; leave dock mode.
        undock(restoreFrame: false)
        onDragOut?()
    }

    private func framesMatch(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.origin.x - b.origin.x) < 1
            && abs(a.origin.y - b.origin.y) < 1
            && abs(a.width - b.width) < 1
            && abs(a.height - b.height) < 1
    }
}
