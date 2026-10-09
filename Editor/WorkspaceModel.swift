//
//  WorkspaceModel.swift
//  64Edit
//
//  Single-window tab workspace (Slice 1). Replaces DocumentGroup so one shared
//  Forth console can serve every open file.
//

import Foundation
import AppKit
import Combine
import UniformTypeIdentifiers

/// One open editor buffer (path optional until first Save As).
final class EditorTab: Identifiable, ObservableObject {
    let id = UUID()
    @Published var text: String
    @Published var fileURL: URL?
    @Published var isDirty: Bool
    @Published var isViewMode: Bool
    @Published var gotoLine: Int?
    /// Peek token to highlight after goto (DEBUG); cleared when applied or session ends.
    @Published var highlightName: String?
    /// File-relative UTF-8 byte span from dbg-map (nil/0 = name search fallback).
    @Published var highlightOff: Int?
    @Published var highlightLen: Int?
    /// Bumped on each debugLocation so deferred finishGoto retries cannot
    /// re-apply a stale span after a newer pause (same VIEW line).
    var highlightEpoch: UInt = 0
    /// Caret / selection restored when this tab becomes selected again.
    var selection = NSRange(location: 0, length: 0)
    /// 1-based first visible line restored with the selection (not @Published — caret churn).
    var topVisibleLine: Int = 1

    init(
        text: String = "",
        fileURL: URL? = nil,
        isDirty: Bool = false,
        isViewMode: Bool = false,
        gotoLine: Int? = nil,
        highlightName: String? = nil,
        highlightOff: Int? = nil,
        highlightLen: Int? = nil
    ) {
        self.text = text
        self.fileURL = fileURL
        self.isDirty = isDirty
        self.isViewMode = isViewMode
        self.gotoLine = gotoLine
        self.highlightName = highlightName
        self.highlightOff = highlightOff
        self.highlightLen = highlightLen
    }

    var title: String {
        let name = fileURL?.lastPathComponent ?? "Untitled"
        return isDirty ? "\(name) •" : name
    }

    var pathString: String? { fileURL?.path }
}

/// Owns the open-tab list and find-or-open for VIEW / EDIT / debugLocation.
final class WorkspaceModel: ObservableObject {
    @Published private(set) var tabs: [EditorTab] = []
    /// Folder-search result tabs (hit lists only — not file buffers).
    @Published private(set) var searchTabs: [SearchSession] = []
    @Published var selectedTabID: UUID?
    /// Right-hand editor pane tab while split; nil means split is closed.
    @Published private(set) var splitSecondaryTabID: UUID?

    private var tabCancellables: [UUID: AnyCancellable] = [:]
    private var searchCancellables: [UUID: AnyCancellable] = [:]

    /// Selected file editor tab (nil when a search tab is selected).
    var selectedTab: EditorTab? {
        tabs.first { $0.id == selectedTabID }
    }

    var selectedSearchTab: SearchSession? {
        searchTabs.first { $0.id == selectedTabID }
    }

    /// True when a second editor pane is open beside the primary.
    var isEditorSplit: Bool { splitSecondaryTabID != nil }

    /// File tab shown in the right pane (nil if split closed or tab was closed).
    var splitSecondaryTab: EditorTab? {
        guard let id = splitSecondaryTabID else { return nil }
        return tabs.first { $0.id == id }
    }

    /// Ordered strip: file tabs then search tabs (v1).
    var tabStripItems: [(id: UUID, title: String, isSearch: Bool)] {
        let files = tabs.map { (id: $0.id, title: $0.title, isSearch: false) }
        let searches = searchTabs.map { (id: $0.id, title: $0.title, isSearch: true) }
        return files + searches
    }

    // MARK: - Editor split

