//
//  ForthGlossary.swift
//  EditForth
//
//  Forth 2012 word entries from System/Reference, for editor highlighting.
//  The text chapters are the shipped standard. This does not fetch the web.
//

import Foundation

enum ForthGlossary {
    struct Entry {
        var word: String
        var wordset: String
        var stack: String
        var summary: String

        var tip: String {
            var lines: [String] = []
            if wordset.isEmpty {
                lines.append(word)
            } else {
                lines.append("\(word)  \(wordset)")
            }
            if !stack.isEmpty { lines.append(stack) }
            if !summary.isEmpty { lines.append(summary) }
            return lines.joined(separator: "\n")
        }
    }

    private static let lock = NSLock()
    private static var cached: [String: Entry]?

    /// Case-insensitive. Empty when the reference files cannot be read.
    static func entry(for word: String) -> Entry? {
        let key = word.uppercased()
        guard !key.isEmpty else { return nil }
        return load()[key]
    }

    static func load() -> [String: Entry] {
        lock.lock()
        defer { lock.unlock() }
        if let cached { return cached }
        let built = build()
        cached = built
        return built
    }

    /// Empty when the shipped glossary still answers these lookups.
    static func selfCheck() -> [String] {
        var fails: [String] = []
        let map = load()
        if map.count < 350 {
            fails.append("glossary has \(map.count) entries")
        }
        func need(_ word: String, stack: String, summary: String) {
            guard let entry = map[word.uppercased()] else {
                fails.append("missing \(word)")
                return
            }
            if !entry.stack.contains(stack) {
                fails.append("\(word) stack [\(entry.stack)]")
            }
            if !summary.isEmpty, !entry.summary.localizedCaseInsensitiveContains(summary) {
                fails.append("\(word) summary [\(entry.summary)]")
            }
        }
        need("DUP", stack: "x -- x x", summary: "Duplicate")
        need("*", stack: "n1", summary: "Multiply")
        need(":", stack: "--", summary: "")
        need("ELSE", stack: "C: orig1 -- orig2", summary: "undefined")
        need("FSIN", stack: "F: r1 -- r2", summary: "sine")
        need("OPEN-FILE", stack: "c-addr u fam -- fileid ior", summary: "Open the file")
        need("AT-XY", stack: "u1 u2 --", summary: "column")
        return fails
    }

    // MARK: - Load

    private static let glossaryFiles = [
        "Forth-2012-core.txt",
        "Forth-2012-block.txt",
        "Forth-2012-double.txt",
        "Forth-2012-exception.txt",
        "Forth-2012-facility.txt",
        "Forth-2012-file.txt",
        "Forth-2012-float.txt",
        "Forth-2012-locals.txt",
        "Forth-2012-memory.txt",
        "Forth-2012-search.txt",
        "Forth-2012-string.txt",
        "Forth-2012-tools.txt",
        "Forth-2012-xchar.txt",
    ]

    private static func build() -> [String: Entry] {
        guard let dir = referenceDirectory() else { return [:] }
        let names = wordNames(in: dir)
        guard !names.isEmpty else { return [:] }
        var entries: [String: Entry] = [:]
        for file in glossaryFiles {
            let url = dir.appendingPathComponent(file)
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            parse(text, names: names, into: &entries)
        }
        return entries
    }

    /// First Reference folder that holds the word list.
    private static func referenceDirectory() -> URL? {
        var candidates: [URL] = []
        candidates.append(
            ForthMenuSupport.userTreeURL.appendingPathComponent("System/Reference", isDirectory: true)
        )
        if let app = SixtyFourForthLocator.locateApp() {
            candidates.append(
                app.appendingPathComponent("Contents/Resources/System/Reference", isDirectory: true)
            )
        }
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Forth/Resources/System/Reference", isDirectory: true)
        candidates.append(source)
        let mapName = "Forth-2012-word-urls.json"
        for dir in candidates {
            let map = dir.appendingPathComponent(mapName)
            if FileManager.default.fileExists(atPath: map.path) { return dir }
        }
        return nil
    }

    private static func wordNames(in dir: URL) -> Set<String> {
        let url = dir.appendingPathComponent("Forth-2012-word-urls.json")
        guard let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        else { return [] }
        return Set(obj.keys)
    }

