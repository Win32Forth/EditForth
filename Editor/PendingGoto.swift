//
//  PendingGoto.swift
//  64Edit
//
//  64Forth writes pending-goto.json (and a distributed notification) before
//  opening a file via VIEW / EDIT / EDIT-AT. Consume it to scroll and set mode.
//

import Foundation
import AppKit

enum PendingGoto {
    static let notificationName = Notification.Name("com.Win32Forth.64Edit.goto")

    struct Request: Equatable {
        var path: String
        /// 1-based line to reveal; 0 means open only (no scroll).
        var line: Int
        /// VIEW → true (read-only until user switches); EDIT → false.
        var viewMode: Bool
    }

    static var fileURL: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return root
            .appendingPathComponent("64Forth", isDirectory: true)
            .appendingPathComponent("pending-goto.json")
    }

    /// JSONSerialization boxes numbers as NSNumber; `as? Int` can fail.
    private static func intValue(_ any: Any?) -> Int? {
        if let i = any as? Int { return i }
        if let n = any as? NSNumber { return n.intValue }
        if let d = any as? Double { return Int(d) }
        return nil
    }

    private static func doubleValue(_ any: Any?) -> Double? {
        if let d = any as? Double { return d }
        if let n = any as? NSNumber { return n.doubleValue }
        if let i = any as? Int { return Double(i) }
        return nil
    }

    /// Peek without removing. Returns nil if missing, stale (>60s), or invalid.
    static func peek() -> Request? {
        let url = fileURL
        guard let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let path = obj["path"] as? String,
              !path.isEmpty
        else { return nil }
        let line = intValue(obj["line"]) ?? 0
        let mode = (obj["mode"] as? String)?.lowercased()
        // Legacy pending files had no mode: line > 0 meant VIEW.
        let viewMode: Bool
        if mode == "view" {
            viewMode = true
        } else if mode == "edit" {
            viewMode = false
        } else {
            guard line > 0 else { return nil }
            viewMode = true
        }
        let created = doubleValue(obj["created"]) ?? 0
        if created > 0, Date().timeIntervalSince1970 - created > 60 {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        return Request(path: path, line: line, viewMode: viewMode)
    }

    static func consume() -> Request? {
        guard let pending = peek() else { return nil }
        try? FileManager.default.removeItem(at: fileURL)
        return pending
    }

    /// Consume only when `documentPath` matches the pending path (string or same inode).
    static func consumeIfMatches(documentPath: String?) -> Request? {
        guard let documentPath,
              let pending = peek(),
              pathsMatch(documentPath, pending.path)
        else { return nil }
        try? FileManager.default.removeItem(at: fileURL)
        return pending
    }

    /// Consume when any candidate path matches the pending file.
    static func consumeIfMatches(candidates: [String]) -> Request? {
        guard let pending = peek(), !candidates.isEmpty else { return nil }
        guard candidates.contains(where: { pathsMatch($0, pending.path) }) else { return nil }
        try? FileManager.default.removeItem(at: fileURL)
        return pending
    }

    /// Paths for this document window only (never other open docs — avoids wrong-window goto).
    static func candidatePaths(explicit: URL?, window: NSWindow? = nil) -> [String] {
        var out: [String] = []
        func add(_ s: String?) {
            guard let s, !s.isEmpty else { return }
            if !out.contains(where: { pathsMatch($0, s) }) { out.append(s) }
        }
        add(explicit?.path)
        add(window?.representedURL?.path)
        // When DocumentGroup has not yet passed fileURL, the key window may already know it.
        if explicit == nil, let key = NSApp.keyWindow {
            add(key.representedURL?.path)
        }
        return out
    }

    static func pathsMatch(_ a: String, _ b: String) -> Bool {
        let ua = URL(fileURLWithPath: a).standardizedFileURL
        let ub = URL(fileURLWithPath: b).standardizedFileURL
        if ua.path.caseInsensitiveCompare(ub.path) == .orderedSame {
            return true
        }
        // Library copies are often hard-linked; DocumentGroup may report the other path.
        guard let aId = try? ua.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier,
              let bId = try? ub.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier
        else {
            return false
        }
        return aId.isEqual(bId)
    }

    /// Select and scroll `tv` so 1-based `line` is visible. Returns false if text is empty.
    @discardableResult
    static func scroll(_ tv: NSTextView, toLine line: Int) -> Bool {
        guard line > 0 else { return false }
        let ns = tv.string as NSString
        guard ns.length > 0 else { return false }
        var current = 1
        var idx = 0
        while current < line && idx < ns.length {
            let para = ns.paragraphRange(for: NSRange(location: idx, length: 0))
            let next = NSMaxRange(para)
            if next <= idx { break }
            idx = next
            current += 1
        }
        let loc = min(idx, max(0, ns.length - 1))
        let range = ns.paragraphRange(for: NSRange(location: loc, length: 0))
        tv.setSelectedRange(range)
        tv.scrollRangeToVisible(range)
        if let layout = tv.layoutManager, let container = tv.textContainer {
            layout.ensureLayout(for: container)
            let glyph = layout.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            let rect = layout.boundingRect(forGlyphRange: glyph, in: container)
            let visible = rect.insetBy(dx: 0, dy: -tv.bounds.height / 3)
            tv.scrollToVisible(visible)
        }
        tv.window?.makeFirstResponder(tv)
        return true
    }

    /// 1-based line of the caret (or 1 if empty).
    static func lineNumber(atCaretIn tv: NSTextView) -> Int? {
        let ns = tv.string as NSString
        guard ns.length > 0 else { return 1 }
        let loc = min(tv.selectedRange().location, max(0, ns.length - 1))
        var line = 1
        var idx = 0
        while idx < loc {
            let para = ns.paragraphRange(for: NSRange(location: idx, length: 0))
            let next = NSMaxRange(para)
            if next <= idx { break }
            if next > loc { break }
            idx = next
            line += 1
        }
        return line
    }

    /// UTF-16 index of the start of 1-based `line`, or `ns.length` if past end.
    static func startIndex(ofLine line: Int, in ns: NSString) -> Int {
        guard line > 1, ns.length > 0 else { return 0 }
        var current = 1
        var idx = 0
        while current < line && idx < ns.length {
            let para = ns.paragraphRange(for: NSRange(location: idx, length: 0))
            let next = NSMaxRange(para)
            if next <= idx { break }
            idx = next
            current += 1
        }
        return idx
    }

    /// Whole-word match of `name` inside the colon definition that starts at
    /// `nearLine` (VIEW line). Does not search the rest of the file.
    ///
    /// Runtime peeks that never appear in source (EXIT, (S"), 0BRANCH, …) are
    /// remapped to source spellings — same idea as `Debugger/dbg-map.fth`.
    static func findWholeWord(_ name: String, in text: String, nearLine: Int) -> NSRange? {
        let needle = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return nil }
        let ns = text as NSString
        guard ns.length > 0 else { return nil }
        let window = definitionSearchRange(nearLine: nearLine, in: ns)
        guard window.length > 0 else { return nil }
        let from = window.location
        let to = NSMaxRange(window)
        for (cand, opts) in highlightNeedles(for: needle) {
            if let hit = firstWholeWord(cand, in: ns, from: from, to: to, options: opts) {
                return hit
            }
        }
        return nil
    }

    /// Search needles for a peek token. Runtime names map to source spellings
    /// (dbg-map / SEE order). First match inside the definition window wins.
    private static func highlightNeedles(
        for name: String
    ) -> [(String, NSString.CompareOptions)] {
        let ci: NSString.CompareOptions = [.caseInsensitive, .literal]
        let lit: NSString.CompareOptions = [.literal]
        func pair(_ s: String, _ o: NSString.CompareOptions = ci) -> (String, NSString.CompareOptions) {
            (s, o)
        }
        switch name.uppercased() {
        case "EXIT":
            // Compiled from `;`; prefer semicolon then explicit EXIT.
            return [pair(";", lit), pair("EXIT")]
        case "(S\")":
            // Runtime for S" and ." (SLIT).
            return [pair("S\"", lit), pair(".\"", lit)]
        case "(C\")":
            return [pair("C\"", lit)]
        case "0BRANCH":
            return [pair("IF"), pair("WHILE"), pair("UNTIL")]
        case "BRANCH":
            return [pair("ELSE"), pair("AGAIN"), pair("REPEAT")]
        case "(DO)":
            return [pair("DO")]
        case "(?DO)":
            return [pair("?DO", lit)]
        case "(LOOP)":
            return [pair("LOOP")]
        case "(+LOOP)":
            return [pair("+LOOP", lit)]
        case "LIT":
            // Source has a number / [CHAR] / ['] — needs payload or maps.
            // Keep LIT last so an explicit LIT in comments still matches.
            return [pair("[']", lit), pair("[CHAR]"), pair("LIT")]
        default:
            return [pair(name)]
        }
    }

    /// Byte range of the colon definition at `nearLine`: from the line start
    /// through its closing `;`, or up to the next top-level `:` if none.
    private static func definitionSearchRange(nearLine: Int, in ns: NSString) -> NSRange {
        let from = startIndex(ofLine: max(nearLine, 1), in: ns)
        guard from < ns.length else {
            return NSRange(location: from, length: 0)
        }
        if let semi = firstWholeWord(";", in: ns, from: from, to: ns.length, options: [.literal]) {
            return NSRange(location: from, length: NSMaxRange(semi) - from)
        }
        let nextDef = nextDefinitionStart(after: from, in: ns) ?? ns.length
        return NSRange(location: from, length: max(0, nextDef - from))
    }

    /// Start index of the next line whose first non-blank character is `:`.
    private static func nextDefinitionStart(after from: Int, in ns: NSString) -> Int? {
        var idx = from
        // Skip the remainder of the line that contains `from`.
        while idx < ns.length {
            let ch = ns.character(at: idx)
            idx += 1
            if ch == 10 || ch == 13 { break }
        }
        while idx < ns.length {
            let lineStart = idx
            var j = idx
            while j < ns.length {
                let ch = ns.character(at: j)
                if ch == 32 || ch == 9 { j += 1; continue }
                break
            }
            if j < ns.length, ns.character(at: j) == 58 /* ':' */ {
                let after = j + 1
                if after >= ns.length || isWordBoundary(after: after, in: ns)
                    || ns.character(at: after) == 32 || ns.character(at: after) == 9 {
                    return lineStart
                }
            }
            while idx < ns.length {
                let ch = ns.character(at: idx)
                idx += 1
                if ch == 10 || ch == 13 { break }
            }
        }
        return nil
    }

    private static let forthSeparators = CharacterSet.whitespacesAndNewlines

    private static func isWordBoundary(before index: Int, in ns: NSString) -> Bool {
        if index <= 0 { return true }
        let scalars = ns.substring(with: NSRange(location: index - 1, length: 1)).unicodeScalars
        guard let s = scalars.first else { return true }
        return forthSeparators.contains(s)
    }

    private static func isWordBoundary(after end: Int, in ns: NSString) -> Bool {
        if end >= ns.length { return true }
        let scalars = ns.substring(with: NSRange(location: end, length: 1)).unicodeScalars
        guard let s = scalars.first else { return true }
        return forthSeparators.contains(s)
    }

    private static func firstWholeWord(
        _ needle: String,
        in ns: NSString,
        from: Int,
        to: Int,
        options: NSString.CompareOptions
    ) -> NSRange? {
        var searchStart = from
        let needleLen = (needle as NSString).length
        while searchStart < to {
            let hay = NSRange(location: searchStart, length: to - searchStart)
            let found = ns.range(of: needle, options: options, range: hay)
            guard found.location != NSNotFound else { return nil }
            let end = NSMaxRange(found)
            if isWordBoundary(before: found.location, in: ns),
               isWordBoundary(after: end, in: ns) {
                return found
            }
            searchStart = found.location + max(1, needleLen)
        }
        return nil
    }

    private static func lastWholeWord(
        _ needle: String,
        in ns: NSString,
        from: Int,
        to: Int,
        options: NSString.CompareOptions
    ) -> NSRange? {
        var last: NSRange?
        var searchStart = from
        let needleLen = (needle as NSString).length
        while searchStart < to {
            let hay = NSRange(location: searchStart, length: to - searchStart)
            let found = ns.range(of: needle, options: options, range: hay)
            guard found.location != NSNotFound, found.location < to else { break }
            let end = NSMaxRange(found)
            if end <= to,
               isWordBoundary(before: found.location, in: ns),
               isWordBoundary(after: end, in: ns) {
                last = found
            }
            searchStart = found.location + max(1, needleLen)
        }
        return last
    }
}
