//
//  ForthMenuSupport.swift
//  EditForth
//
//  Forth menu actions hosted in EditForth’s menu bar (the floating console is
//  an EditForth window, so the companion process menu bar never becomes active).
//

import AppKit
import UniformTypeIdentifiers

enum ForthMenuSupport {

    /// Documents/EditForth tree (FileHost user data for this project).
    static var userTreeURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("EditForth", isDirectory: true)
    }

    /// True when `url` is inside `Documents/EditForth/<folder>/`.
    static func isInUserTreeFolder(_ url: URL, named folder: String) -> Bool {
        let path = url.standardizedFileURL.path
        let root = userTreeURL.standardizedFileURL.path
        guard path.hasPrefix(root + "/") else { return false }
        let rest = path.dropFirst(root.count + 1)
        guard let top = rest.split(separator: "/", maxSplits: 1).first else { return false }
        return String(top).caseInsensitiveCompare(folder) == .orderedSame
    }

    /// Docs and System open read-only. Library and files outside the tree stay editable.
    static func opensReadOnly(_ url: URL) -> Bool {
        isInUserTreeFolder(url, named: "Docs") || isInUserTreeFolder(url, named: "System")
    }

    static let loadRefusedMessage =
        "Only .fth, .fs, and .f files can be loaded, and you cannot load a system file because they are already loaded."

    /// True when `url` is Documents/EditForth/System/Testing or a file under it.
    static func isUnderUserTreeTesting(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let testing = userTreeURL.standardizedFileURL.path + "/System/Testing"
        if path.caseInsensitiveCompare(testing) == .orderedSame { return true }
        return path.range(of: testing + "/", options: [.caseInsensitive, .anchored]) != nil
    }

    /// INCLUDE / FLOAD: `.fth`, `.fs`, and `.f` only.
    /// System files are refused, except files under System/Testing.
    static func canLoadForthFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        let allowed = ext == "fth" || ext == "fs" || ext == "f"
        let systemBlocked = isInUserTreeFolder(url, named: "System") && !isUnderUserTreeTesting(url)
        return allowed && !systemBlocked
    }

    /// Shows the load dialog and returns true when INCLUDE / FLOAD must stop.
    @discardableResult
    static func refuseLoadIfNeeded(_ url: URL) -> Bool {
        guard canLoadForthFile(url) else {
            let alert = NSAlert()
            alert.messageText = loadRefusedMessage
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return true
        }
        return false
    }

    /// Finder window on Documents/EditForth (Library, System, Docs).
    static func openUserTree() {
        let url = userTreeURL
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.open(url)
        } else {
            revealInFinder(url)
        }
    }

    static func revealInFinder(_ url: URL?) {
        guard let url else { return }
        let path = url.path
        if FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            NSWorkspace.shared.open(url.deletingLastPathComponent())
        }
    }

    static func clearConsole(forth: ForthConnectionManager) {
        forth.clearConsoleDisplay()
    }

    /// Help → Show Boot Messages: ask the companion to append cold-bootstrap emit.
    static func showBootMessages(forth: ForthConnectionManager) {
        forth.send(.showBootMessages)
    }

    static func presentFload(forth: ForthConnectionManager) {
        let panel = makeFloadPanel(forth: forth)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        includeFile(at: url, forth: forth, autoAnew: false)
    }

    /// Status-panel / F4: save the current tab if needed, `ANEW <stem>_MODULE`, then `INCLUDED`.
    /// Auto-ANEW lets the same file reload without an `ANEW` line in the source.
    /// A clean Untitled tab has nothing to save. Pick a file, show it, then INCLUDE it.
    /// A dirty Untitled still asks to save first.
    static func includeCurrentTab(workspace: WorkspaceModel, forth: ForthConnectionManager) {
        guard forth.isConnected else { return }
        guard !forth.isDebugSessionArmed else {
            forth.noteUserError("debugger paused — use Step/Continue")
            return
        }
        guard let tab = workspace.selectedTab else {
            forth.noteUserError("INCLUDE needs an open editor tab")
            return
        }
        if tab.fileURL == nil && !tab.isDirty {
            includePickedFile(workspace: workspace, forth: forth, replacingTabID: tab.id)
            return
        }
        if tab.isDirty || tab.fileURL == nil {
            guard workspace.saveSelected() else { return }
        }
        guard let url = tab.fileURL else {
            forth.noteUserError("INCLUDE needs a saved file")
            return
        }
        includeFile(at: url, forth: forth, autoAnew: true)
    }

    /// Clean Untitled INCLUDE: same panel as bare FLOAD, open the file, then INCLUDE it.
    private static func includePickedFile(
        workspace: WorkspaceModel,
        forth: ForthConnectionManager,
        replacingTabID: UUID
    ) {
        let panel = makeFloadPanel(forth: forth)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let opened = workspace.openURL(url, viewMode: false, line: nil) else {
            forth.noteUserError("INCLUDE could not open \(url.lastPathComponent)")
            return
        }
        if opened.id != replacingTabID {
            workspace.closeTab(id: replacingTabID)
        }
        includeFile(at: opened.fileURL ?? url, forth: forth, autoAnew: true)
    }

    private static func makeFloadPanel(forth: ForthConnectionManager) -> NSOpenPanel {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            UTType(filenameExtension: "fth") ?? .plainText,
            UTType(filenameExtension: "fs") ?? .plainText,
            UTType(filenameExtension: "4th") ?? .plainText,
            .plainText
        ]
        panel.directoryURL = forth.panelStartURL
        panel.prompt = "Load"
        panel.message = "FLOAD / INCLUDE a Forth source file"
        return panel
    }

    /// Status-panel EMIT: re-INCLUDE current tab (flags from source), then `EMIT-AUTO-FILE`.
    /// Artifacts: `<source-dir>/<STEM>/{STEM.app,STEM.img,STEM.emit.log}`.
    static func emitCurrentTab(workspace: WorkspaceModel, forth: ForthConnectionManager) {
        guard forth.isConnected else { return }
        guard !forth.isDebugSessionArmed else {
            forth.noteUserError("debugger paused — use Step/Continue")
            return
        }
        guard let tab = workspace.selectedTab else {
            forth.noteUserError("EMIT needs an open editor tab")
            return
        }
        if tab.isDirty || tab.fileURL == nil {
            guard workspace.saveSelected() else { return }
        }
        guard let url = tab.fileURL else {
            forth.noteUserError("EMIT needs a saved file")
            return
        }
        if refuseLoadIfNeeded(url) { return }
        let path = url.standardizedFileURL.path
        let escaped = path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let marker = moduleMarkerName(for: url)
        let stem = url.deletingPathExtension().lastPathComponent.uppercased()
        // Immediate editor-side feedback: quiet emit hides INCLUDE/emit chatter.
        forth.noteInfo("Emitting \(stem)/\(stem).app …")
        // Reset directives, reload main file, emit using *this* path as .app stem
        // (not LAST-INCLUDED, which can be a nested INCLUDE). Output folder is
        // beside the source: <dir>/<STEM>/.
        forth.send(.executeCommand(command:
            "EMIT-FLAGS-RESET ANEW \(marker) S\" \(escaped)\" INCLUDED S\" \(escaped)\" EMIT-AUTO-FILE"
        ))
    }

    /// `ANEW` marker for editor-driven INCLUDE: `hello.fth` → `HELLO_MODULE`.
    static func moduleMarkerName(for url: URL) -> String {
        let stem = url.deletingPathExtension().lastPathComponent
        var out = ""
        out.reserveCapacity(stem.count + 8)
        var lastWasUnderscore = false
        for ch in stem.uppercased() {
            let ok = ch.isLetter || ch.isNumber
            if ok {
                out.append(ch)
                lastWasUnderscore = false
            } else if !lastWasUnderscore {
                out.append("_")
                lastWasUnderscore = true
            }
        }
        while out.hasPrefix("_") { out.removeFirst() }
        while out.hasSuffix("_") { out.removeLast() }
        if out.isEmpty { out = "UNTITLED" }
        return out + "_MODULE"
    }

    private static func includeFile(at url: URL, forth: ForthConnectionManager, autoAnew: Bool) {
        if refuseLoadIfNeeded(url) { return }
        let path = url.standardizedFileURL.path
        let escaped = path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let included = "S\" \(escaped)\" INCLUDED"
        let source = (try? String(contentsOf: url, encoding: .utf8))
            ?? (try? String(contentsOf: url, encoding: .isoLatin1))
        forth.noteIncludedDefinition(source.flatMap { ForthColonScan.lastName(in: $0) })
        if autoAnew {
            let marker = moduleMarkerName(for: url)
            // Clear EMIT-NO-* so a prior file's directives do not stick.
            forth.send(.executeCommand(command: "EMIT-FLAGS-RESET ANEW \(marker) \(included)"))
        } else {
            forth.send(.executeCommand(command: included))
        }
    }

    static func presentChdir(forth: ForthConnectionManager) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = forth.panelStartURL
        panel.prompt = "Choose"
        panel.message = "CHDIR — set Forth working directory"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let path = url.path
        // Quoted path — CHDIR uses _next_filespec (spaces OK).
        let escaped = path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        // Optimistic cache so the next Open/FLOAD panel starts here before cwdChanged arrives.
        forth.rememberWorkingDirectory(path)
        forth.send(.executeCommand(command: "CHDIR \"\(escaped)\""))
    }

    static func presentEdit(workspace: WorkspaceModel, forth: ForthConnectionManager) {
        workspace.openPanel(startDirectory: forth.panelStartURL)
    }

    /// Forth → Update User Data: fill missing Library/System/Docs from companion ship.
    static func updateUserData(forth: ForthConnectionManager) {
        guard forth.isConnected else {
            forth.noteUserError("Start Forth before updating Documents/EditForth")
            return
        }
        forth.send(.updateUserTree)
    }

    /// Forth → Restore Shipped Files: confirm in EditForth, then companion replace.
    static func restoreShippedFiles(forth: ForthConnectionManager) {
        guard forth.isConnected else {
            forth.noteUserError("Start Forth before restoring Documents/EditForth")
            return
        }
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Restore shipped EditForth files?"
        alert.informativeText =
            "This replaces Library, System, and Docs in Documents/EditForth. " +
            "Any changes you made in that folder will be lost unless you rename it first."
        alert.addButton(withTitle: "Rename EditForth")
        alert.addButton(withTitle: "Replace EditForth")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            forth.send(.restoreUserTree(renameFirst: true))
        case .alertSecondButtonReturn:
            let sure = NSAlert()
            sure.alertStyle = .critical
            sure.messageText = "Are you sure?"
            sure.informativeText =
                "Documents/EditForth will be overwritten. Your edits in that folder will be deleted."
            sure.addButton(withTitle: "Yes")
            sure.addButton(withTitle: "Cancel")
            guard sure.runModal() == .alertFirstButtonReturn else { return }
            forth.send(.restoreUserTree(renameFirst: false))
        default:
            break
        }
    }
}
