//
//  AppDelegate.swift
//  64Edit
//
//  Receives Finder / `open -a 64Edit.app path` file opens for the tab workspace.
//  Quit / last-window-close runs dirty Save / Don’t Save / Cancel sheets.
//

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
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
            self?.bringWorkspaceWindowsForward()
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        NSApp.activate(ignoringOtherApps: true)
        if let workspace {
            workspace.openExternalURLs(urls)
            bringWorkspaceWindowsForward()
        } else {
            queuedURLs.append(contentsOf: urls)
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        windowGuard.installOnOpenWindows()
        workspace?.refreshDocumentEdited()
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

    private func bringWorkspaceWindowsForward() {
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
