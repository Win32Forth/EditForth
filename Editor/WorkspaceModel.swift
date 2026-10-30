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

    /// Whitespace-delimited Forth token at the stored caret, if any.
    func forthTokenAtCaret() -> String? {
        let ns = text as NSString
        let idx = min(max(0, selection.location), ns.length)
        return EditorNSTextView.forthToken(at: idx, in: ns)
    }

    /// Selected text when it is one Forth word. A bare caret is not a highlight.
    func forthHighlightedWord() -> String? {
        EditorNSTextView.forthHighlightedWord(in: text as NSString, selection: selection)
    }

    /// Append streamed Ask Forth text and park the caret at the end.
    func appendStreamingText(_ chunk: String) {
        guard !chunk.isEmpty else { return }
        text += chunk
        isDirty = true
        let end = (text as NSString).length
        selection = NSRange(location: end, length: 0)
    }
}

/// Owns the open-tab list and find-or-open for VIEW / EDIT / debugLocation.
final class WorkspaceModel: ObservableObject {
    @Published private(set) var tabs: [EditorTab] = []
    /// Folder-search result tabs (hit lists only — not file buffers).
    @Published private(set) var searchTabs: [SearchSession] = []
    /// Buffer ↔ disk diff tabs (hunk lists only — not file buffers).
    @Published private(set) var diffTabs: [BufferDiskDiffSession] = []
    /// Embedded WKWebView tabs (doc browser — not file buffers).
    @Published private(set) var webTabs: [WebSession] = []
    @Published var selectedTabID: UUID?
    /// One console note per dirty-buffer debug session (span offsets are file bytes).
    var debugDirtySpanNoted = false
    /// Right-hand editor pane tab while split; nil means split is closed.
    @Published private(set) var splitSecondaryTabID: UUID?

    private var tabCancellables: [UUID: AnyCancellable] = [:]
    private var searchCancellables: [UUID: AnyCancellable] = [:]
    private var diffCancellables: [UUID: AnyCancellable] = [:]
    private var webCancellables: [UUID: AnyCancellable] = [:]

    /// Selected file editor tab (nil when a search/diff/web tab is selected).
    var selectedTab: EditorTab? {
        tabs.first { $0.id == selectedTabID }
    }

    /// Token under the selected file tab's caret (idle Arm). Nil on search/diff tabs.
    func forthTokenAtCaret() -> String? {
        selectedTab?.forthTokenAtCaret()
    }

    /// Highlighted Forth word in the selected file, else the split pane.
    /// Nil when nothing is selected, so RUN / F5 can use the last
    /// definition in the file just included.
    func forthHighlightedWord() -> String? {
        if let word = selectedTab?.forthHighlightedWord() { return word }
        return splitSecondaryTab?.forthHighlightedWord()
    }

    var selectedSearchTab: SearchSession? {
        searchTabs.first { $0.id == selectedTabID }
    }

    var selectedDiffTab: BufferDiskDiffSession? {
        diffTabs.first { $0.id == selectedTabID }
    }

    var selectedWebTab: WebSession? {
        webTabs.first { $0.id == selectedTabID }
    }

    /// True when a second editor pane is open beside the primary.
    var isEditorSplit: Bool { splitSecondaryTabID != nil }

    /// File tab shown in the right pane (nil if split closed or tab was closed).
    var splitSecondaryTab: EditorTab? {
        guard let id = splitSecondaryTabID else { return nil }
        return tabs.first { $0.id == id }
    }

    /// Ordered strip: file tabs then search / diff / web tabs.
    var tabStripItems: [(id: UUID, title: String, isSearch: Bool)] {
        let files = tabs.map { (id: $0.id, title: $0.title, isSearch: false) }
        let searches = searchTabs.map { (id: $0.id, title: $0.title, isSearch: true) }
        let diffs = diffTabs.map { (id: $0.id, title: $0.title, isSearch: true) }
        let webs = webTabs.map { (id: $0.id, title: $0.title, isSearch: true) }
        return files + searches + diffs + webs
    }

