//
//  AskForthStandardBoost.swift
//  EditForth
//
//  When the Ask Forth prompt looks like a word lookup, resolve candidates
//  against a shipped Forth-2012 word→URL map and fetch forth-standard.org pages.
//

import Foundation

enum AskForthStandardBoost {
    private static let mapFileName = "Forth-2012-word-urls.json"
    private static let hostBase = "https://forth-standard.org/"
    private static let maxWords = 3

    private static var cachedMap: [String: String]?
    private static var cacheLock = NSLock()

    /// Candidate standard words in `prompt`, in priority order (max `maxWords`).
    static func candidateWords(in prompt: String) -> [String] {
        let map = loadWordMap()
        guard !map.isEmpty else { return [] }

        var ordered: [String] = []
        var seen = Set<String>()

        func consider(_ raw: String) {
            let word = normalizeCandidate(raw)
            guard !word.isEmpty, map[word] != nil else { return }
            guard seen.insert(word).inserted else { return }
            ordered.append(word)
        }

        // 1) Backtick-quoted tokens: `OPEN-FILE`
        if let re = try? NSRegularExpression(pattern: #"`([^`]+)`"#) {
            let ns = prompt as NSString
            for match in re.matches(in: prompt, range: NSRange(location: 0, length: ns.length)) {
                guard match.numberOfRanges >= 2 else { continue }
                consider(ns.substring(with: match.range(at: 1)))
            }
        }

        // 2) Explicit lookup phrasing.
        let patterns = [
            #"(?i)\bwhat\s+does\s+[`'"]?(\S+?)[`'"]?\s*(?:do|mean)?\b"#,
            #"(?i)\b(?:stack\s+effect|explain|define|definition\s+of|meaning\s+of)\s+[`'"]?(\S+?)[`'"]?\b"#,
            #"(?i)\b(?:how\s+(?:do(?:es)?\s+)?(?:i\s+)?use)\s+[`'"]?(\S+?)[`'"]?\b"#,
        ]
        for pat in patterns {
            guard let re = try? NSRegularExpression(pattern: pat) else { continue }
            let ns = prompt as NSString
            for match in re.matches(in: prompt, range: NSRange(location: 0, length: ns.length)) {
                guard match.numberOfRanges >= 2 else { continue }
                consider(ns.substring(with: match.range(at: 1)))
            }
        }

        // 3) Short prompts: any known standard words as Forth-ish tokens.
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if ordered.isEmpty, trimmed.count <= 120 {
            for token in forthTokens(in: trimmed) {
                consider(token)
                if ordered.count >= maxWords { break }
            }
        }

        if ordered.count > maxWords {
            return Array(ordered.prefix(maxWords))
        }
        return ordered
    }

    /// forth-standard.org URLs for lookup candidates in `prompt`.
    static func standardURLs(for prompt: String) -> [URL] {
        let map = loadWordMap()
        var urls: [URL] = []
        for word in candidateWords(in: prompt) {
            guard let path = map[word] else { continue }
            let absolute = hostBase + path
            if let url = URL(string: absolute) {
                urls.append(url)
            }
        }
        return urls
    }

    /// Fetch standard pages for lookup-like prompts (empty if none).
    static func fetchBoost(for prompt: String) async -> AskForthURLFetchResult {
        let urls = standardURLs(for: prompt)
        guard !urls.isEmpty else {
            return AskForthURLFetchResult(excerpts: [], errors: [])
        }
        return await AskForthURLFetch.fetchExcerpts(urls: urls)
    }

    // MARK: - Map loading

    static func loadWordMap() -> [String: String] {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let cachedMap { return cachedMap }

        let urls = candidateMapFileURLs()
        for url in urls {
            guard let data = try? Data(contentsOf: url),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                  !obj.isEmpty
            else { continue }
            cachedMap = obj
            return obj
        }
        cachedMap = [:]
        return [:]
    }

    private static func candidateMapFileURLs() -> [URL] {
        var list: [URL] = []
        let user = ForthMenuSupport.userTreeURL
            .appendingPathComponent("Library/Reference/\(mapFileName)", isDirectory: false)
        list.append(user)
        if let app = SixtyFourForthLocator.locateApp() {
            list.append(
                app.appendingPathComponent(
                    "Contents/Resources/Library/Reference/\(mapFileName)",
                    isDirectory: false
                )
            )
        }
        // Debug / source tree fallback while iterating.
        let src = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Forth/Resources/Library/Reference/\(mapFileName)")
        list.append(src)
        return list
    }

    // MARK: - Token helpers

    private static func normalizeCandidate(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip trailing sentence punctuation (not Forth-significant).
        while let last = s.last, ".,;:!?".contains(last) {
            s.removeLast()
        }
        // Drop surrounding quotes left by patterns.
        if s.count >= 2 {
            let pairs: [(Character, Character)] = [("\"", "\""), ("'", "'"), ("`", "`")]
            for (a, b) in pairs {
                if s.first == a, s.last == b {
                    s = String(s.dropFirst().dropLast())
                }
            }
        }
        return s
    }

    /// Whitespace-split tokens; keep Forth punctuation inside tokens.
    private static func forthTokens(in text: String) -> [String] {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).map(String.init)
    }
}