    /// A glossary heading such as `6.1.1290` or `12.6.2.1614`.
    private static func isSectionID(_ line: String) -> Bool {
        guard line.count >= 5, line.allSatisfy({ $0.isNumber || $0 == "." }) else { return false }
        let parts = line.split(separator: ".")
        return parts.count >= 3 && parts.allSatisfy { !$0.isEmpty && $0.allSatisfy(\.isNumber) }
    }

    private static func isWordset(_ line: String) -> Bool {
        guard !line.isEmpty, line.unicodeScalars.allSatisfy({ scalar in
            let v = scalar.value
            return (v >= 65 && v <= 90) || v == 32 || v == 45
        }) else { return false }
        return line.first?.isUppercase == true
    }

    private static func normalized(_ line: String) -> String {
        line.replacingOccurrences(of: "\u{00A0}", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    private static func parse(_ text: String, names: Set<String>, into entries: inout [String: Entry]) {
        let raw = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map(String.init)
        var index = 0
        while index < raw.count {
            let line = normalized(raw[index])
            guard isSectionID(line) else {
                index += 1
                continue
            }
            var cursor = index + 1
            while cursor < raw.count, normalized(raw[cursor]).isEmpty { cursor += 1 }
            guard cursor < raw.count else { break }
            let word = normalized(raw[cursor])
            guard names.contains(word), !word.contains(" ") else {
                index += 1
                continue
            }
            cursor += 1
            while cursor < raw.count, normalized(raw[cursor]).isEmpty { cursor += 1 }
            if cursor < raw.count, !isWordset(normalized(raw[cursor])) {
                cursor += 1
                while cursor < raw.count, normalized(raw[cursor]).isEmpty { cursor += 1 }
            }
            var wordset = ""
            if cursor < raw.count, isWordset(normalized(raw[cursor])) {
                wordset = normalized(raw[cursor])
                cursor += 1
            }
            var body: [String] = []
            while cursor < raw.count {
                let next = normalized(raw[cursor])
                if isSectionID(next) { break }
                body.append(raw[cursor])
                cursor += 1
            }
            let parsed = parseBody(body)
            let entry = Entry(word: word, wordset: wordset, stack: parsed.stack, summary: parsed.summary)
            let key = word.uppercased()
            if let old = entries[key] {
                if entry.summary.count > old.summary.count { entries[key] = entry }
            } else {
                entries[key] = entry
            }
            index = cursor
        }
    }

    private static let stopHeads: Set<String> = ["Testing", "See", "Rationale", "Implementation"]
    private static let labels: Set<String> = ["Interpretation", "Compilation", "Run-time", "Execution"]

    private static func parseBody(_ lines: [String]) -> (stack: String, summary: String) {
        var stacks: [String] = []
        var stackBuf: [String] = []
        var label = ""
        var summary: [String] = []
        var summarizing = false

        func flushStack() {
            let text = stackBuf.map { normalized($0) }.filter { !$0.isEmpty }.joined(separator: " ")
            stackBuf.removeAll()
            guard text.contains("--") else { return }
            if label.isEmpty {
                stacks.append(text)
            } else {
                stacks.append("\(label): \(text)")
            }
        }

        for line in lines {
            let trimmed = normalized(line)
            if trimmed.isEmpty {
                if !stackBuf.isEmpty { flushStack() }
                summarizing = false
                continue
            }
            if stopHeads.contains(trimmed) || trimmed.hasPrefix("See ") {
                flushStack()
                break
            }
            if labels.contains(trimmed) {
                flushStack()
                label = trimmed
                summarizing = false
                continue
            }
            if trimmed == "or" || trimmed.hasPrefix("(") || (trimmed.contains("--") && trimmed.contains("(")) {
                stackBuf.append(trimmed)
                summarizing = false
                continue
            }
            if !stackBuf.isEmpty { flushStack() }
            if summary.isEmpty || summarizing {
                summarizing = true
                summary.append(trimmed)
                if summary.joined(separator: " ").count > 420 { break }
            }
        }
        flushStack()
        var prose = summary.joined(separator: " ")
        if prose.count > 420 {
            prose = String(prose.prefix(420)).trimmingCharacters(in: .whitespaces) + "…"
        }
        return (stacks.prefix(3).joined(separator: "\n"), prose)
    }
}