    /// True when there is nothing to show in the editor area.
    var isEditorEmpty: Bool {
        tabs.isEmpty && searchTabs.isEmpty && diffTabs.isEmpty && webTabs.isEmpty
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
            let mode = ForthMenuSupport.opensReadOnly(existing.fileURL ?? standardized) ? true : viewMode
            focus(existing, viewMode: mode, line: line, reloadIfClean: reloadIfClean, fileURL: standardized)
            return existing
        }

        // Relative VIEW stamps (Library/…, AutoLoad/…) must not create a second empty tab
        // beside an already-open absolute copy of the same leaf.
        let exists = FileManager.default.fileExists(atPath: standardized.path)
        if !exists {
            let leaf = standardized.lastPathComponent
            if let byLeaf = tabForLeaf(leaf) {
                let mode = (byLeaf.fileURL.map(ForthMenuSupport.opensReadOnly) ?? false) ? true : viewMode
                focus(byLeaf, viewMode: mode, line: line, reloadIfClean: false, fileURL: nil)
                return byLeaf
            }
            return nil
        }

        let text = Self.readFile(standardized) ?? ""
        let tab = EditorTab(
            text: text,
            fileURL: standardized,
            isDirty: false,
            isViewMode: ForthMenuSupport.opensReadOnly(standardized) || (viewMode ?? false),
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

    func openPanel(startDirectory: URL? = nil) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.plainText, .text, .utf8PlainText, .forthSource]
        panel.directoryURL = startDirectory ?? ForthMenuSupport.userTreeURL
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
            // Docs and System stay read-only inside openURL. Other files unlock.
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

    /// Create `~/Documents/EditForth/AskForth/AskForth-N.fth` (next free N), write `initialText`, and open it.
    @discardableResult
    func createAskForthFile(initialText: String) -> EditorTab? {
        let dir = ForthMenuSupport.userTreeURL.appendingPathComponent("AskForth", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            NSAlert(error: error).runModal()
            return nil
        }
        let url = Self.nextAskForthURL(in: dir)
        do {
            try initialText.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            NSAlert(error: error).runModal()
            return nil
        }
        return openURL(url, viewMode: false, line: nil)
    }

    /// Next unused `AskForth-N.fth` under `dir`.
    static func nextAskForthURL(in dir: URL) -> URL {
        var n = 1
        while n < 100_000 {
            let url = dir.appendingPathComponent("AskForth-\(n).fth", isDirectory: false)
            if !FileManager.default.fileExists(atPath: url.path) {
                return url
            }
            n += 1
        }
        return dir.appendingPathComponent("AskForth-\(UUID().uuidString).fth", isDirectory: false)
    }

    /// Tab with `id` if it is still open.
    func tab(id: UUID) -> EditorTab? {
        tabs.first { $0.id == id }
    }

    // MARK: - Save

    @discardableResult
    func saveSelected() -> Bool {
        guard let tab = selectedTab else { return false }
        return saveTab(tab)
    }

    /// `directory` is where an untitled Save As panel opens.
    @discardableResult
    func saveSelectedAs(directory: URL? = nil) -> Bool {
        guard let tab = selectedTab else { return false }
        return saveTabAs(tab, directory: directory)
    }

    /// Write `tab` to its path, or run Save As when Untitled.
    @discardableResult
    func saveTab(_ tab: EditorTab) -> Bool {
        if let url = tab.fileURL {
            return write(tab, to: url)
        }
        return saveTabAs(tab)
    }

