//
//  SearchFoldersPanel.swift
//  EditForth
//
//  Edit → Search in Folders… dialog with remembered queries and extension
//  sets. Up to three folder rows, each an editable path with Choose… and
//  Clear. Nested (recursive) vs folder-level only.
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
    /// `editing` fills the dialog from that results tab so Modify Search
    /// changes the search that is already open.
    static func run(workspace: WorkspaceModel, editing session: SearchSession? = nil) {
        let alert = NSAlert()
        alert.messageText = "Search in Folders"
        alert.informativeText =
            "Type a query and an extension set. Each folder row is one directory. " +
            "Choose… picks a folder; Clear stops searching that row. " +
            "Nested searches subfolders; off searches only the listed folders."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Search")
        alert.addButton(withTitle: "Cancel")

        // Frame-based accessory layout: NSAlert clips Auto Layout accessory
        // views (the top "Find:" label was reduced to a few pixels).
        let width: CGFloat = 520
        let labelH: CGFloat = 18
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
        matchCaseBox.state = (session?.caseSensitive ?? SearchHistory.caseSensitiveDefault) ? .on : .off
        let wholeWordBox = NSButton(checkboxWithTitle: "Whole Word", target: nil, action: nil)
        wholeWordBox.state = (session?.wholeWord ?? SearchHistory.wholeWordDefault) ? .on : .off

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
        queryCombo.stringValue = session?.query ?? SearchHistory.queries.first ?? ""

        // --- Folders: three editable paths, each with Choose… and Clear ---
        let rootsLabel = makeLabel("Folders:")
        let savedFolders: [String]
        if let session {
            savedFolders = session.roots.map(\.path)
        } else {
            savedFolders = SearchHistory.folderSets.first.map {
                $0.split(whereSeparator: \.isNewline)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            } ?? []
        }
        var initialFolders = Array(savedFolders.prefix(FolderPathRows.count))
        if initialFolders.isEmpty {
            initialFolders = [ForthMenuSupport.userTreeURL.path]
        }
        while initialFolders.count < FolderPathRows.count {
            initialFolders.append("")
        }

        let chooseProbe = Self.folderButton("Choose…")
        let clearProbe = Self.folderButton("Clear")
        let buttonGap: CGFloat = 6
        let rowH = max(26, chooseProbe.frame.height, clearProbe.frame.height)
        let fieldW = width - chooseProbe.frame.width - clearProbe.frame.width - buttonGap * 2
        var folderFields: [NSTextField] = []
        var folderRows: [NSView] = []
        for index in 0..<FolderPathRows.count {
            let row = NSView(frame: NSRect(x: 0, y: 0, width: width, height: rowH))
            let field = NSTextField(frame: NSRect(x: 0, y: 0, width: fieldW, height: rowH))
            field.stringValue = initialFolders[index]
            field.placeholderString = index == 0 ? "Folder path" : "Optional folder"
            field.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            field.lineBreakMode = .byTruncatingHead
            field.cell?.wraps = false
            let choose = Self.folderButton("Choose…")
            let clear = Self.folderButton("Clear")
            choose.tag = index
            clear.tag = index
            choose.frame = NSRect(
                x: fieldW + buttonGap,
                y: (rowH - choose.frame.height) / 2,
                width: choose.frame.width,
                height: choose.frame.height
            )
            clear.frame = NSRect(
                x: fieldW + buttonGap * 2 + choose.frame.width,
                y: (rowH - clear.frame.height) / 2,
                width: clear.frame.width,
                height: clear.frame.height
            )
            row.addSubview(field)
            row.addSubview(choose)
            row.addSubview(clear)
            folderFields.append(field)
            folderRows.append(row)
        }
        let folderRowsController = FolderPathRows(fields: folderFields)
        for row in folderRows {
            for view in row.subviews {
                guard let button = view as? NSButton else { continue }
                button.target = folderRowsController
                button.action = button.title == "Clear"
                    ? #selector(FolderPathRows.clear(_:))
                    : #selector(FolderPathRows.choose(_:))
            }
        }

        // --- Extensions (history of sets) ---
        let extLabel = makeLabel("Extensions (comma-separated sets):")
        let extCombo = NSComboBox(frame: .zero)
        extCombo.isEditable = true
        extCombo.completes = true
        extCombo.numberOfVisibleItems = 12
        for set in SearchHistory.extensionSets {
            extCombo.addItem(withObjectValue: set)
        }
        extCombo.stringValue = session.map { $0.extensions.joined(separator: ", ") }
            ?? SearchHistory.extensionSets.first
            ?? FolderSearch.defaultExtensions.joined(separator: ", ")

        let nestedBox = NSButton(
            checkboxWithTitle: "Search nested folders",
            target: nil,
            action: nil
        )
        nestedBox.state = (session?.recursive ?? SearchHistory.nestedDefault) ? .on : .off

        // Top-down layout inside a fixed frame (y decreases from top).
        var rows: [(NSView, CGFloat)] = [
            (findHeader, findHeaderH),
            (queryCombo, 26),
            (rootsLabel, labelH)
        ]
        for row in folderRows {
            rows.append((row, rowH))
        }
        rows.append((extLabel, labelH))
        rows.append((extCombo, 26))
        rows.append((nestedBox, checkH))
        var totalH: CGFloat = 4 // top pad so Find: is not clipped by the alert edge
        for (i, row) in rows.enumerated() {
            if i > 0 {
                let beforeExt = (row.0 === extLabel)
                let beforeNested = (row.0 === nestedBox)
                totalH += (beforeExt || beforeNested) ? sectionGap : gap
            }
            totalH += row.1
        }
        totalH += 4

        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: totalH))
        var y = totalH - 4
        for (i, row) in rows.enumerated() {
            if i > 0 {
                let beforeExt = (row.0 === extLabel)
                let beforeNested = (row.0 === nestedBox)
                y -= (beforeExt || beforeNested) ? sectionGap : gap
            }
            y -= row.1
            row.0.frame = NSRect(x: 0, y: y, width: width, height: row.1)
            container.addSubview(row.0)
        }

        alert.accessoryView = container
        // Keep the row controller alive for the modal session.
        objc_setAssociatedObject(
            alert,
            &FolderPathRows.assocKey,
            folderRowsController,
            .OBJC_ASSOCIATION_RETAIN
        )
        alert.window.initialFirstResponder = queryCombo

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        let query = queryCombo.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        let rootLines = folderFields.map {
            $0.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }
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
        SearchHistory.rememberFolderSet(rootLines.joined(separator: "\n"))
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

    private static func folderButton(_ title: String) -> NSButton {
        let button = NSButton(title: title, target: nil, action: nil)
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        button.sizeToFit()
        return button
    }
}

