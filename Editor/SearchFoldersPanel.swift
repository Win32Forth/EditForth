//
//  SearchFoldersPanel.swift
//  EditForth
//
//  Edit → Search in Folders… dialog with remembered queries, folder sets,
//  and extension sets; nested (recursive) vs folder-level only.
//  Accessory view is frame-laid-out (NSAlert clips Auto Layout tops).
//

import AppKit

/// Persisted MRU lists for the Search in Folders dialog.
enum SearchHistory {
    static let maxEntries = 20

    private static let queriesKey = "searchHistory.queries"
    private static let folderSetsKey = "searchHistory.folderSets"
    private static let extensionSetsKey = "searchHistory.extensionSets"
    private static let nestedKey = "searchHistory.nestedDefault"
    private static let caseKey = "searchHistory.caseSensitiveDefault"
    private static let wholeWordKey = "searchHistory.wholeWordDefault"

    static var queries: [String] {
        get { UserDefaults.standard.stringArray(forKey: queriesKey) ?? [] }
        set { UserDefaults.standard.set(Array(newValue.prefix(maxEntries)), forKey: queriesKey) }
    }

    /// Each entry is one or more folder paths joined by newlines.
    static var folderSets: [String] {
        get { UserDefaults.standard.stringArray(forKey: folderSetsKey) ?? [] }
        set { UserDefaults.standard.set(Array(newValue.prefix(maxEntries)), forKey: folderSetsKey) }
    }

    /// Each entry is a comma-separated extension set, e.g. `fth, fs, 4th`.
    static var extensionSets: [String] {
        get {
            let stored = UserDefaults.standard.stringArray(forKey: extensionSetsKey) ?? []
            if stored.isEmpty {
                return [FolderSearch.defaultExtensions.joined(separator: ", ")]
            }
            return stored
        }
        set { UserDefaults.standard.set(Array(newValue.prefix(maxEntries)), forKey: extensionSetsKey) }
    }

    static var nestedDefault: Bool {
        get {
            if UserDefaults.standard.object(forKey: nestedKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: nestedKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: nestedKey) }
    }

    static var caseSensitiveDefault: Bool {
        get { UserDefaults.standard.bool(forKey: caseKey) }
        set { UserDefaults.standard.set(newValue, forKey: caseKey) }
    }

    static var wholeWordDefault: Bool {
        get { UserDefaults.standard.bool(forKey: wholeWordKey) }
        set { UserDefaults.standard.set(newValue, forKey: wholeWordKey) }
    }

    static func rememberQuery(_ raw: String) {
        let q = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        queries = prependUnique(q, onto: queries)
    }

    static func rememberFolderSet(_ raw: String) {
        let normalized = normalizeFolderSet(raw)
        guard !normalized.isEmpty else { return }
        folderSets = prependUnique(normalized, onto: folderSets)
    }

    static func rememberExtensionSet(_ raw: String) {
        let normalized = normalizeExtensionSet(raw)
        guard !normalized.isEmpty else { return }
        extensionSets = prependUnique(normalized, onto: extensionSets)
    }

