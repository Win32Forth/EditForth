//
//  SixtyFourForthLocator.swift
//  EditForth
//
//  The Forth engine lives in this app. Ping, Ask Forth --agent, and Library
//  lookup use the running EditForth.app, not a second 64Forth.app.
//

import Foundation

enum SixtyFourForthLocator {
    /// This process's app bundle (EditForth.app). Library, System (including
    /// AutoLoad), Docs, and Config are copied into that bundle at build time.
    nonisolated static func locateApp() -> URL? {
        let url = Bundle.main.bundleURL
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir),
              isDir.boolValue else {
            return nil
        }
        return url
    }

    /// This process's executable. Launch it again with `--companion` or `--agent`.
    nonisolated static func locateBinary() -> URL? {
        guard let exe = Bundle.main.executableURL else { return nil }
        guard FileManager.default.isExecutableFile(atPath: exe.path) else { return nil }
        return exe
    }
}