    /// `directory` is where the panel opens when `tab` has no file yet.
    @discardableResult
    func saveTabAs(_ tab: EditorTab, directory: URL? = nil) -> Bool {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText, .utf8PlainText, .forthSource]
        panel.canCreateDirectories = true
        panel.title = "Save As"
        if let url = tab.fileURL {
            panel.directoryURL = url.deletingLastPathComponent()
            panel.nameFieldStringValue = url.lastPathComponent
        } else {
            if let directory {
                panel.directoryURL = directory
            }
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

    /// Close a file, search, diff, or web tab; dirty file tabs prompt Save / Don’t Save / Cancel.
    func closeTab(id: UUID) {
        if searchTabs.contains(where: { $0.id == id }) {
            removeSearchTab(id: id)
            return
        }
        if diffTabs.contains(where: { $0.id == id }) {
            removeDiffTab(id: id)
            return
        }
        if webTabs.contains(where: { $0.id == id }) {
            removeWebTab(id: id)
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
            // Prefer a neighboring search tab, else another special/file tab.
            if !searchTabs.isEmpty {
                let next = min(index, searchTabs.count - 1)
                selectedTabID = searchTabs[next].id
            } else {
                selectedTabID = tabs.last?.id ?? diffTabs.last?.id ?? webTabs.last?.id
            }
        }
        objectWillChange.send()
    }

    // MARK: - Buffer ↔ disk diff tabs

    /// Compare the selected file tab’s buffer with its on-disk contents.
    @discardableResult
    func compareSelectedWithDisk() -> BufferDiskDiffSession? {
        guard let tab = selectedTab, let url = tab.fileURL else { return nil }
        return openDiff(for: tab, fileURL: url)
    }

    /// Whether File → Compare with Disk should be enabled.
    var canCompareSelectedWithDisk: Bool {
        selectedTab?.fileURL != nil
    }

    @discardableResult
    func openDiff(for tab: EditorTab, fileURL: URL) -> BufferDiskDiffSession {
        let standardized = fileURL.standardizedFileURL
        // Refresh an existing diff for the same source tab if present.
        if let existing = diffTabs.first(where: { $0.sourceTabID == tab.id }) {
            selectedTabID = existing.id
            existing.reload()
            objectWillChange.send()
            return existing
        }
        let session = BufferDiskDiffSession(
            sourceTabID: tab.id,
            fileURL: standardized,
            workspace: self
        )
        diffTabs.append(session)
        bindDiff(session)
        selectedTabID = session.id
        objectWillChange.send()
        session.reload()
        return session
    }

    private func bindDiff(_ session: BufferDiskDiffSession) {
        diffCancellables[session.id] = session.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    // MARK: - Web browser tabs

    /// Open `url` in a new Web tab (or focus an existing tab with the same URL).
    @discardableResult
    func openWeb(url: URL) -> WebSession {
        let absolute = url.absoluteString
        if let existing = webTabs.first(where: { $0.currentURL?.absoluteString == absolute || $0.address == absolute }) {
            selectedTabID = existing.id
            objectWillChange.send()
            return existing
        }
        let session = WebSession(url: url)
        webTabs.append(session)
        bindWeb(session)
        selectedTabID = session.id
        objectWillChange.send()
        return session
    }

    /// Open (or focus) the default Web tab and put the keyboard in the address / search field.
    func openWebPage() {
        let session = openWeb(url: WebSession.defaultHomeURL)
        session.requestAddressFocus()
    }

    private func bindWeb(_ session: WebSession) {
        webCancellables[session.id] = session.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    private func removeWebTab(id: UUID) {
        guard let index = webTabs.firstIndex(where: { $0.id == id }) else { return }
        webCancellables[id] = nil
        webTabs.remove(at: index)
        if selectedTabID == id {
            if !webTabs.isEmpty {
                let next = min(index, webTabs.count - 1)
                selectedTabID = webTabs[next].id
            } else {
                selectedTabID = tabs.last?.id ?? searchTabs.last?.id ?? diffTabs.last?.id
            }
        }
        objectWillChange.send()
    }

    private func removeDiffTab(id: UUID) {
        guard let index = diffTabs.firstIndex(where: { $0.id == id }) else { return }
        diffCancellables[id] = nil
        diffTabs.remove(at: index)
        if selectedTabID == id {
            if !diffTabs.isEmpty {
                let next = min(index, diffTabs.count - 1)
                selectedTabID = diffTabs[next].id
            } else {
                selectedTabID = tabs.last?.id ?? searchTabs.last?.id ?? webTabs.last?.id
            }
        }
        objectWillChange.send()
    }

    /// Close every diff tab linked to a source editor tab (when that file tab closes).
    private func removeDiffTabs(forSourceTabID sourceID: UUID) {
        let linked = diffTabs.filter { $0.sourceTabID == sourceID }.map(\.id)
        for id in linked {
            removeDiffTab(id: id)
        }
    }

    /// Jump from a hunk into the source editor buffer.
    func focusDiffHunk(_ session: BufferDiskDiffSession, hunk: DiffHunk) {
        guard let tab = tabs.first(where: { $0.id == session.sourceTabID }) else {
            // Fall back to opening the path if the tab was somehow removed.
            if let line = hunk.bufferLine ?? hunk.diskLine {
                openURL(session.fileURL, viewMode: false, line: line)
            } else {
                openURL(session.fileURL, viewMode: false, line: nil)
            }
            return
        }
        let line = hunk.bufferLine ?? hunk.diskLine
        focus(tab, viewMode: false, line: line, reloadIfClean: false, fileURL: session.fileURL)
    }

    /// Confirm and replace the source buffer with disk contents.
    func revertDiffToDisk(_ session: BufferDiskDiffSession) {
        guard let tab = tabs.first(where: { $0.id == session.sourceTabID }) else {
            let alert = NSAlert()
            alert.messageText = "Source tab closed"
            alert.informativeText = "The editor tab for this file is no longer open."
            alert.runModal()
            return
        }
        let name = session.fileURL.lastPathComponent
        let alert = NSAlert()
        alert.messageText = "Revert “\(name)” to disk?"
        alert.informativeText = "Replace the buffer with the contents from disk? Unsaved edits will be lost."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Revert to Disk")
        alert.addButton(withTitle: "Cancel")

        let applyRevert: () -> Void = { [weak self] in
            guard let self else { return }
            let disk = BufferDiskDiff.readDisk(url: session.fileURL)
            if let err = disk.error {
                NSAlert(error: NSError(
                    domain: "EditForth",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: err]
                )).runModal()
                return
            }
            guard let text = disk.text else {
                let missing = NSAlert()
                missing.messageText = "Disk file missing"
                missing.informativeText = "Cannot revert — \(name) is not on disk."
                missing.runModal()
                return
            }
            tab.text = text
            tab.isDirty = false
            self.objectWillChange.send()
            self.refreshDocumentEdited()
            session.reload()
        }

        if let window = Self.sheetHostWindow() {
            alert.beginSheetModal(for: window) { response in
                guard response == .alertFirstButtonReturn else { return }
                applyRevert()
            }
        } else if alert.runModal() == .alertFirstButtonReturn {
            applyRevert()
        }
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
        // Drop linked diff tabs before removing the file tab.
        removeDiffTabs(forSourceTabID: id)
        tabCancellables[id] = nil
        tabs.remove(at: index)
        if selectedTabID == id {
            if tabs.isEmpty {
                selectedTabID = searchTabs.last?.id ?? diffTabs.last?.id
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

    /// Cold-launch only: open Docs/GettingStarted.txt when nothing was opened
    /// via `open -a` / pending-goto. Closing the last tab leaves the empty
    /// placeholder (New File / Open…).
    func openStartupDocument() {
        guard tabs.isEmpty, searchTabs.isEmpty, diffTabs.isEmpty else { return }
        let note = ForthMenuSupport.userTreeURL
            .appendingPathComponent("Docs/GettingStarted.txt", isDirectory: false)
        if !FileManager.default.fileExists(atPath: note.path) {
            seedStartupDocument(at: note)
        }
        if FileManager.default.fileExists(atPath: note.path) {
            _ = openURL(note, viewMode: true)
            return
        }
        _ = newFile()
    }

    /// Put the shipped note in Documents/EditForth/Docs when the user tree
    /// does not have it yet. The companion sync can still be in flight.
    private func seedStartupDocument(at note: URL) {
        let fm = FileManager.default
        guard let shipped = Bundle.main.url(
            forResource: "GettingStarted",
            withExtension: "txt",
            subdirectory: "Docs"
        ), fm.fileExists(atPath: shipped.path) else { return }
        let dir = note.deletingLastPathComponent()
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            if !fm.fileExists(atPath: note.path) {
                try fm.copyItem(at: shipped, to: note)
            }
        } catch {
            return
        }
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

    func findTab(matching path: String) -> EditorTab? {
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
        // Docs and System stay read-only. Otherwise nil preserves the current mode
        // so open -a does not strip VIEW/debug browse mode.
        let locked = (fileURL ?? tab.fileURL).map(ForthMenuSupport.opensReadOnly) ?? false
        if locked {
            tab.isViewMode = true
        } else if let viewMode {
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
