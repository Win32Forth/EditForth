//
//  TextMatch.swift
//  EditForth
//
//  Shared literal Find / Whole Word matching for Find & Replace and
//  Search in Folders. Whole-word characters match Forth-ish names
//  (CLOCK-BOX, @, $, etc.).
//

import Foundation
import AppKit

enum TextMatch {
    /// Forth-ish name characters so Whole Word treats CLOCK-BOX as one word.
    static let wordChars = CharacterSet.alphanumerics.union(
        CharacterSet(charactersIn: "_-?!'.+*/<>=@$")
    )

    static func isWordChar(_ ch: Character) -> Bool {
        ch.unicodeScalars.allSatisfy { wordChars.contains($0) }
    }

    /// True when UTF-16 `range` in `ns` is a whole-word hit.
    static func isWholeWordMatch(in ns: NSString, range: NSRange) -> Bool {
        if range.location > 0 {
            let before = ns.character(at: range.location - 1)
            if let scalar = UnicodeScalar(before), wordChars.contains(scalar) {
                return false
            }
        }
        let end = NSMaxRange(range)
        if end < ns.length {
            let after = ns.character(at: end)
            if let scalar = UnicodeScalar(after), wordChars.contains(scalar) {
                return false
            }
        }
        return true
    }

    /// True when `range` in Swift `line` is a whole-word hit.
    static func isWholeWordMatch(in line: String, range: Range<String.Index>) -> Bool {
        if range.lowerBound > line.startIndex {
            let before = line[line.index(before: range.lowerBound)]
            if isWordChar(before) { return false }
        }
        if range.upperBound < line.endIndex {
            let after = line[range.upperBound]
            if isWordChar(after) { return false }
        }
        return true
    }

    static func compareOptions(matchCase: Bool) -> NSString.CompareOptions {
        matchCase ? [] : [.caseInsensitive]
    }

    /// Next match at or after `from`, optionally wrapping once from the start.
    static func findNext(
        in ns: NSString,
        needle: String,
        matchCase: Bool,
        wholeWord: Bool,
        from: Int,
        wrap: Bool
    ) -> NSRange? {
        guard !needle.isEmpty, ns.length > 0 else { return nil }
        let opts = compareOptions(matchCase: matchCase)
        let start = max(0, min(from, ns.length))
        if let hit = scanForward(ns: ns, needle: needle, options: opts, wholeWord: wholeWord,
                                 searchRange: NSRange(location: start, length: ns.length - start)) {
            return hit
        }
        guard wrap, start > 0 else { return nil }
        return scanForward(ns: ns, needle: needle, options: opts, wholeWord: wholeWord,
                           searchRange: NSRange(location: 0, length: start))
    }

    /// Previous match ending at or before `from`, optionally wrapping once from the end.
    static func findPrevious(
        in ns: NSString,
        needle: String,
        matchCase: Bool,
        wholeWord: Bool,
        from: Int,
        wrap: Bool
    ) -> NSRange? {
        guard !needle.isEmpty, ns.length > 0 else { return nil }
        let opts = compareOptions(matchCase: matchCase).union(.backwards)
        let end = max(0, min(from, ns.length))
        if let hit = scanBackward(ns: ns, needle: needle, options: opts, wholeWord: wholeWord,
                                  searchRange: NSRange(location: 0, length: end)) {
            return hit
        }
        guard wrap, end < ns.length else { return nil }
        return scanBackward(ns: ns, needle: needle, options: opts, wholeWord: wholeWord,
                            searchRange: NSRange(location: end, length: ns.length - end))
    }

    /// Every match range in document order (UTF-16).
    static func allMatchRanges(
        in ns: NSString,
        needle: String,
        matchCase: Bool,
        wholeWord: Bool
    ) -> [NSRange] {
        guard !needle.isEmpty, ns.length > 0 else { return [] }
        let opts = compareOptions(matchCase: matchCase)
        var ranges: [NSRange] = []
        var searchFrom = 0
        while searchFrom <= ns.length {
            let remaining = NSRange(location: searchFrom, length: ns.length - searchFrom)
            guard let hit = scanForward(ns: ns, needle: needle, options: opts, wholeWord: wholeWord,
                                        searchRange: remaining) else { break }
            ranges.append(hit)
            searchFrom = NSMaxRange(hit)
            if hit.length == 0 { searchFrom += 1 }
        }
        return ranges
    }

    /// 1-based index of `range` among `matches`, or nil if it is not a listed match.
    static func matchIndex(of range: NSRange, in matches: [NSRange]) -> Int? {
        for (i, m) in matches.enumerated() {
            if NSEqualRanges(m, range) { return i + 1 }
        }
        return nil
    }

    /// Replace every match. Returns the number of replacements.
    static func replaceAll(
        in tv: NSTextView,
        needle: String,
        replacement: String,
        matchCase: Bool,
        wholeWord: Bool
    ) -> Int {
        guard !needle.isEmpty, tv.isEditable else { return 0 }
        let ns = tv.string as NSString
        let opts = compareOptions(matchCase: matchCase)
        var ranges: [NSRange] = []
        var searchFrom = 0
        while searchFrom <= ns.length {
            let remaining = NSRange(location: searchFrom, length: ns.length - searchFrom)
            guard let hit = scanForward(ns: ns, needle: needle, options: opts, wholeWord: wholeWord,
                                        searchRange: remaining) else { break }
            ranges.append(hit)
            searchFrom = NSMaxRange(hit)
            if hit.length == 0 { searchFrom += 1 }
        }
        guard !ranges.isEmpty else { return 0 }
        // Replace from the end so earlier ranges stay valid.
        var count = 0
        tv.undoManager?.beginUndoGrouping()
        for range in ranges.reversed() {
            if tv.shouldChangeText(in: range, replacementString: replacement) {
                tv.replaceCharacters(in: range, with: replacement)
                tv.didChangeText()
                count += 1
            }
        }
        tv.undoManager?.endUndoGrouping()
        return count
    }

    private static func scanForward(
        ns: NSString,
        needle: String,
        options: NSString.CompareOptions,
        wholeWord: Bool,
        searchRange: NSRange
    ) -> NSRange? {
        var range = searchRange
        while range.length > 0 {
            let found = ns.range(of: needle, options: options, range: range)
            guard found.location != NSNotFound else { return nil }
            if !wholeWord || isWholeWordMatch(in: ns, range: found) {
                return found
            }
            let next = NSMaxRange(found)
            if next >= NSMaxRange(searchRange) { return nil }
            range = NSRange(location: next, length: NSMaxRange(searchRange) - next)
        }
        return nil
    }

    private static func scanBackward(
        ns: NSString,
        needle: String,
        options: NSString.CompareOptions,
        wholeWord: Bool,
        searchRange: NSRange
    ) -> NSRange? {
        var range = searchRange
        while range.length > 0 {
            let found = ns.range(of: needle, options: options, range: range)
            guard found.location != NSNotFound else { return nil }
            if !wholeWord || isWholeWordMatch(in: ns, range: found) {
                return found
            }
            // Move the end just before this rejected hit.
            if found.location == 0 { return nil }
            range = NSRange(location: range.location, length: found.location - range.location)
        }
        return nil
    }
}
