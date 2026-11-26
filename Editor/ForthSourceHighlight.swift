//
//  ForthSourceHighlight.swift
//  EditForth
//
//  Classify a Forth buffer the way the Arduino-Forth analyzer paints a
//  listing: comments, numbers, defining words, and standard words.
//  Ranges are UTF-16 indexes, the same indexes NSTextView uses.
//

import Foundation

enum ForthSourceHighlight {
    enum Kind {
        case comment
        case string
        case number
        case definition
        case conditional
        case documented
        case plain
    }

    struct Run {
        var location: Int
        var length: Int
        var kind: Kind
        var tip: String?
    }

    /// Defining words the analyzer draws in red. They still keep a glossary tip.
    private static let definitionWords: Set<String> = [":", ";", ":NONAME", "EXIT"]

    /// Control-flow words. Painted apart from ordinary dictionary words.
    private static let conditionalWords: Set<String> = [
        "IF", "ELSE", "THEN",
        "BEGIN", "WHILE", "REPEAT", "UNTIL", "AGAIN",
        "CASE", "OF", "ENDOF", "ENDCASE",
        "DO", "?DO", "LOOP", "+LOOP", "LEAVE", "UNLOOP",
        "FOR", "NEXT",
    ]

    /// The following token is a new name, not a call.
    private static let nameFollowers: Set<String> = [
        ":", "VARIABLE", "2VARIABLE", "CONSTANT", "2CONSTANT", "VALUE", "2VALUE",
        "BUFFER:", "DEFER", "MARKER", "CREATE",
    ]

    static func paint(_ text: String) -> [Run] {
        let ns = text as NSString
        let count = ns.length
        var runs: [Run] = []
        var index = 0
        var defined: Set<String> = []
        var expectName = false
        var expectChar = false

        func isBreak(_ c: unichar) -> Bool {
            c == 32 || c == 9 || c == 10 || c == 13
        }

        func append(_ start: Int, _ end: Int, _ kind: Kind, _ tip: String?) {
            guard end > start else { return }
            runs.append(Run(location: start, length: end - start, kind: kind, tip: tip))
        }

        func appendWord(_ start: Int, _ end: Int, _ token: String) {
            let upper = token.uppercased()
            if definitionWords.contains(upper) {
                append(start, end, .definition, ForthGlossary.entry(for: token)?.tip)
            } else if conditionalWords.contains(upper) {
                append(start, end, .conditional, ForthGlossary.entry(for: token)?.tip)
            } else if let entry = ForthGlossary.entry(for: token) {
                append(start, end, .documented, entry.tip)
            } else {
                append(start, end, .plain, nil)
            }
        }

        func classifyWord(_ token: String, upper: String, start: Int, end: Int) -> Bool {
            if definitionWords.contains(upper) {
                append(start, end, .definition, ForthGlossary.entry(for: token)?.tip)
                return true
            }
            if conditionalWords.contains(upper) {
                append(start, end, .conditional, ForthGlossary.entry(for: token)?.tip)
                return true
            }
            if let entry = ForthGlossary.entry(for: token) {
                append(start, end, .documented, entry.tip)
                return true
            }
            return false
        }

        while index < count {
            let ch = ns.character(at: index)
            if isBreak(ch) {
                index += 1
                continue
            }
            let start = index
            while index < count, !isBreak(ns.character(at: index)) {
                index += 1
            }
            let token = ns.substring(with: NSRange(location: start, length: index - start))
            let upper = token.uppercased()

            if upper == "\\" {
                let lineEnd = endOfLine(ns, from: start, count: count)
                append(start, lineEnd, .comment, nil)
                index = lineEnd
                continue
            }
            if upper == "(" {
                let end = endOfParen(ns, from: index, count: count, depth: 1)
                append(start, end, .comment, nil)
                index = end
                continue
            }
            if upper == ".(" {
                let end = endOfDelimiter(ns, from: index, count: count, delimiter: 41, escaped: false)
                appendWord(start, index, token)
                if end > index { append(index, end, .string, nil) }
                index = end
                continue
            }
            if upper == ".\"" || upper == ",\"" || upper == "S\"" || upper == "C\"" || upper == "ABORT\"" || upper == "S\\\"" {
                let escaped = upper == "S\\\""
                let end = endOfDelimiter(ns, from: index, count: count, delimiter: 34, escaped: escaped)
                appendWord(start, index, token)
                if end > index { append(index, end, .string, nil) }
                index = end
                continue
            }

            if expectChar {
                expectChar = false
                append(start, index, .number, "character")
                continue
            }
            if expectName {
                expectName = false
                defined.insert(upper)
                append(start, index, .plain, "Defined in this file")
                continue
            }

            if classifyWord(token, upper: upper, start: start, end: index) {
                if nameFollowers.contains(upper) { expectName = true }
                if upper == "CHAR" || upper == "[CHAR]" { expectChar = true }
                continue
            }
            if let numberTip = numberTip(token) {
                append(start, index, .number, numberTip)
                continue
            }
            let localTip = defined.contains(upper) ? "Defined in this file" : nil
            append(start, index, .plain, localTip)
        }
        return runs
    }

