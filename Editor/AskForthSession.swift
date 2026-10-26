//
//  AskForthSession.swift
//  EditForth
//
//  Host-owned Ask Forth session file. The model never rewrites the header.
//  Earlier drafts are line-commented so INCLUDE loads only the newest section.
//  `\\` … `{` cannot wrap old drafts: any `{` ends that F-PC block comment.
//

import Foundation

enum AskForthSession {
    static let liveMarker = "\\ --- live ---"
    static let draftMarker = "\\ --- earlier draft ---"
    static let contextCap = 16_000

    enum Entry: Equatable {
        case prompt(text: String, reference: String?)
        case note(String)
    }

    struct Document: Equatable {
        var entries: [Entry]
        var archive: String
        var live: String
    }

    // MARK: - Parse

    /// Header is everything before the first line that is only `{`.
    /// Body after the last `\ --- live ---` line is the live section.
    /// A legacy file with no marker treats the whole body as live.
    static func parse(_ text: String) -> Document {
        let lines = splitLines(normalizeNewlines(text))
        var header: [String] = []
        var body: [String] = []
        var sawCloser = false
        for line in lines {
            if !sawCloser && line.trimmingCharacters(in: .whitespaces) == "{" {
                sawCloser = true
                continue
            }
            if sawCloser {
                body.append(line)
            } else {
                header.append(line)
            }
        }
        guard sawCloser else {
            return Document(entries: [], archive: "", live: trimBoundingNewlines(normalizeNewlines(text)))
        }
        let entries = parseEntries(header)
        if let idx = body.lastIndex(where: { isExactMarker($0, liveMarker) }) {
            let before = body[..<idx].joined(separator: "\n")
            let after = body[body.index(after: idx)...].joined(separator: "\n")
            return Document(
                entries: entries,
                archive: trimBoundingNewlines(before),
                live: trimBoundingNewlines(after)
            )
        }
        return Document(
            entries: entries,
            archive: "",
            live: trimBoundingNewlines(body.joined(separator: "\n"))
        )
    }

    // MARK: - Render

    static func renderHeader(
        model: String,
        temperature: String,
        settingLines: [String],
        sessionReference: String?,
        entries: [Entry]
    ) -> String {
        let modelText = model.trimmingCharacters(in: .whitespacesAndNewlines)
        var lines: [String] = [
            "\\\\ Ask Forth",
            "\\ Model: \(sanitizeHeader(modelText.isEmpty ? "(none)" : modelText))",
            "\\ Temperature: \(sanitizeHeader(temperature))",
        ]
        for raw in settingLines {
            let safe = sanitizeHeader(raw.replacingOccurrences(of: "\n", with: " "))
            if safe.isEmpty { continue }
            lines.append("\\ " + safe)
        }
        lines.append("\\ Reference: \(sanitizeHeader(referenceLabel(sessionReference)))")
        lines.append("\\ Earlier drafts are line comments. INCLUDE loads only the newest section.")
        lines.append("\\")

        var promptIndex = 0
        for entry in entries {
            switch entry {
            case .prompt(let text, let reference):
                promptIndex += 1
                lines.append("\\ Prompt \(promptIndex):")
                lines.append("\\ Reference: \(sanitizeHeader(referenceLabel(reference)))")
                let parts = splitLines(normalizeNewlines(text))
                if parts.isEmpty {
                    lines.append("\\")
                } else {
                    for part in parts {
                        lines.append(storedPromptLine(part))
                    }
                }
            case .note(let note):
                lines.append(storedNoteLine(note))
            }
        }
        lines.append("{")
        return lines.joined(separator: "\n") + "\n"
    }

    /// Header plus commented archive plus the live marker. The model streams after this.
    static func renderPrefix(header: String, archive: String) -> String {
        var s = header
        if !s.hasSuffix("\n") { s += "\n" }
        let arch = trimBoundingNewlines(archive)
        if !arch.isEmpty {
            s += "\n"
            s += arch
            s += "\n"
        }
        s += "\n"
        s += liveMarker
        s += "\n"
        return s
    }

