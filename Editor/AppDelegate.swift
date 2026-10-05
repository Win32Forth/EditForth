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
    private var queuedURLs: [URL] = []
    private var isReviewingTermination = false
    private let windowGuard = WorkspaceWindowGuard()

    func attach(workspace: WorkspaceModel) {
        self.workspace = workspace
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
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        if let workspace {
            workspace.openExternalURLs(urls)
        } else {
            queuedURLs.append(contentsOf: urls)
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        windowGuard.installOnOpenWindows()
        workspace?.refreshDocumentEdited()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        true
    }

    /// Single-window editor: closing the last window quits (dirty review runs first).
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let workspace else { return .terminateNow }
        guard workspace.tabs.contains(where: \.isDirty) else { return .terminateNow }
        if isReviewingTermination { return .terminateLater }
        isReviewingTermination = true
        workspace.reviewDirtyTabsForTermination { [weak self] allow in
            self?.isReviewingTermination = false
            NSApp.reply(toApplicationShouldTerminate: allow)
        }
        return .terminateLater
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
