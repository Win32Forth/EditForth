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

    /// Documents/64Forth tree (same layout FileHost uses for user data).
    static var userTreeURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("64Forth", isDirectory: true)
    }

    static var configURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("64Forth/Config", isDirectory: true)
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

    static func presentFload(forth: ForthConnectionManager) {
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
        panel.directoryURL = userTreeURL.appendingPathComponent("Library", isDirectory: true)
        panel.prompt = "Load"
        panel.message = "FLOAD / INCLUDE a Forth source file"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let path = url.path
        let escaped = path.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        forth.send(.executeCommand(command: "S\" \(escaped)\" INCLUDED"))
    }

    static func presentChdir(forth: ForthConnectionManager) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = userTreeURL
        panel.prompt = "Choose"
        panel.message = "CHDIR — set Forth working directory"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let path = url.path
        // CHDIR parses a name from the input stream (same as INCLUDE path form).
        forth.send(.executeCommand(command: "CHDIR \(path)"))
    }

    static func presentEdit(workspace: WorkspaceModel) {
        workspace.openPanel()
    }
}
