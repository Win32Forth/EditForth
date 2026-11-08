//
//  ForthColonScan.swift
//  EditForth
//
//  Last named colon definition in a source file, for RUN after INCLUDE.
//

import Foundation

enum ForthColonScan {
    /// One `: NAME`. `line` is the 1-based line of the colon.
    struct Header {
        var name: String
        var line: Int
    }

    /// Last `: NAME` in `source`. Skips line comments, `( … )` comments,
    /// and `."` / `S"` / `C"` / `ABORT"` / `S\"` strings. `:NONAME` is not a name.
    static func lastName(in source: String) -> String? {
        headers(in: source).last?.name
    }

    /// `: NAME` whose colon is on `line`, or the latest colon above it.
    /// Lines before the first colon have no definition.
    static func definitionName(containingLine line: Int, in source: String) -> String? {
        var found: String?
        for header in headers(in: source) {
            if header.line <= line {
                found = header.name
            } else {
                break
            }
        }
        return found
    }

    /// Whitespace-separated tokens on a 1-based line, stopping at `\`.
    static func tokens(onLine line: Int, in source: String) -> [String] {
        let text = lineText(line, in: source)
        var tokens: [String] = []
        var index = text.startIndex
        while index < text.endIndex {
            let ch = text[index]
            if ch == " " || ch == "\t" {
                index = text.index(after: index)
                continue
            }
            let start = index
            while index < text.endIndex {
                let c = text[index]
                if c == " " || c == "\t" { break }
                index = text.index(after: index)
            }
            let token = String(text[start..<index])
            if token == "\\" { break }
            tokens.append(token)
        }
        return tokens
    }

    /// `: NAME` headers in order. Skips the same comments and strings as `lastName`.
    static func headers(in source: String) -> [Header] {
        var found: [Header] = []
        var index = source.startIndex
        var line = 1
        var lineComment = false
        var paren = 0

        func bump(_ i: inout String.Index) {
            i = source.index(after: i)
        }

        while index < source.endIndex {
            let ch = source[index]
            if consumeLineBreak(source, index: &index, line: &line) {
                lineComment = false
                continue
            }
            if lineComment || ch == " " || ch == "\t" {
                bump(&index)
                continue
            }

            let tokenStart = index
            while index < source.endIndex {
                let c = source[index]
                if c == " " || c == "\t" || c == "\n" || c == "\r" { break }
                bump(&index)
            }
            let token = String(source[tokenStart..<index])

            if paren > 0 {
                paren += token.filter { $0 == "(" }.count
                paren -= token.filter { $0 == ")" }.count
                if paren < 0 { paren = 0 }
                continue
            }
            if token == "\\" {
                lineComment = true
                continue
            }
            if token == "(" {
                paren = 1
                continue
            }
            if token == ".(" {
                skipParenString(source, from: &index, line: &line)
                continue
            }
            if token == ".\"" || token == "S\"" || token == "C\"" || token == "ABORT\"" {
                skipQuote(source, from: &index, line: &line, escaped: false)
                continue
            }
            if token == "S\\\"" {
                skipQuote(source, from: &index, line: &line, escaped: true)
                continue
            }
            if token == ":" {
                let colonLine = line
                guard let name = nextToken(
                    source,
                    from: &index,
                    line: &line,
                    lineComment: &lineComment,
                    paren: &paren
                ) else {
                    continue
                }
                if name.caseInsensitiveCompare("NONAME") != .orderedSame {
                    found.append(Header(name: name, line: colonLine))
                }
            }
        }
        return found
    }

    private static func nextToken(
        _ source: String,
        from index: inout String.Index,
        line: inout Int,
        lineComment: inout Bool,
        paren: inout Int
    ) -> String? {
        while index < source.endIndex {
            if consumeLineBreak(source, index: &index, line: &line) {
                lineComment = false
                continue
            }
            let ch = source[index]
            if lineComment || ch == " " || ch == "\t" {
                index = source.index(after: index)
                continue
            }
            let start = index
            while index < source.endIndex {
                let c = source[index]
                if c == " " || c == "\t" || c == "\n" || c == "\r" { break }
                index = source.index(after: index)
            }
            let token = String(source[start..<index])
            if paren > 0 {
                paren += token.filter { $0 == "(" }.count
                paren -= token.filter { $0 == ")" }.count
                if paren < 0 { paren = 0 }
                continue
            }
            if token == "\\" {
                lineComment = true
                continue
            }
            if token == "(" {
                paren = 1
                continue
            }
            return token
        }
        return nil
    }

    private static func skipQuote(
        _ source: String,
        from index: inout String.Index,
        line: inout Int,
        escaped: Bool
    ) {
        while index < source.endIndex {
            if consumeLineBreak(source, index: &index, line: &line) { return }
            let ch = source[index]
            index = source.index(after: index)
            if escaped, ch == "\\" {
                if index < source.endIndex { index = source.index(after: index) }
                continue
            }
            if ch == "\"" { return }
        }
    }

    private static func skipParenString(
        _ source: String,
        from index: inout String.Index,
        line: inout Int
    ) {
        while index < source.endIndex {
            if consumeLineBreak(source, index: &index, line: &line) { return }
            let ch = source[index]
            index = source.index(after: index)
            if ch == ")" { return }
        }
    }

    /// `\n` or `\r\n` or `\r` counts as one line. Returns true when one was consumed.
    private static func consumeLineBreak(
        _ source: String,
        index: inout String.Index,
        line: inout Int
    ) -> Bool {
        guard index < source.endIndex else { return false }
        let ch = source[index]
        if ch == "\n" {
            index = source.index(after: index)
            line += 1
            return true
        }
        if ch == "\r" {
            index = source.index(after: index)
            if index < source.endIndex, source[index] == "\n" {
                index = source.index(after: index)
            }
            line += 1
            return true
        }
        return false
    }

    private static func lineText(_ line: Int, in source: String) -> String {
        guard line >= 1 else { return "" }
        var current = 1
        var index = source.startIndex
        var start = index
        while index < source.endIndex && current < line {
            if consumeLineBreak(source, index: &index, line: &current) {
                start = index
            } else {
                index = source.index(after: index)
            }
        }
        guard current == line else { return "" }
        var end = start
        while end < source.endIndex {
            let ch = source[end]
            if ch == "\n" || ch == "\r" { break }
            end = source.index(after: end)
        }
        return String(source[start..<end])
    }
}