    /// Comment out one live section. Already-archived text must not be passed here.
    static func archiveLive(_ live: String) -> String {
        let core = trimBoundingNewlines(live)
        if core.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "" }
        var out: [String] = [draftMarker]
        for line in splitLines(core) {
            if line.isEmpty {
                out.append("\\")
            } else {
                out.append("\\ " + line)
            }
        }
        return out.joined(separator: "\n")
    }

    static func combineArchive(existing: String, added: String) -> String {
        let a = trimBoundingNewlines(existing)
        let b = trimBoundingNewlines(added)
        if a.isEmpty { return b }
        if b.isEmpty { return a }
        return a + "\n\n" + b
    }

    // MARK: - Model text

    /// Make a model reply safe to INCLUDE as the live section.
    /// Fenced prose becomes line comments. `\\`, `\S`, and `\\S` cannot start a word.
    /// An unclosed `(` is closed only when `closeParens` is true (final write).
    static func sanitizeLive(_ text: String, closeParens: Bool) -> String {
        let normalized = normalizeNewlines(text)
        var out = ""
        for piece in fencedPieces(normalized) {
            let rendered = piece.isCode ? sanitizeCode(piece.text) : commentProse(piece.text)
            guard !rendered.isEmpty else { continue }
            if !out.isEmpty && !out.hasSuffix("\n") { out += "\n" }
            out += rendered
        }
        if closeParens {
            out = closeUnclosedParenComments(out)
        }
        return out
    }

    static func agentEnhanceNote(from transcript: String) -> String {
        var status: String?
        var depth: String?
        var search = transcript[...]
        while let range = search.range(of: "status=") {
            let after = search[range.upperBound...]
            let num = after.prefix(while: { $0 == "-" || $0.isNumber })
            if !num.isEmpty {
                status = String(num)
                if let depthRange = after.range(of: "depth=") {
                    let depthAfter = after[depthRange.upperBound...]
                    let depthNum = depthAfter.prefix(while: { $0 == "-" || $0.isNumber })
                    if !depthNum.isEmpty {
                        depth = String(depthNum)
                    }
                }
            }
            search = after
        }
        if let status, let depth {
            return "\\ Agent enhance: status=\(status) depth=\(depth)"
        }
        if transcript.contains("DONE (failed)") {
            return "\\ Agent enhance: status=failed"
        }
        if transcript.contains("DONE (ok)") {
            return "\\ Agent enhance: status=0"
        }
        return "\\ Agent enhance: status=unknown"
    }

    /// Earlier prompts and the previous live section, for a follow-up Ask.
    static func modelPreface(entries: [Entry], previousLive: String) -> String {
        var parts: [String] = [
            "This continues an Ask Forth session. Reply with only the new live Forth for the new request. Do not repeat the header, earlier prompts, or earlier drafts. The host comments out the previous live section; your reply is the only Forth INCLUDE loads."
        ]
        var promptBlock = ""
        var count = 0
        for entry in entries {
            guard case .prompt(let text, let reference) = entry else { continue }
            count += 1
            if !promptBlock.isEmpty { promptBlock += "\n" }
            promptBlock += "\(count). "
            if let reference, !reference.isEmpty {
                promptBlock += "[reference: \(reference)] "
            }
            promptBlock += text
        }
        if count > 0 {
            parts.append("Earlier prompts:\n" + promptBlock)
        }
        let live = trimBoundingNewlines(previousLive)
        if !live.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            var shown = live
            if shown.count > contextCap {
                shown = String(shown.prefix(contextCap)) + "\n[truncated — previous live Forth continues]"
            }
            parts.append("Previous live Forth:\n" + shown)
        }
        return parts.joined(separator: "\n\n")
    }

    /// `contents == nil` means the file could not be read. Ask still proceeds.
    static func referenceContextBlock(path: String, contents: String?) -> String {
        guard let contents else {
            return "Read-only reference file could not be read: \(path)\nContinue without its contents."
        }
        var body = contents
        var note = ""
        if body.count > contextCap {
            body = String(body.prefix(contextCap))
            note = "\n[truncated — reference file continues beyond \(contextCap) characters]"
        }
        return """
        Read-only reference file (never write this file; put suggestions only in the Ask Forth reply):
        Path: \(path)
        \(body)\(note)
        """
    }

    // MARK: - Header safety

    /// `{` ends an F-PC `\\` block comment. The header must not contain one before the closer.
    static func sanitizeHeader(_ text: String) -> String {
        normalizeNewlines(text).replacingOccurrences(of: "{", with: "(brace)")
    }

    // MARK: - Private

    private static func referenceLabel(_ path: String?) -> String {
        let trimmed = path?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "(none)" : trimmed
    }

    private static func parseEntries(_ header: [String]) -> [Entry] {
        var entries: [Entry] = []
        var i = 0
        while i < header.count {
            let line = header[i]
            if isPromptStart(line) {
                i += 1
                var reference: String?
                if i < header.count, header[i].hasPrefix("\\ Reference:") {
                    reference = parseReferenceLine(header[i])
                    i += 1
                }
                var textLines: [String] = []
                while i < header.count {
                    let current = header[i]
                    if isPromptStart(current) || isAgentNote(current) { break }
                    if let body = promptBodyLine(current) {
                        textLines.append(body)
                    }
                    i += 1
                }
                entries.append(.prompt(text: textLines.joined(separator: "\n"), reference: reference))
            } else if isAgentNote(line) {
                entries.append(.note(storedNoteLine(line)))
                i += 1
            } else {
                i += 1
            }
        }
        return entries
    }

    private static func parseReferenceLine(_ line: String) -> String? {
        let prefix = "\\ Reference:"
        guard line.hasPrefix(prefix) else { return nil }
        let value = line.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
        if value.isEmpty || value == "(none)" { return nil }
        return String(value)
    }

    private static func promptBodyLine(_ line: String) -> String? {
        if line == "\\" { return "" }
        if line.hasPrefix("\\ ") { return String(line.dropFirst(2)) }
        return nil
    }

    private static func isPromptStart(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let prefix = "\\ Prompt"
        guard trimmed.hasPrefix(prefix) else { return false }
        let rest = trimmed.dropFirst(prefix.count)
        if rest == ":" { return true }
        guard rest.first == " " else { return false }
        let after = rest.dropFirst()
        guard after.last == ":" else { return false }
        let number = after.dropLast()
        return !number.isEmpty && number.allSatisfy(\.isNumber)
    }

    private static func isAgentNote(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).hasPrefix("\\ Agent enhance:")
    }

    private static func storedPromptLine(_ rawLine: String) -> String {
        let safe = sanitizeHeader(rawLine).replacingOccurrences(of: "\n", with: " ")
        if safe.isEmpty { return "\\" }
        let line = "\\ " + safe
        if isPromptStart(line) || isAgentNote(line) {
            return "\\  " + safe
        }
        return line
    }

    private static func storedNoteLine(_ note: String) -> String {
        var line = note.trimmingCharacters(in: .whitespaces)
        if line.isEmpty { return "\\ Agent enhance: status=unknown" }
        if !line.hasPrefix("\\") {
            line = "\\ " + line
        }
        return sanitizeHeader(line)
    }

    private struct Piece {
        var isCode: Bool
        var text: String
    }

    private static func fencedPieces(_ text: String) -> [Piece] {
        let fence = "```"
        guard text.contains(fence) else { return [Piece(isCode: true, text: text)] }
        let parts = text.components(separatedBy: fence)
        var pieces: [Piece] = []
        for (idx, part) in parts.enumerated() {
            if idx % 2 == 0 {
                pieces.append(Piece(isCode: false, text: part))
            } else {
                var code = part
                if let newline = code.firstIndex(of: "\n") {
                    code = String(code[code.index(after: newline)...])
                } else {
                    code = ""
                }
                pieces.append(Piece(isCode: true, text: code))
            }
        }
        return pieces
    }

    private static func commentProse(_ prose: String) -> String {
        var s = prose
        if s.hasPrefix("\n") { s.removeFirst() }
        if s.hasSuffix("\n") { s.removeLast() }
        if s.isEmpty { return "" }
        return splitLines(s).map { line in
            if line.isEmpty { return "\\" }
            if line == "\\" || line.hasPrefix("\\ ") { return neutralizeMarker(line) }
            return neutralizeMarker("\\ " + line)
        }.joined(separator: "\n")
    }

    private static func sanitizeCode(_ code: String) -> String {
        if code.isEmpty { return "" }
        return splitLines(code).map { neutralizeCodeLine($0) }.joined(separator: "\n")
    }

    private static func neutralizeCodeLine(_ line: String) -> String {
        if line.isEmpty { return line }
        if isExactMarker(line, liveMarker) || isExactMarker(line, draftMarker) || firstTokenForbidden(line) {
            return "\\ " + line
        }
        return line
    }

    private static func neutralizeMarker(_ line: String) -> String {
        if isExactMarker(line, liveMarker) || isExactMarker(line, draftMarker) {
            return "\\ " + line
        }
        return line
    }

    private static func firstTokenForbidden(_ line: String) -> Bool {
        let trimmed = line.drop(while: { $0 == " " || $0 == "\t" })
        if trimmed.isEmpty { return false }
        let token = trimmed.prefix(while: { !$0.isWhitespace })
        return token == "\\\\" || token == "\\\\S" || token == "\\S"
    }

    private static func isExactMarker(_ line: String, _ marker: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces) == marker
    }

    private static let stringWords: Set<String> = [".\"", "S\"", "C\"", "ABORT\"", "S\\\""]

    /// True when a whitespace-delimited `(` or `.(` is still open.
    /// Line comments and `."` / `S"` / `C"` / `ABORT"` / `S\"` strings do not count.
    private static func parenCommentIsOpen(_ text: String) -> Bool {
        var index = text.startIndex
        var state = 0 // 0 code, 1 line comment, 2 paren, 3 string
        while index < text.endIndex {
            let ch = text[index]
            if state == 1 {
                if ch == "\n" { state = 0 }
                index = text.index(after: index)
                continue
            }
            if state == 2 {
                if ch == ")" { state = 0 }
                index = text.index(after: index)
                continue
            }
            if state == 3 {
                if ch == "\"" {
                    state = 0
                } else if ch == "\\" {
                    let next = text.index(after: index)
                    if next < text.endIndex {
                        index = text.index(after: next)
                        continue
                    }
                }
                index = text.index(after: index)
                continue
            }
            if ch == " " || ch == "\t" || ch == "\n" || ch == "\r" {
                index = text.index(after: index)
                continue
            }
            let start = index
            while index < text.endIndex {
                let c = text[index]
                if c == " " || c == "\t" || c == "\n" || c == "\r" { break }
                index = text.index(after: index)
            }
            let token = String(text[start..<index])
            if token == "\\" {
                state = 1
            } else if token == "(" || token == ".(" {
                state = 2
            } else if stringWords.contains(token) {
                state = 3
            }
        }
        return state == 2
    }

    private static func closeUnclosedParenComments(_ text: String) -> String {
        guard parenCommentIsOpen(text) else { return text }
        if text.isEmpty { return ")" }
        if text.last?.isWhitespace == true { return text + ")" }
        return text + " )"
    }

    private static func normalizeNewlines(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    }

    private static func splitLines(_ text: String) -> [String] {
        text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    private static func trimBoundingNewlines(_ text: String) -> String {
        var t = text
        while t.first == "\n" { t.removeFirst() }
        while t.last == "\n" { t.removeLast() }
        return t
    }
}