    static func normalizeFolderSet(_ raw: String) -> String {
        raw.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    static func normalizeExtensionSet(_ raw: String) -> String {
        raw.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.hasPrefix(".") ? String($0.dropFirst()) : $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    private static func prependUnique(_ item: String, onto list: [String]) -> [String] {
        var out = list.filter { $0.caseInsensitiveCompare(item) != .orderedSame }
        out.insert(item, at: 0)
        return Array(out.prefix(maxEntries))
    }
}

enum SearchFoldersPanel {
    /// Present the dialog; on OK, open a search tab on `workspace`.
    static func run(workspace: WorkspaceModel) {
        let alert = NSAlert()
        alert.messageText = "Search in Folders"
        alert.informativeText =
            "Pick or type a query, folder set, and extension set. " +
            "Nested searches subfolders; off searches only the listed folders."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Search")
        alert.addButton(withTitle: "Cancel")

        // Frame-based accessory layout: NSAlert clips Auto Layout accessory
        // views (the top "Find:" label was reduced to a few pixels).
        let width: CGFloat = 440
        let labelH: CGFloat = 18
        let fieldH: CGFloat = 26
        let rootsH: CGFloat = 72
        let checkH: CGFloat = 18
        let gap: CGFloat = 6
        let sectionGap: CGFloat = 10

        func makeLabel(_ title: String) -> NSTextField {
            let lab = NSTextField(labelWithString: title)
            lab.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
            return lab
        }

        // --- Find row: "Find:" + Match Case + Whole Word ---
        let queryLabel = makeLabel("Find:")
        let matchCaseBox = NSButton(checkboxWithTitle: "Match Case", target: nil, action: nil)
        matchCaseBox.state = SearchHistory.caseSensitiveDefault ? .on : .off
        let wholeWordBox = NSButton(checkboxWithTitle: "Whole Word", target: nil, action: nil)
        wholeWordBox.state = SearchHistory.wholeWordDefault ? .on : .off

        let findHeader = NSView(frame: .zero)
        // Size checkboxes from their intrinsic titles, pack to the right of Find:.
        matchCaseBox.sizeToFit()
        wholeWordBox.sizeToFit()
        queryLabel.sizeToFit()
        let findHeaderH = max(labelH, matchCaseBox.frame.height, wholeWordBox.frame.height)
        findHeader.frame = NSRect(x: 0, y: 0, width: width, height: findHeaderH)
        queryLabel.frame = NSRect(
            x: 0,
            y: (findHeaderH - queryLabel.frame.height) / 2,
            width: queryLabel.frame.width,
            height: queryLabel.frame.height
        )
        let checkGap: CGFloat = 12
        let wholeX = width - wholeWordBox.frame.width
        let matchX = wholeX - checkGap - matchCaseBox.frame.width
        matchCaseBox.frame = NSRect(
            x: matchX,
            y: (findHeaderH - matchCaseBox.frame.height) / 2,
            width: matchCaseBox.frame.width,
            height: matchCaseBox.frame.height
        )
        wholeWordBox.frame = NSRect(
            x: wholeX,
            y: (findHeaderH - wholeWordBox.frame.height) / 2,
            width: wholeWordBox.frame.width,
            height: wholeWordBox.frame.height
        )
        findHeader.addSubview(queryLabel)
        findHeader.addSubview(matchCaseBox)
        findHeader.addSubview(wholeWordBox)

        let queryCombo = NSComboBox(frame: .zero)
        queryCombo.isEditable = true
        queryCombo.completes = true
        queryCombo.numberOfVisibleItems = 12
        for q in SearchHistory.queries {
            queryCombo.addItem(withObjectValue: q)
        }
        queryCombo.addItem(withObjectValue: "") // blank to clear / type new
        queryCombo.stringValue = SearchHistory.queries.first ?? ""

        // --- Folders: history combo picks a set; text view edits the active set ---
        let rootsLabel = makeLabel("Folders (one path per line):")
        let folderCombo = NSComboBox(frame: .zero)
        folderCombo.isEditable = false
        folderCombo.numberOfVisibleItems = 12
        folderCombo.addItem(withObjectValue: "(current)")
        for set in SearchHistory.folderSets {
            folderCombo.addItem(withObjectValue: Self.folderSetMenuTitle(set))
        }
        folderCombo.selectItem(at: 0)

        let rootsScroll = NSScrollView(frame: .zero)
        rootsScroll.hasVerticalScroller = true
        rootsScroll.borderType = .bezelBorder
        rootsScroll.autohidesScrollers = true
        let rootsView = NSTextView(frame: NSRect(x: 0, y: 0, width: width, height: rootsH))
        rootsView.minSize = NSSize(width: 0, height: 0)
        rootsView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        rootsView.isVerticallyResizable = true
        rootsView.isHorizontallyResizable = false
        rootsView.autoresizingMask = [.width]
        rootsView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        if let first = SearchHistory.folderSets.first {
            rootsView.string = first
        } else {
            rootsView.string = ForthMenuSupport.userTreeURL.path
        }
        rootsScroll.documentView = rootsView

        let folderBridge = FolderSetComboBridge(combo: folderCombo, textView: rootsView)
        folderCombo.target = folderBridge
        folderCombo.action = #selector(FolderSetComboBridge.selectionChanged(_:))

        // --- Extensions (history of sets) ---
        let extLabel = makeLabel("Extensions (comma-separated sets):")
        let extCombo = NSComboBox(frame: .zero)
        extCombo.isEditable = true
        extCombo.completes = true
        extCombo.numberOfVisibleItems = 12
        for set in SearchHistory.extensionSets {
            extCombo.addItem(withObjectValue: set)
        }
        extCombo.stringValue = SearchHistory.extensionSets.first
            ?? FolderSearch.defaultExtensions.joined(separator: ", ")

        let nestedBox = NSButton(
            checkboxWithTitle: "Search nested folders",
            target: nil,
            action: nil
        )
        nestedBox.state = SearchHistory.nestedDefault ? .on : .off

        // Top-down layout inside a fixed frame (y decreases from top).
        let rows: [(NSView, CGFloat)] = [
            (findHeader, findHeaderH),
            (queryCombo, fieldH),
            (rootsLabel, labelH),
            (folderCombo, fieldH),
            (rootsScroll, rootsH),
            (extLabel, labelH),
            (extCombo, fieldH),
            (nestedBox, checkH)
        ]
        var totalH: CGFloat = 4 // top pad so Find: is not clipped by the alert edge
        for (i, row) in rows.enumerated() {
            if i > 0 {
                let afterRootsLabel = (rows[i - 1].0 === rootsLabel)
                let beforeExt = (row.0 === extLabel)
                let beforeNested = (row.0 === nestedBox)
                totalH += (afterRootsLabel || beforeExt || beforeNested) ? sectionGap : gap
            }
            totalH += row.1
        }
        totalH += 4

        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: totalH))
        var y = totalH - 4
        for (i, row) in rows.enumerated() {
            if i > 0 {
                let afterRootsLabel = (rows[i - 1].0 === rootsLabel)
                let beforeExt = (row.0 === extLabel)
                let beforeNested = (row.0 === nestedBox)
                y -= (afterRootsLabel || beforeExt || beforeNested) ? sectionGap : gap
            }
            y -= row.1
            row.0.frame = NSRect(x: 0, y: y, width: width, height: row.1)
            container.addSubview(row.0)
        }

        alert.accessoryView = container
        // Keep bridge alive for the modal session.
        objc_setAssociatedObject(
            alert,
            &FolderSetComboBridge.assocKey,
            folderBridge,
            .OBJC_ASSOCIATION_RETAIN
        )
        alert.window.initialFirstResponder = queryCombo

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        let query = queryCombo.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        let rootLines = rootsView.string
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let roots = rootLines.map {
            URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath)
        }
        guard !roots.isEmpty else { return }

