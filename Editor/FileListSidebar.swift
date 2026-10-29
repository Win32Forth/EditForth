//
//  FileListSidebar.swift
//  EditForth
//
//  Left-hand list of the folders and files under one directory.
//  The directory starts at ~/Documents/EditForth with Docs open.
//  New, Save, and Share
//  use the same document actions as the File menu. Share runs Save As.
//

import AppKit
import Combine
import CoreServices
import SwiftUI
import UniformTypeIdentifiers

struct FileListEntry: Identifiable {
    let path: String
    let name: String
    let isDirectory: Bool
    /// Populated for a real directory. Nil for a file or a package.
    let children: [FileListEntry]?

    var id: String { path }
}

/// Watches one folder and publishes its tree. The root is not persisted:
/// each launch starts at Documents/EditForth.
final class FileListModel: ObservableObject {
    @Published private(set) var root: URL
    @Published private(set) var entries: [FileListEntry] = []
    @Published private(set) var expanded: Set<String> = []

    private var stream: FSEventStreamRef?
    private var generation = 0
    private var reloadWork: DispatchWorkItem?
    private var revealedPath = ""
    private var lastSelection: URL?

    init() {
        root = ForthMenuSupport.userTreeURL.standardizedFileURL
        let docs = root.appendingPathComponent("Docs", isDirectory: true)
        if FileManager.default.fileExists(atPath: docs.path) {
            expanded = [docs.standardizedFileURL.path]
        }
        startWatching()
        reload()
    }

    deinit {
        stopWatching()
    }

    var displayRoot: String {
        let path = root.path
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        if path == home { return "~" }
        if path.hasPrefix(home + "/") {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    func isExpanded(_ path: String) -> Bool {
        expanded.contains(path)
    }

    func toggleExpanded(_ path: String) {
        var next = expanded
        if next.contains(path) {
            next.remove(path)
        } else {
            next.insert(path)
        }
        expanded = next
    }

    /// Open a native folder panel and list that directory.
    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.message = "Show the folders and files in this directory."
        panel.directoryURL = root
        guard panel.runModal() == .OK, let url = panel.url else { return }
        setRoot(url)
    }

    func setRoot(_ url: URL) {
        root = url.standardizedFileURL
        expanded = []
        revealedPath = ""
        stopWatching()
        startWatching()
        reload()
        noteSelection(lastSelection)
    }

    /// Expand the folders above `url` once, when the selected file changes.
    func noteSelection(_ url: URL?) {
        lastSelection = url
        let path = url?.standardizedFileURL.path ?? ""
        guard path != revealedPath else { return }
        revealedPath = path
        guard let url else { return }
        let filePath = url.standardizedFileURL.path
        let rootPath = root.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard filePath.hasPrefix(prefix) else { return }
        let parts = filePath.dropFirst(prefix.count).split(separator: "/").map(String.init)
        guard parts.count > 1 else { return }
        var next = expanded
        var acc = rootPath
        for part in parts.dropLast() {
            acc += "/" + part
            next.insert(acc)
        }
        expanded = next
    }

    func scheduleReload() {
        reloadWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.reload()
        }
        reloadWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    func reload() {
        if stream == nil {
            startWatching()
        }
        generation += 1
        let token = generation
        let directory = root
        DispatchQueue.global(qos: .userInitiated).async {
            let found = Self.scan(directory)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == token else { return }
                self.entries = found
            }
        }
    }

