//
//  ForthColonScan.swift
//  EditForth
//
//  Last named colon definition in a source file, for RUN after INCLUDE.
//

import Foundation

enum ForthColonScan {
    /// Last `: NAME` in `source`. Skips line comments, `( … )` comments,
    /// and `."` / `S"` / `C"` / `ABORT"` / `S\"` strings. `:NONAME` is not a name.
    static func lastName(in source: String) -> String? {
        var last: String?
        var index = source.startIndex
        var lineComment = false
        var paren = 0

        func bump(_ i: inout String.Index) {
            i = source.index(after: i)
        }

        while index < source.endIndex {
            let ch = source[index]
            if ch == "\n" || ch == "\r" {
                lineComment = false
                bump(&index)
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
                skipParenString(source, from: &index)
                continue
            }
            if token == ".\"" || token == "S\"" || token == "C\"" || token == "ABORT\"" {
                skipQuote(source, from: &index, escaped: false)
                continue
            }
            if token == "S\\\"" {
                skipQuote(source, from: &index, escaped: true)
                continue
            }
            if token == ":" {
                guard let name = nextToken(source, from: &index, lineComment: &lineComment, paren: &paren) else {
                    continue
                }
                if name.caseInsensitiveCompare("NONAME") != .orderedSame {
                    last = name
                }
            }
        }
        return last
    }

    private static func nextToken(
        _ source: String,
        from index: inout String.Index,
        lineComment: inout Bool,
        paren: inout Int
    ) -> String? {
        while index < source.endIndex {
            let ch = source[index]
            if ch == "\n" || ch == "\r" {
                lineComment = false
                index = source.index(after: index)
                continue
            }
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

    private static func skipQuote(_ source: String, from index: inout String.Index, escaped: Bool) {
        while index < source.endIndex {
            let ch = source[index]
            index = source.index(after: index)
            if escaped, ch == "\\" {
                if index < source.endIndex { index = source.index(after: index) }
                continue
            }
            if ch == "\"" { return }
            if ch == "\n" || ch == "\r" { return }
        }
    }

    private static func skipParenString(_ source: String, from index: inout String.Index) {
        while index < source.endIndex {
            let ch = source[index]
            index = source.index(after: index)
            if ch == ")" || ch == "\n" || ch == "\r" { return }
        }
    }
}