    /// Open a side-by-side editor. Left stays the current file tab; right picks
    /// another open file, or an Open… panel when only one file is open.
    func openEditorSplit() {
        // Need a file tab on the left — prefer selection, else last file tab.
        let left: EditorTab? = selectedTab ?? tabs.last
        guard let left else { return }
        if selectedTabID != left.id {
            selectedTabID = left.id
        }

        if let other = tabs.first(where: { $0.id != left.id }) {
            splitSecondaryTabID = other.id
            objectWillChange.send()
            return
        }

        // Only one file tab — open another file for the right pane.
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.forthSource, .plainText, .utf8PlainText, .sourceCode]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a file for the right editor pane"
        panel.prompt = "Open in Split"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let opened = openURL(url, viewMode: false, line: nil) else { return }
        // openURL focuses the new tab (left). Put the previous file back on the
        // left and the newly opened file on the right.
        selectedTabID = left.id
        splitSecondaryTabID = opened.id
        objectWillChange.send()
    }

    func closeEditorSplit() {
        guard splitSecondaryTabID != nil else { return }
        splitSecondaryTabID = nil
        objectWillChange.send()
    }

    /// Change which file tab fills the right pane.
    func setSplitSecondaryTab(id: UUID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        splitSecondaryTabID = id
        objectWillChange.send()
    }

    /// Keep left and right on different tabs when the tab bar focuses the right’s file.
    func ensureSplitPanesDistinct() {
        guard let secondary = splitSecondaryTabID,
              secondary == selectedTabID
        else { return }
        if let other = tabs.first(where: { $0.id != selectedTabID }) {
            splitSecondaryTabID = other.id
        } else {
            splitSecondaryTabID = nil
        }
        objectWillChange.send()
    }

    // MARK: - Open / focus

    /// Open `url` or select an existing tab for the same path/inode.
    /// `viewMode` nil keeps an existing tab's mode (and defaults new tabs to edit);
    /// true/false forces VIEW or EDIT. `open -a` must pass nil so it does not
    /// clobber VIEW/debug browse mode after pending-goto was already consumed.
    @discardableResult
    func openURL(
        _ url: URL,
        viewMode: Bool? = nil,
        line: Int? = nil,
        reloadIfClean: Bool = false
    ) -> EditorTab? {
        let standardized = url.standardizedFileURL
        if let existing = findTab(matching: standardized.path) {
            focus(existing, viewMode: viewMode, line: line, reloadIfClean: reloadIfClean, fileURL: standardized)
            return existing
        }

        // Relative VIEW stamps (Library/…, AutoLoad/…) must not create a second empty tab
        // beside an already-open absolute copy of the same leaf.
        let exists = FileManager.default.fileExists(atPath: standardized.path)
        if !exists {
            let leaf = standardized.lastPathComponent
            if let byLeaf = tabForLeaf(leaf) {
                focus(byLeaf, viewMode: viewMode, line: line, reloadIfClean: false, fileURL: nil)
                return byLeaf
            }
            return nil
        }

        let text = Self.readFile(standardized) ?? ""
        let tab = EditorTab(
            text: text,
            fileURL: standardized,
            isDirty: false,
            isViewMode: viewMode ?? false,
            gotoLine: (line ?? 0) > 0 ? line : nil
        )
        insertTab(tab)
        selectedTabID = tab.id
        return tab
    }

    /// Finder / `open -a` delivery. Does not force edit mode — pending-goto,
    /// sock debugLocation, or Open panel set mode explicitly.
    func openExternalURLs(_ urls: [URL]) {
        for url in urls {
            guard url.isFileURL else { continue }
            openURL(url, viewMode: nil, line: nil)
        }
        // pending-goto may refine view mode / line for the last opened path.
        handlePendingGoto()
    }

    func openPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.plainText, .text, .utf8PlainText, .forthSource]
        panel.directoryURL = ForthMenuSupport.userTreeURL
        panel.prompt = "Open"
        let accessory = OpenPanelNewFileAccessory(panel: panel)
        panel.accessoryView = accessory.view
        panel.isAccessoryViewDisclosed = true
        let response = panel.runModal()
        if accessory.choseNewFile {
            newFile()
            return
        }
        guard response == .OK else { return }
        for url in panel.urls {
            // File menu Open always unlocks editing.
            openURL(url, viewMode: false, line: nil)
        }
    }

    /// Always create a new Untitled edit tab (⌘N / empty-state / open-panel accessory).
    @discardableResult
    func newFile() -> EditorTab {
        let tab = EditorTab(text: "", fileURL: nil, isDirty: false, isViewMode: false)
        insertTab(tab)
        selectedTabID = tab.id
        return tab
    }

    // MARK: - Save

    @discardableResult
    func saveSelected() -> Bool {
        guard let tab = selectedTab else { return false }
        return saveTab(tab)
    }

    @discardableResult
    func saveSelectedAs() -> Bool {
        guard let tab = selectedTab else { return false }
        return saveTabAs(tab)
    }

    /// Write `tab` to its path, or run Save As when Untitled.
    @discardableResult
    func saveTab(_ tab: EditorTab) -> Bool {
        if let url = tab.fileURL {
            return write(tab, to: url)
        }
        return saveTabAs(tab)
    }

    @discardableResult
    func saveTabAs(_ tab: EditorTab) -> Bool {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText, .utf8PlainText, .forthSource]
        panel.canCreateDirectories = true
        panel.title = "Save As"
        if let url = tab.fileURL {
            panel.directoryURL = url.deletingLastPathComponent()
            panel.nameFieldStringValue = url.lastPathComponent
        } else {
            panel.nameFieldStringValue = "Untitled.fth"
        }
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        return write(tab, to: url.standardizedFileURL)
    }

    // MARK: - Close / new

    private enum SavePromptResult {
        case save
        case discard
        case cancel
    }

    func closeSelected() {
        guard let id = selectedTabID else { return }
        closeTab(id: id)
    }

    /// Close a file or search tab; dirty file tabs prompt Save / Don’t Save / Cancel.
    func closeTab(id: UUID) {
        if searchTabs.contains(where: { $0.id == id }) {
            removeSearchTab(id: id)
            return
        }
        guard let tab = tabs.first(where: { $0.id == id }) else { return }
        if !tab.isDirty {
            removeTab(id: id)
            return
        }
        selectedTabID = id
        presentSavePrompt(for: tab) { [weak self] result in
            guard let self else { return }
            switch result {
            case .save:
                if self.saveTab(tab) {
                    self.removeTab(id: id)
                }
            case .discard:
                self.removeTab(id: id)
            case .cancel:
                break
            }
        }
    }

    // MARK: - Folder search tabs

    /// Open (or replace the selected search tab with) a new folder search and start it.
    @discardableResult
    func openSearch(
        query: String,
        roots: [URL],
        extensions: [String],
        caseSensitive: Bool = false,
        wholeWord: Bool = false,
        recursive: Bool = true,
        replaceSelectedSearch: Bool = true
    ) -> SearchSession {
        if replaceSelectedSearch, let existing = selectedSearchTab {
            existing.requestCancel()
            let session = SearchSession(
                query: query,
                roots: roots,
                extensions: extensions,
                caseSensitive: caseSensitive,
                wholeWord: wholeWord,
                recursive: recursive
            )
            if let idx = searchTabs.firstIndex(where: { $0.id == existing.id }) {
                searchCancellables[existing.id] = nil
                searchTabs[idx] = session
                bindSearch(session)
            }
            selectedTabID = session.id
            objectWillChange.send()
            session.start()
            return session
        }
        let session = SearchSession(
            query: query,
            roots: roots,
            extensions: extensions,
            caseSensitive: caseSensitive,
            wholeWord: wholeWord,
            recursive: recursive
        )
        searchTabs.append(session)
        bindSearch(session)
        selectedTabID = session.id
        objectWillChange.send()
        session.start()
        return session
    }

    private func bindSearch(_ session: SearchSession) {
        searchCancellables[session.id] = session.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    private func removeSearchTab(id: UUID) {
        guard let index = searchTabs.firstIndex(where: { $0.id == id }) else { return }
        searchTabs[index].requestCancel()
        searchCancellables[id] = nil
        searchTabs.remove(at: index)
        if selectedTabID == id {
            // Prefer a neighboring search tab, else the last file tab.
            if !searchTabs.isEmpty {
                let next = min(index, searchTabs.count - 1)
                selectedTabID = searchTabs[next].id
            } else {
                selectedTabID = tabs.last?.id
            }
        }
        objectWillChange.send()
    }

    /// Walk dirty tabs with Save / Don’t Save / Cancel sheets; used before quit.
    /// Calls `completion(true)` only when every dirty tab was saved or discarded.
    func reviewDirtyTabsForTermination(completion: @escaping (Bool) -> Void) {
        let dirtyIDs = tabs.filter(\.isDirty).map(\.id)
        reviewDirtyTabs(ids: dirtyIDs, completion: completion)
    }

    private func reviewDirtyTabs(ids: [UUID], completion: @escaping (Bool) -> Void) {
        guard let id = ids.first else {
            completion(true)
            return
        }
        let rest = Array(ids.dropFirst())
        guard let tab = tabs.first(where: { $0.id == id }), tab.isDirty else {
            reviewDirtyTabs(ids: rest, completion: completion)
            return
        }
        selectedTabID = id
        presentSavePrompt(for: tab) { [weak self] result in
            guard let self else {
                completion(false)
                return
            }
            switch result {
            case .save:
                if self.saveTab(tab) {
                    self.reviewDirtyTabs(ids: rest, completion: completion)
                } else {
                    completion(false)
                }
            case .discard:
                tab.isDirty = false
                self.refreshDocumentEdited()
                self.reviewDirtyTabs(ids: rest, completion: completion)
            case .cancel:
                completion(false)
            }
        }
    }

    private func presentSavePrompt(for tab: EditorTab, completion: @escaping (SavePromptResult) -> Void) {
        let name = tab.fileURL?.lastPathComponent ?? "Untitled"
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Do you want to save the changes you made to “\(name)”?"
        alert.informativeText = "Your changes will be lost if you don’t save them."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Don’t Save")
        alert.addButton(withTitle: "Cancel")

        if let window = Self.sheetHostWindow() {
            alert.beginSheetModal(for: window) { response in
                completion(Self.savePromptResult(from: response))
            }
        } else {
            completion(Self.savePromptResult(from: alert.runModal()))
        }
    }

    private static func savePromptResult(from response: NSApplication.ModalResponse) -> SavePromptResult {
        switch response {
        case .alertFirstButtonReturn: return .save
        case .alertSecondButtonReturn: return .discard
        default: return .cancel
        }
    }

    private static func sheetHostWindow() -> NSWindow? {
        NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first { $0.isVisible }
    }

    private func removeTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabCancellables[id] = nil
        tabs.remove(at: index)
        if selectedTabID == id {
            if tabs.isEmpty {
                selectedTabID = nil
            } else {
                let next = min(index, tabs.count - 1)
                selectedTabID = tabs[next].id
            }
        }
        if splitSecondaryTabID == id {
            // Prefer another file that is not the left pane; else close the split.
            if let other = tabs.first(where: { $0.id != selectedTabID }) {
                splitSecondaryTabID = other.id
            } else {
                splitSecondaryTabID = nil
            }
        }
        objectWillChange.send()
        refreshDocumentEdited()
    }

    /// Cold-launch only: one Untitled when nothing was opened via `open -a` / pending-goto.
    /// Closing the last tab leaves the empty placeholder (New File / Open…).
    func newUntitledIfEmpty() {
        guard tabs.isEmpty, searchTabs.isEmpty else { return }
        _ = newFile()
    }

    // MARK: - Pending goto / debug

    /// Consume pending-goto.json and find-or-open the path (any window/tab).
    func handlePendingGoto() {
        guard let pending = PendingGoto.peek() else { return }
        openURL(
            URL(fileURLWithPath: pending.path),
            viewMode: pending.viewMode,
            line: pending.line > 0 ? pending.line : nil
        )
        _ = PendingGoto.consume()
    }

    func applyDebugLocation(
        path: String,
        line: Int,
        name: String = "",
        off: Int = 0,
        len: Int = 0
    ) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let hl = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let hlOpt: String? = hl.isEmpty ? nil : hl
        let spanOff: Int? = (len > 0 && off >= 0) ? off : nil
        let spanLen: Int? = (len > 0 && off >= 0) ? len : nil
        if let existing = findTab(matching: trimmed) {
            // Already focused: update wash only. Re-setting gotoLine every step
            // re-arms finishGoto's 0/0.05/0.2s retries and lets a stale capture
            // re-wash an earlier token (e.g. first DUP) after nesting further.
            let alreadyFocused = selectedTabID == existing.id && existing.gotoLine == nil
            focus(
                existing,
                viewMode: true,
                line: alreadyFocused ? nil : (line > 0 ? line : nil),
                reloadIfClean: false,
                fileURL: nil
            )
            existing.highlightEpoch &+= 1
            existing.highlightName = hlOpt
            existing.highlightOff = spanOff
            existing.highlightLen = spanLen
            return
        }
        if let tab = openURL(
            URL(fileURLWithPath: trimmed),
            viewMode: true,
            line: line > 0 ? line : nil
        ) {
            tab.highlightEpoch &+= 1
            tab.highlightName = hlOpt
            tab.highlightOff = spanOff
            tab.highlightLen = spanLen
        }
    }

    /// Drop temporary DEBUG highlights on every tab (session ended).
    func clearDebugHighlights() {
        for tab in tabs {
            tab.highlightEpoch &+= 1
            tab.highlightName = nil
            tab.highlightOff = nil
            tab.highlightLen = nil
        }
    }

    /// Toggle browse (VIEW) ↔ edit for the selected tab. Browse is read-only.
    func toggleBrowseMode() {
        guard let tab = selectedTab else { return }
        tab.isViewMode.toggle()
    }

    func setBrowseMode(_ browse: Bool) {
        guard let tab = selectedTab else { return }
        tab.isViewMode = browse
    }

    // MARK: - Internals

    private func findTab(matching path: String) -> EditorTab? {
        tabs.first { tab in
            guard let p = tab.pathString else { return false }
            return PendingGoto.pathsMatch(p, path)
        }
    }

    /// Prefer a tab whose file still exists on disk (avoids focusing a stale empty twin).
    private func tabForLeaf(_ leaf: String) -> EditorTab? {
        let matches = tabs.filter { $0.fileURL?.lastPathComponent == leaf }
        if let real = matches.first(where: { tab in
            guard let p = tab.pathString else { return false }
            return FileManager.default.fileExists(atPath: p)
        }) {
            return real
        }
        return matches.first(where: { !$0.text.isEmpty }) ?? matches.first
    }

    private func focus(
        _ tab: EditorTab,
        viewMode: Bool?,
        line: Int?,
        reloadIfClean: Bool,
        fileURL: URL?
    ) {
        selectedTabID = tab.id
        // nil = preserve (open -a must not strip VIEW/debug browse mode).
        if let viewMode {
            tab.isViewMode = viewMode
        }
        if let line, line > 0 {
            tab.gotoLine = line
        }
        if let fileURL, tab.fileURL == nil {
            tab.fileURL = fileURL
        }
        if reloadIfClean, !tab.isDirty, let fileURL,
           let text = Self.readFile(fileURL) {
            tab.text = text
        }
    }

    private func insertTab(_ tab: EditorTab) {
        tabs.append(tab)
        tabCancellables[tab.id] = tab.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
            DispatchQueue.main.async {
                self?.refreshDocumentEdited()
            }
        }
        objectWillChange.send()
        refreshDocumentEdited()
    }

    /// Red close-button proxy and title dirty mark for the workspace window.
    func refreshDocumentEdited() {
        let dirty = tabs.contains(where: \.isDirty)
        for window in NSApp.windows where window.isVisible || window === NSApp.keyWindow {
            window.isDocumentEdited = dirty
        }
    }

    private func write(_ tab: EditorTab, to url: URL) -> Bool {
        do {
            try tab.text.data(using: .utf8)?.write(to: url, options: .atomic)
            tab.fileURL = url
            tab.isDirty = false
            objectWillChange.send()
            refreshDocumentEdited()
            return true
        } catch {
            // App-modal so it stacks cleanly after a Save sheet / Save panel.
            NSAlert(error: error).runModal()
            return false
        }
    }

    private static func readFile(_ url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
    }
}

/// Accessory control for `NSOpenPanel`: New File dismisses the panel and creates Untitled.
private final class OpenPanelNewFileAccessory: NSObject {
    private(set) var choseNewFile = false
    private weak var panel: NSOpenPanel?
    let view: NSView

    init(panel: NSOpenPanel) {
        self.panel = panel
        let button = NSButton(
            title: "New File",
            target: nil,
            action: nil
        )
        button.bezelStyle = .rounded
        button.setButtonType(.momentaryPushIn)
        button.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        button.sizeToFit()
        var frame = button.frame
        frame.size.width = max(frame.width, 88)
        frame.origin = NSPoint(x: 8, y: 4)
        button.frame = frame

        let container = NSView(frame: NSRect(x: 0, y: 0, width: frame.maxX + 8, height: frame.height + 8))
        container.addSubview(button)
        self.view = container
        super.init()
        button.target = self
        button.action = #selector(newFileClicked(_:))
    }

    @objc private func newFileClicked(_ sender: Any?) {
        choseNewFile = true
        // End the modal open session; caller checks `choseNewFile`.
        NSApp.stopModal(withCode: .cancel)
        panel?.close()
    }
}
