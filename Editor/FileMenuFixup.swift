//
//  FileMenuFixup.swift
//  64Edit
//
//  Created by Tom's MacBook Air on 9/29/26.
//

import AppKit

enum FileMenuFixup {
    /// DocumentGroup used to leave Duplicate on ⌘⇧S. Workspace commands own Save As now;
    /// clear any leftover Duplicate shortcut if AppKit still inserts one.
    static func install() {
        guard let file = NSApp.mainMenu?.item(withTitle: "File")?.submenu else { return }
        if let dup = file.item(withTitle: "Duplicate") {
            dup.keyEquivalent = ""
            dup.keyEquivalentModifierMask = []
        }
    }
}