#if ASKFORTH_SESSION_TEST
@main
enum AskForthSessionTestMain {
    static func main() {
        var failed = 0
        func check(_ name: String, _ cond: Bool, _ detail: String = "") {
            if cond {
                print("ok \(name)")
            } else {
                failed += 1
                print("FAIL \(name) \(detail)")
            }
        }

        let header = AskForthSession.renderHeader(
            model: "gemma{4}",
            temperature: "0.30",
            settingLines: ["Include Library context: on"],
            sessionReference: "/tmp/foo{bar}.fth",
            entries: [
                .prompt(text: "use { until }\nPrompt 1:\nAgent enhance: nope", reference: nil),
                .note("\\ Agent enhance: status=0 depth=2"),
                .prompt(text: "add a word", reference: "/Users/me/Library/Sample/hi.fth"),
            ]
        )
        let braceLines = header.split(separator: "\n", omittingEmptySubsequences: false).filter { $0.contains("{") }
        check("header has one brace", braceLines.count == 1 && braceLines[0] == "{", header)
        check("brace rewritten", header.contains("(brace)") && header.contains("gemma(brace)4"))

        let prefix = AskForthSession.renderPrefix(header: header, archive: "")
        let file1 = prefix + ": ONE  1 ;\n"
        let doc1 = AskForthSession.parse(file1)
        check("prompt count", doc1.entries.count == 3)
        if case .prompt(let text, let reference) = doc1.entries[0] {
            check("brace in prompt", text.contains("(brace)") && !text.contains("{"), text)
            check("escaped prompt line", text.contains("Prompt 1:"), text)
            check("escaped agent line", text.contains("Agent enhance: nope"), text)
            check("nil reference", reference == nil)
        } else {
            check("first entry prompt", false)
        }
        if case .note(let note) = doc1.entries[1] {
            check("note kept", note.contains("status=0") && note.contains("depth=2"), note)
        } else {
            check("note entry", false)
        }
        check("live one", doc1.live == ": ONE  1 ;", doc1.live)
        check("no archive yet", doc1.archive.isEmpty)

        let archived = AskForthSession.archiveLive(doc1.live)
        check("archive prefixes", archived.contains("\\ : ONE  1 ;"), archived)
        check("archive marker", archived.hasPrefix(AskForthSession.draftMarker))
        let emptyLine = AskForthSession.archiveLive(": A ;\n\n: B { ;\n")
        check("empty becomes comment", emptyLine.contains("\\\n\\ : B"), emptyLine)
        check("brace in archive stays commented", emptyLine.contains("\\ : B { ;"))

        let combined = AskForthSession.combineArchive(existing: archived, added: AskForthSession.archiveLive(": TWO  2 ;"))
        let header2 = AskForthSession.renderHeader(
            model: "gemma",
            temperature: "0.30",
            settingLines: [],
            sessionReference: nil,
            entries: doc1.entries
        )
        let file2 = AskForthSession.renderPrefix(header: header2, archive: combined) + ": THREE  3 ;\n"
        let doc2 = AskForthSession.parse(file2)
        check("live is newest", doc2.live == ": THREE  3 ;", doc2.live)
        check("archive keeps both", doc2.archive.contains(": ONE") && doc2.archive.contains(": TWO"), doc2.archive)
        check("archive not triple commented", !doc2.archive.contains("\\ \\ \\"), doc2.archive)
        let braceArchive = AskForthSession.archiveLive(": B { ;")
        let braceFile = AskForthSession.renderPrefix(header: header2, archive: braceArchive) + ": NEW ;\n"
        let braceDoc = AskForthSession.parse(braceFile)
        check("brace draft kept", braceDoc.archive.contains("\\ : B { ;"), braceDoc.archive)
        check("brace draft does not end header", braceDoc.live == ": NEW ;", braceDoc.live)

        let legacy = """
        \\\\ Ask Forth
        \\ Model: old
        \\
        \\ Prompt:
        \\ hello { there
        {

        : LEGACY  1 ;
        """
        let old = AskForthSession.parse(legacy)
        check("legacy prompt", old.entries.count == 1)
        if case .prompt(let text, _) = old.entries.first {
            check("legacy prompt text", text == "hello { there", text)
        }
        check("legacy live", old.live == ": LEGACY  1 ;", old.live)

        let fenced = AskForthSession.sanitizeLive(
            "Note\n```forth\n: DOUBLE ( n -- n )  2* ;\n```\nDone\n",
            closeParens: true
        )
        check("fence code kept", fenced.contains(": DOUBLE ( n -- n )  2* ;"), fenced)
        check("fence prose commented", fenced.contains("\\ Note") && fenced.contains("\\ Done"), fenced)
        check("fence markers gone", !fenced.contains("```"), fenced)

        let danger = AskForthSession.sanitizeLive(
            "\\\\ this swallows\n: OK ;\n\\S stop\n  \\\\S also\n\\ --- live ---\n",
            closeParens: true
        )
        check("block comment prefixed", danger.contains("\\ \\\\ this swallows"), danger)
        check("stop prefixed", danger.contains("\\ \\S stop"), danger)
        check("stop2 prefixed", danger.contains("\\   \\\\S also"), danger)
        check("marker neutralized", danger.contains("\\ \\ --- live ---"), danger)
        check("ok word stays", danger.contains(": OK ;"), danger)

        let closedSrc = ": FOO ( n -- n ) 2* ;\n"
        let closed = AskForthSession.sanitizeLive(closedSrc, closeParens: true)
        check("closed paren untouched", closed == closedSrc, closed)
        let open = AskForthSession.sanitizeLive(": FOO ( n -- n  2* ;", closeParens: true)
        check("open paren closed", open.hasSuffix(")"), open)
        let commentedSrc = "\\ ( unclosed\n: OK ;\n"
        let commented = AskForthSession.sanitizeLive(commentedSrc, closeParens: true)
        check("line comment hides paren", commented == commentedSrc, commented)
        let stringSrc = ".\" (not a comment\" )\n"
        let stringed = AskForthSession.sanitizeLive(stringSrc, closeParens: true)
        check("string hides paren", stringed == stringSrc, stringed)
        let dotted = AskForthSession.sanitizeLive(".( hi there\n", closeParens: true)
        check("dot paren closed", dotted.hasSuffix(")"), dotted)
        let streaming = AskForthSession.sanitizeLive(": FOO ( n --", closeParens: false)
        check("stream leaves paren", streaming == ": FOO ( n --", streaming)
        let longLine = String(repeating: "A", count: 120)
        let kept = AskForthSession.sanitizeLive(longLine, closeParens: true)
        check("no wrap", kept == longLine, "count \(kept.count)")

        let note = AskForthSession.agentEnhanceNote(from: """
        [64Forth agent] status=-1 depth=3
        [64Forth agent] status=0 depth=1
        [64Forth agent] DONE (ok)
        """)
        check("last status", note == "\\ Agent enhance: status=0 depth=1", note)

        let preface = AskForthSession.modelPreface(
            entries: [.prompt(text: "first", reference: "/tmp/a.fth")],
            previousLive: ": ONE  1 ;"
        )
        check("preface has prompt", preface.contains("1. [reference: /tmp/a.fth] first"), preface)
        check("preface has live", preface.contains(": ONE  1 ;"))

        let missing = AskForthSession.referenceContextBlock(path: "/tmp/missing.fth", contents: nil)
        check("missing reference", missing.contains("could not be read"))
        let big = AskForthSession.referenceContextBlock(path: "/tmp/a.fth", contents: String(repeating: "Z", count: 20_000))
        check("reference capped", big.contains("truncated") && big.count < 20_000)

        if failed != 0 {
            print("\(failed) failed")
            exit(1)
        }
        print("all ok")
    }
}
#endif

