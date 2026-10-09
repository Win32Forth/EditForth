//
//  AppDelegate.swift
//  64Edit
//
//  Receives Finder / `open -a 64Edit.app path` file opens for the tab workspace.
//  Quit / last-window-close runs dirty Save / Don’t Save / Cancel sheets.
//

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Tags SwiftUI workspace windows (see `WindowChrome`) so Finder opens can
    /// collapse duplicates without closing the floating Forth console.
    static let workspaceWindowID = NSUserInterfaceItemIdentifier("EditForth.workspace")

    weak var workspace: WorkspaceModel?
    weak var forth: ForthConnectionManager?
    private var queuedURLs: [URL] = []
    private var isReviewingTermination = false
    private let windowGuard = WorkspaceWindowGuard()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
        bringWorkspaceWindowsForward()
    }

    func attach(workspace: WorkspaceModel, forth: ForthConnectionManager? = nil) {
        self.workspace = workspace
        if let forth {
            self.forth = forth
        }
        windowGuard.workspace = workspace
        windowGuard.appDelegate = self
        let urls = queuedURLs
        queuedURLs = []
        if !urls.isEmpty {
            workspace.openExternalURLs(urls)
        } else {
            workspace.handlePendingGoto()
        }
        if workspace.tabs.isEmpty {
            workspace.newUntitledIfEmpty()
        }
        workspace.refreshDocumentEdited()
        DispatchQueue.main.async { [weak self] in
            self?.windowGuard.installOnOpenWindows()
            self?.collapseExtraWorkspaceWindows()
            self?.bringWorkspaceWindowsForward()
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        NSApp.activate(ignoringOtherApps: true)
        if let workspace {
            workspace.openExternalURLs(urls)
            // Finder open can still race a second WindowGroup scene; collapse soon + delayed.
            collapseExtraWorkspaceWindowsSoon()
        } else {
            queuedURLs.append(contentsOf: urls)
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        windowGuard.installOnOpenWindows()
        workspace?.refreshDocumentEdited()
        collapseExtraWorkspaceWindows()
        bringWorkspaceWindowsForward()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // Dock click with no visible window — SwiftUI WindowGroup should recreate;
            // still force activation so the user is not left with a headless process.
            NSApp.activate(ignoringOtherApps: true)
        }
        bringWorkspaceWindowsForward()
        return true
    }

    /// Collapse now and again after WindowChrome has a chance to tag a raced scene.
    func collapseExtraWorkspaceWindowsSoon() {
        DispatchQueue.main.async { [weak self] in
            self?.collapseExtraWorkspaceWindows()
            self?.bringWorkspaceWindowsForward()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.collapseExtraWorkspaceWindows()
            self?.bringWorkspaceWindowsForward()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.collapseExtraWorkspaceWindows()
            self?.bringWorkspaceWindowsForward()
        }
    }

    /// Prefer a single workspace window; leave the floating "64Forth" console alone.
    func collapseExtraWorkspaceWindows() {
        let id = Self.workspaceWindowID
        var workspaceWindows = NSApp.windows.filter { $0.identifier == id && $0.isVisible }
        // Before WindowChrome tags a raced scene, also catch untitled SwiftUI windows
        // that are not the floating Forth console / panels.
        if workspaceWindows.count <= 1 {
            let consoleTitle = "64Forth"
            let extras = NSApp.windows.filter { win in
                guard win.isVisible, win.canBecomeKey, !(win is NSPanel) else { return false }
                if win.title == consoleTitle { return false }
                if win.identifier == id { return true }
                // Untagged SwiftUI workspace-like windows (titled, closable).
                return win.styleMask.contains(.titled) && win.styleMask.contains(.closable)
            }
            workspaceWindows = extras
        }
        guard workspaceWindows.count > 1 else { return }
        // Keep the oldest (first created) — that is the real workspace the user had open.
        let keep = workspaceWindows.min(by: { $0.windowNumber < $1.windowNumber })
            ?? workspaceWindows[0]
        for window in workspaceWindows where window !== keep {
            window.close()
        }
    }

    private func bringWorkspaceWindowsForward() {
        let id = Self.workspaceWindowID
        if let main = NSApp.windows.first(where: { $0.identifier == id && $0.isVisible })
            ?? NSApp.windows.first(where: { $0.canBecomeKey && $0.isVisible && $0.title != "64Forth" }) {
            main.makeKeyAndOrderFront(nil)
            return
        }
        for window in NSApp.windows where window.canBecomeKey {
            window.makeKeyAndOrderFront(nil)
        }
    }

    /// Single-window editor: closing the last window quits (dirty review runs first).
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let workspace else {
            forth?.terminateLaunchedCompanion()
            return .terminateNow
        }
        guard workspace.tabs.contains(where: \.isDirty) else {
            forth?.terminateLaunchedCompanion()
            return .terminateNow
        }
        if isReviewingTermination { return .terminateLater }
        isReviewingTermination = true
        workspace.reviewDirtyTabsForTermination { [weak self] allow in
            self?.isReviewingTermination = false
            if allow {
                self?.forth?.terminateLaunchedCompanion()
            }
            NSApp.reply(toApplicationShouldTerminate: allow)
        }
        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) {
        forth?.terminateLaunchedCompanion()
    }

    /// Red-close while dirty: keep the window up for sheets, then quit if allowed.
    func reviewDirtyThenTerminateIfAllowed() {
        guard let workspace else {
            NSApp.terminate(nil)
            return
        }
        guard workspace.tabs.contains(where: \.isDirty) else {
            NSApp.terminate(nil)
            return
        }
        if isReviewingTermination { return }
        isReviewingTermination = true
        workspace.reviewDirtyTabsForTermination { [weak self] allow in
            self?.isReviewingTermination = false
            if allow {
                NSApp.terminate(nil)
            }
        }
    }
}

/// Keeps Save sheets on the workspace window before red-close dismisses it.
private final class WorkspaceWindowGuard: NSObject, NSWindowDelegate {
    weak var workspace: WorkspaceModel?
    weak var appDelegate: AppDelegate?
    private var observedIDs = Set<ObjectIdentifier>()

    func installOnOpenWindows() {
        for window in NSApp.windows where window.isVisible {
            install(on: window)
        }
    }

    func install(on window: NSWindow) {
        let id = ObjectIdentifier(window)
        if !observedIDs.contains(id) {
            observedIDs.insert(id)
        }
        window.delegate = self
        workspace?.refreshDocumentEdited()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard let workspace, workspace.tabs.contains(where: \.isDirty) else {
            return true
        }
        appDelegate?.reviewDirtyThenTerminateIfAllowed()
        return false
    }
}