    /// Empty when the sample listing classifies the way the analyzer does.
    static func selfCheck() -> [String] {
        var fails = ForthGlossary.selfCheck()
        let sample = ": cube ( n -- n )\n    dup dup * * ;\n42 cube .\n\\ comment\n.\" hi\"\n"
        let ns = sample as NSString
        let runs = paint(sample)
        func text(_ run: Run) -> String {
            ns.substring(with: NSRange(location: run.location, length: run.length))
        }
        func fail(_ message: String) { fails.append(message) }

        guard let colon = runs.first, text(colon) == ":", colon.kind == .definition else {
            fail("colon run missing")
            return fails
        }
        guard let comment = runs.first(where: { text($0).hasPrefix("(") }) else {
            fail("stack comment missing")
            return fails
        }
        if comment.kind != .comment || text(comment) != "( n -- n )" {
            fail("stack comment [\(text(comment))] \(comment.kind)")
        }
        let dups = runs.filter { text($0).caseInsensitiveCompare("dup") == .orderedSame }
        if dups.count != 2 || dups.contains(where: { $0.kind != .documented || !($0.tip ?? "").contains("x -- x x") }) {
            fail("dup runs \(dups.map { "\($0.kind)" })")
        }
        if runs.first(where: { text($0) == ";" })?.kind != .definition {
            fail("semicolon")
        }
        if paint("EXIT").first?.kind != .definition {
            fail("EXIT should match ;")
        }
        let commaString = paint(",\" hi\"")
        let commaText = ",\" hi\"" as NSString
        if commaString.first(where: { commaText.substring(with: NSRange(location: $0.location, length: $0.length)).contains("hi") })?.kind != .string {
            fail(",\" string")
        }
        let forNext = paint("FOR NEXT")
        let forNextText = "FOR NEXT" as NSString
        for run in forNext {
            let word = forNextText.substring(with: NSRange(location: run.location, length: run.length))
            if run.kind != .conditional { fail("\(word) should be conditional") }
        }
        if runs.first(where: { text($0) == "42" })?.tip != "64-bit integer" {
            fail("integer")
        }
        let cubes = runs.filter { text($0).caseInsensitiveCompare("cube") == .orderedSame }
        if cubes.count != 2 || cubes.contains(where: { $0.kind != .plain || $0.tip != "Defined in this file" }) {
            fail("cube \(cubes.map { "\($0.kind) \($0.tip ?? "")" })")
        }
        if runs.first(where: { text($0) == "." })?.kind != .documented {
            fail("dot")
        }
        if runs.first(where: { text($0).hasPrefix("\\") })?.kind != .comment {
            fail("line comment")
        }
        if runs.first(where: { text($0).contains("hi") })?.kind != .string {
            fail("string")
        }
        let cond = paint("IF ELSE THEN BEGIN WHILE REPEAT DUP")
        let condText = "IF ELSE THEN BEGIN WHILE REPEAT DUP" as NSString
        for run in cond {
            let word = condText.substring(with: NSRange(location: run.location, length: run.length))
            if word == "DUP" {
                if run.kind != .documented { fail("DUP should stay a normal word") }
            } else if run.kind != .conditional {
                fail("\(word) should be conditional")
            }
        }
        return fails
    }

    // MARK: - Scan

    private static func endOfLine(_ ns: NSString, from index: Int, count: Int) -> Int {
        var i = index
        while i < count {
            let c = ns.character(at: i)
            if c == 10 || c == 13 { break }
            i += 1
        }
        return i
    }

    /// `)` is unichar 41. A comment may cross lines. Depth counts nested parentheses.
    private static func endOfParen(_ ns: NSString, from index: Int, count: Int, depth startDepth: Int) -> Int {
        var i = index
        var depth = startDepth
        while i < count, depth > 0 {
            let c = ns.character(at: i)
            if c == 40 { depth += 1 }
            if c == 41 {
                depth -= 1
                i += 1
                if depth <= 0 { return i }
                continue
            }
            i += 1
        }
        return i
    }

    /// `delimiter` is `"` (34) or `)` (41). Stops at the end of the line.
    private static func endOfDelimiter(
        _ ns: NSString,
        from index: Int,
        count: Int,
        delimiter: unichar,
        escaped: Bool
    ) -> Int {
        var i = index
        while i < count {
            let c = ns.character(at: i)
            if c == 10 || c == 13 { return i }
            if escaped, c == 92 {
                i += 1
                if i < count, ns.character(at: i) != 10, ns.character(at: i) != 13 { i += 1 }
                continue
            }
            i += 1
            if c == delimiter { return i }
        }
        return i
    }

    private static func numberTip(_ token: String) -> String? {
        if token.range(of: #"^[+-]?[0-9]+$"#, options: .regularExpression) != nil {
            return "64-bit integer"
        }
        if token.range(of: #"^[+-]?[0-9]+\.[0-9]*([eE][+-]?[0-9]+)?$"#, options: .regularExpression) != nil
            || token.range(of: #"^[+-]?\.[0-9]+([eE][+-]?[0-9]+)?$"#, options: .regularExpression) != nil {
            return "floating-point number"
        }
        if token.range(of: #"^\$[0-9A-Fa-f]+$"#, options: .regularExpression) != nil {
            return "hexadecimal integer"
        }
        if token.range(of: #"^%[01]+$"#, options: .regularExpression) != nil {
            return "binary integer"
        }
        if token.range(of: #"^[#&][0-9]+$"#, options: .regularExpression) != nil {
            return "decimal integer"
        }
        return nil
    }
}