        let extRaw = SearchHistory.normalizeExtensionSet(extCombo.stringValue)
        let exts = extRaw
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let nested = nestedBox.state == .on
        let matchCase = matchCaseBox.state == .on
        let wholeWord = wholeWordBox.state == .on

        SearchHistory.rememberQuery(query)
        SearchHistory.rememberFolderSet(rootsView.string)
        SearchHistory.rememberExtensionSet(extRaw.isEmpty
            ? FolderSearch.defaultExtensions.joined(separator: ", ")
            : extRaw)
        SearchHistory.nestedDefault = nested
        SearchHistory.caseSensitiveDefault = matchCase
        SearchHistory.wholeWordDefault = wholeWord

        workspace.openSearch(
            query: query,
            roots: roots,
            extensions: exts.isEmpty ? FolderSearch.defaultExtensions : exts,
            caseSensitive: matchCase,
            wholeWord: wholeWord,
            recursive: nested,
            replaceSelectedSearch: true
        )
    }

    private static func folderSetMenuTitle(_ set: String) -> String {
        let lines = set.split(whereSeparator: \.isNewline).map(String.init)
        guard let first = lines.first else { return "(empty)" }
        if lines.count == 1 {
            return shortenedPath(first)
        }
        return "\(shortenedPath(first)) +\(lines.count - 1) more"
    }

    private static func shortenedPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}

/// Fills the folders text view when a remembered folder set is chosen.
private final class FolderSetComboBridge: NSObject {
    static var assocKey: UInt8 = 0

    private weak var combo: NSComboBox?
    private weak var textView: NSTextView?

    init(combo: NSComboBox, textView: NSTextView) {
        self.combo = combo
        self.textView = textView
    }

    @objc func selectionChanged(_ sender: NSComboBox) {
        let idx = sender.indexOfSelectedItem
        // 0 = "(current)" — leave the text view alone.
        guard idx > 0 else { return }
        let sets = SearchHistory.folderSets
        let setIndex = idx - 1
        guard sets.indices.contains(setIndex) else { return }
        textView?.string = sets[setIndex]
    }
}