/// Three folder paths for Search in Folders. Choose… uses a directory panel
/// like CHDIR. Clear empties that row so it is not searched.
private final class FolderPathRows: NSObject {
    static var assocKey: UInt8 = 0
    static let count = 3

    private let fields: [NSTextField]

    init(fields: [NSTextField]) {
        self.fields = fields
    }

    @objc func choose(_ sender: NSButton) {
        let index = sender.tag
        guard fields.indices.contains(index) else { return }
        let field = fields[index]
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "Choose"
        panel.message = "Choose a folder to search"
        panel.directoryURL = Self.startURL(for: field.stringValue)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        field.stringValue = url.path
    }

    @objc func clear(_ sender: NSButton) {
        let index = sender.tag
        guard fields.indices.contains(index) else { return }
        fields[index].stringValue = ""
    }

    private static func startURL(for raw: String) -> URL {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let expanded = (trimmed as NSString).expandingTildeInPath
        let fm = FileManager.default
        if !expanded.isEmpty {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: expanded, isDirectory: &isDir) {
                let url = URL(fileURLWithPath: expanded, isDirectory: isDir.boolValue)
                return isDir.boolValue ? url : url.deletingLastPathComponent()
            }
            let parent = (expanded as NSString).deletingLastPathComponent
            if fm.fileExists(atPath: parent) {
                return URL(fileURLWithPath: parent, isDirectory: true)
            }
        }
        return ForthMenuSupport.userTreeURL
    }
}
