//
//  SixtyFourForthLocator.swift
//  EditForth
//
//  Shared lookup for this project’s companion 64Forth.app (Debug/Release).
//  Used by Ping launch and by Ask Forth’s --agent runner.
//

import Foundation

enum SixtyFourForthLocator {
    /// Companion `64Forth.app` matching this editor’s build flavor.
    /// Prefers the **EditForth** project’s 64Forth target (same Products / EditForth DerivedData),
    /// not the standalone Win32Forth/64Forth tree.
    /// **Debug:** sibling Products, then newest `EditForth-*` DerivedData Debug,
    /// then project-local `DerivedData/*/Build/Products/Debug/64Forth.app`.
    /// **Release:** sibling, then `/Applications/64Forth.app` (never Debug DerivedData).
    /// File-system only — `nonisolated` so headless `--agent` can call from off the main actor.
    nonisolated static func locateApp() -> URL? {
        let fm = FileManager.default

        func existsApp(_ url: URL) -> URL? {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
                return nil
            }
            return url
        }

        let sibling = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("64Forth.app", isDirectory: true)
        let applications = URL(fileURLWithPath: "/Applications/64Forth.app", isDirectory: true)

        func newestApp(inRoots roots: [URL], config: String) -> URL? {
            var candidates: [(url: URL, date: Date)] = []
            for root in roots {
                guard let dirs = try? fm.contentsOfDirectory(
                    at: root,
                    includingPropertiesForKeys: [.contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                ) else { continue }
                for dir in dirs {
                    let name = dir.lastPathComponent
                    guard name.hasPrefix("EditForth") else { continue }
                    let app = dir
                        .appendingPathComponent("Build/Products/\(config)/64Forth.app", isDirectory: true)
                    guard let url = existsApp(app) else { continue }
                    let vals = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                    candidates.append((url, vals?.contentModificationDate ?? .distantPast))
                }
            }
            return candidates.sorted(by: { $0.date > $1.date }).first?.url
        }

        func libraryDerivedDataCandidate(config: String) -> URL? {
            let home = fm.homeDirectoryForCurrentUser
            let dd = home.appendingPathComponent("Library/Developer/Xcode/DerivedData", isDirectory: true)
            return newestApp(inRoots: [dd], config: config)
        }

        func projectLocalDerivedDataCandidate(config: String) -> URL? {
            var dir = Bundle.main.bundleURL
            for _ in 0..<12 {
                dir = dir.deletingLastPathComponent()
                let dd = dir.appendingPathComponent("DerivedData", isDirectory: true)
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: dd.path, isDirectory: &isDir), isDir.boolValue else {
                    continue
                }
                if let hit = newestApp(inRoots: [dd], config: config) {
                    return hit
                }
            }
            return nil
        }

        #if DEBUG
        if let s = existsApp(sibling) { return s }
        if let dd = libraryDerivedDataCandidate(config: "Debug") { return dd }
        if let local = projectLocalDerivedDataCandidate(config: "Debug") { return local }
        #else
        if let s = existsApp(sibling) { return s }
        if let a = existsApp(applications) { return a }
        #endif
        return nil
    }

    /// `Contents/MacOS/64Forth` inside the located app, if executable.
    nonisolated static func locateBinary() -> URL? {
        guard let app = locateApp() else { return nil }
        let exe = app.appendingPathComponent("Contents/MacOS/64Forth")
        guard FileManager.default.isExecutableFile(atPath: exe.path) else { return nil }
        return exe
    }
}
