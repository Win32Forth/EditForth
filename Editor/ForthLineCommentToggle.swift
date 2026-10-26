//
//  ForthLineCommentToggle.swift
//  64Edit
//
//  Add or remove a leading "\ " on every line that intersects a selection.
//

import Foundation

enum ForthLineCommentToggle {
    static let prefix = "\\ "

    struct Edit: Equatable {
        var range: NSRange
        var replacement: String
        var newSelection: NSRange
    }

    /// Whole lines touched by `selection`. A caret toggles the line it sits on.
    /// A selection that ends on the first character of the next line does not include that line.
    static func edit(in text: String, selection: NSRange) -> Edit {
        let ns = text as NSString
        let safeLoc = min(max(0, selection.location), ns.length)
        let safeLen = min(max(0, selection.length), ns.length - safeLoc)
        let sel = NSRange(location: safeLoc, length: safeLen)
        let block = lineBlock(in: ns, selection: sel)
        let chunk = block.length == 0 ? "" : ns.substring(with: block)
        let parts = split(chunk)
        let uncomment = shouldUncomment(parts.lines)
        let rewritten = parts.lines.map { line -> String in
            if uncomment {
                return line.hasPrefix(prefix) ? String(line.dropFirst(prefix.count)) : line
            }
            return prefix + line
        }
        var replacement = rewritten.joined(separator: parts.newline)
        if parts.trailingNewline {
            replacement += parts.newline
        }
        let newLen = (replacement as NSString).length
        return Edit(
            range: block,
            replacement: replacement,
            newSelection: NSRange(location: block.location, length: newLen)
        )
    }

    private static func shouldUncomment(_ lines: [String]) -> Bool {
        let nonempty = lines.filter { !$0.isEmpty }
        return !nonempty.isEmpty && nonempty.allSatisfy { $0.hasPrefix(prefix) }
    }

    private static func lineBlock(in ns: NSString, selection: NSRange) -> NSRange {
        if ns.length == 0 {
            return NSRange(location: 0, length: 0)
        }
        let startLoc = min(selection.location, ns.length)
        let start = ns.paragraphRange(for: NSRange(location: min(startLoc, ns.length - 1), length: 0))
        if selection.length == 0 {
            if startLoc == ns.length, startLoc > 0 {
                let before = ns.character(at: startLoc - 1)
                if before == 10 || before == 13 {
                    return NSRange(location: startLoc, length: 0)
                }
            }
            if startLoc == ns.length {
                return start
            }
            return ns.paragraphRange(for: NSRange(location: startLoc, length: 0))
        }
        let lastChar = selection.location + selection.length - 1
        let end = ns.paragraphRange(for: NSRange(location: lastChar, length: 0))
        let loc = start.location
        return NSRange(location: loc, length: NSMaxRange(end) - loc)
    }

    private struct Parts {
        var lines: [String]
        var newline: String
        var trailingNewline: Bool
    }

    private static func split(_ chunk: String) -> Parts {
        if chunk.isEmpty {
            return Parts(lines: [""], newline: "\n", trailingNewline: false)
        }
        let newline: String
        if chunk.contains("\r\n") {
            newline = "\r\n"
        } else if chunk.contains("\r") {
            newline = "\r"
        } else {
            newline = "\n"
        }
        var lines = chunk.components(separatedBy: newline)
        var trailing = false
        if lines.last == "" {
            lines.removeLast()
            trailing = true
        }
        if lines.isEmpty {
            lines = [""]
        }
        return Parts(lines: lines, newline: newline, trailingNewline: trailing)
    }
}