    /// Text the editor can open. Packages and other files stay in the list
    /// and are revealed in Finder instead.
    static func opensInEditor(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .isPackageKey])
        guard values?.isRegularFile == true, values?.isPackage != true else { return false }
        if let size = values?.fileSize, size > 2_000_000 { return false }
        let ext = url.pathExtension
        if ext.isEmpty { return true }
        guard let type = UTType(filenameExtension: ext) else { return false }
        return type.conforms(to: .text)
            || type.conforms(to: .sourceCode)
            || type.conforms(to: .forthSource)
            || type.conforms(to: .plainText)
    }

    private static func scan(_ directory: URL) -> [FileListEntry] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: directory.path) else { return [] }
        return children(of: directory, fileManager: fm)
    }

    private static func children(of directory: URL, fileManager: FileManager) -> [FileListEntry] {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var folders: [FileListEntry] = []
        var files: [FileListEntry] = []
        for raw in urls {
            let url = raw.standardizedFileURL
            let name = url.lastPathComponent
            if name.hasPrefix(".") { continue }
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
            let isFolder = values?.isDirectory == true && values?.isPackage != true
            if isFolder {
                folders.append(FileListEntry(
                    path: url.path,
                    name: name,
                    isDirectory: true,
                    children: children(of: url, fileManager: fileManager)
                ))
            } else {
                files.append(FileListEntry(
                    path: url.path,
                    name: name,
                    isDirectory: false,
                    children: nil
                ))
            }
        }
        let byName: (FileListEntry, FileListEntry) -> Bool = {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        return folders.sorted(by: byName) + files.sorted(by: byName)
    }

    private func startWatching() {
        stopWatching()
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagNoDefer)
        guard let created = FSEventStreamCreate(
            nil,
            { _, info, _, _, _, _ in
                guard let info else { return }
                let model = Unmanaged<FileListModel>.fromOpaque(info).takeUnretainedValue()
                model.scheduleReload()
            },
            &context,
            [root.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.3,
            flags
        ) else { return }
        stream = created
        FSEventStreamSetDispatchQueue(created, .main)
        FSEventStreamStart(created)
    }

    private func stopWatching() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }
}

struct FileListSidebar: View {
    @ObservedObject var model: FileListModel
    @ObservedObject var workspace: WorkspaceModel

    private var currentPath: String? {
        workspace.selectedTab?.fileURL?.standardizedFileURL.path
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Button("New") {
                    workspace.newFile()
                }
                .help("New File")
                Button("Save") {
                    if workspace.saveSelected() {
                        model.scheduleReload()
                    }
                }
                .disabled(workspace.selectedTab == nil)
                .help("Save")
                Button("Share") {
                    if workspace.saveSelectedAs(directory: model.root) {
                        model.scheduleReload()
                    }
                }
                .disabled(workspace.selectedTab == nil)
                .help("Save As")
            }
            .controlSize(.small)
            .buttonStyle(.bordered)
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 6)

            Button {
                model.chooseFolder()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                    Text(model.displayRoot)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help("Choose the folder this list shows. \(model.root.path)")
            .padding(.horizontal, 8)
            .padding(.bottom, 6)

            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1)

            if model.entries.isEmpty {
                Text(emptyMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(10)
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        FileListBranch(
                            entries: model.entries,
                            depth: 0,
                            model: model,
                            currentPath: currentPath,
                            onOpen: openFile
                        )
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .controlBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("File list")
        .onAppear {
            model.noteSelection(workspace.selectedTab?.fileURL)
        }
        .onChange(of: workspace.selectedTab?.fileURL?.path) { _, _ in
            model.noteSelection(workspace.selectedTab?.fileURL)
        }
    }

    private var emptyMessage: String {
        if FileManager.default.fileExists(atPath: model.root.path) {
            return "This folder is empty."
        }
        return "This folder is not there yet."
    }

    private func openFile(_ url: URL) {
        if FileListModel.opensInEditor(url) {
            workspace.openURL(url, viewMode: false)
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
}

private struct FileListBranch: View {
    let entries: [FileListEntry]
    let depth: Int
    @ObservedObject var model: FileListModel
    let currentPath: String?
    let onOpen: (URL) -> Void

    var body: some View {
        ForEach(entries) { entry in
            Button {
                if entry.isDirectory {
                    model.toggleExpanded(entry.path)
                } else {
                    onOpen(URL(fileURLWithPath: entry.path))
                }
            } label: {
                HStack(spacing: 4) {
                    if entry.isDirectory {
                        Image(systemName: model.isExpanded(entry.path) ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 12)
                        Image(systemName: "folder")
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.secondary)
                            .padding(.leading, 16)
                    }
                    Text(entry.name)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 0)
                }
                .font(.system(size: 12))
                .padding(.leading, 8 + CGFloat(depth) * 14)
                .padding(.trailing, 6)
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    currentPath == entry.path
                        ? Color.accentColor.opacity(0.22)
                        : Color.clear
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(entry.name)

            if entry.isDirectory, model.isExpanded(entry.path) {
                FileListBranch(
                    entries: entry.children ?? [],
                    depth: depth + 1,
                    model: model,
                    currentPath: currentPath,
                    onOpen: onOpen
                )
            }
        }
    }
}
