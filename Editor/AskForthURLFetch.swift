//
//  AskForthURLFetch.swift
//  EditForth
//
//  Opt-in web context for Ask Forth: extract https URLs from the prompt,
//  fetch pages, strip to plain text, and return capped excerpts for the LLM.
//

import Foundation

struct AskForthURLFetchResult: Sendable {
    var excerpts: [(url: String, text: String)]
    var errors: [(url: String, message: String)]

    var isEmpty: Bool { excerpts.isEmpty }

    /// Block to prepend/append to the model user message.
    func contextBlock(maxChars: Int) -> String {
        guard !excerpts.isEmpty else { return "" }
        var out = "Web page context (fetched by EditForth from Prompt URLs and/or forth-standard.org; prefer facts from these pages when relevant):\n"
        for item in excerpts {
            let header = "\n--- \(item.url) ---\n"
            if out.count + header.count + item.text.count > maxChars {
                let room = max(0, maxChars - out.count - header.count - 20)
                if room < 80 { break }
                out += header
                out += String(item.text.prefix(room))
                out += "\n…"
                break
            }
            out += header
            out += item.text
            if !item.text.hasSuffix("\n") { out += "\n" }
        }
        return out
    }

    var statusNote: String {
        if excerpts.isEmpty, errors.isEmpty { return "" }
        if !excerpts.isEmpty, errors.isEmpty {
            return " · Web \(excerpts.count) page(s)"
        }
        if excerpts.isEmpty {
            return " · Web: \(errors.count) fetch error(s)"
        }
        return " · Web \(excerpts.count) page(s), \(errors.count) error(s)"
    }
}

enum AskForthURLFetch {
    static let maxURLs = 4
    static let maxBytesPerPage = 200_000
    static let maxCharsPerExcerpt = 8_000
    static let timeoutSeconds: TimeInterval = 15

    /// http/https URLs in `text`, de-duplicated, capped.
    static func extractURLs(from text: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        var seen = Set<String>()
        var urls: [URL] = []
        detector.enumerateMatches(in: text, options: [], range: range) { match, _, stop in
            guard let match, let url = match.url else { return }
            let scheme = (url.scheme ?? "").lowercased()
            guard scheme == "http" || scheme == "https" else { return }
            let key = url.absoluteString
            guard !seen.contains(key) else { return }
            seen.insert(key)
            urls.append(url)
            if urls.count >= maxURLs {
                stop.pointee = true
            }
        }
        return urls
    }

    /// Fetch each URL found in `text` and return plain-text excerpts.
    static func fetchExcerpts(from text: String) async -> AskForthURLFetchResult {
        await fetchExcerpts(urls: extractURLs(from: text))
    }

    /// Fetch the given URLs (de-duplicated by absoluteString).
    static func fetchExcerpts(urls: [URL]) async -> AskForthURLFetchResult {
        guard !urls.isEmpty else {
            return AskForthURLFetchResult(excerpts: [], errors: [])
        }

        var seen = Set<String>()
        var excerpts: [(String, String)] = []
        var errors: [(String, String)] = []

        for url in urls {
            let key = url.absoluteString
            guard seen.insert(key).inserted else { continue }
            do {
                let raw = try await fetchData(url: url)
                let text = plainText(from: raw, url: url)
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    errors.append((key, "empty after HTML strip"))
                    continue
                }
                let capped = String(trimmed.prefix(maxCharsPerExcerpt))
                excerpts.append((key, capped))
            } catch {
                errors.append((key, error.localizedDescription))
            }
        }
        return AskForthURLFetchResult(excerpts: excerpts, errors: errors)
    }

    /// Merge two fetch results (later excerpts skipped if URL already present).
    static func merge(_ a: AskForthURLFetchResult, _ b: AskForthURLFetchResult) -> AskForthURLFetchResult {
        var seen = Set(a.excerpts.map(\.url))
        var excerpts = a.excerpts
        for item in b.excerpts where seen.insert(item.url).inserted {
            excerpts.append(item)
        }
        return AskForthURLFetchResult(excerpts: excerpts, errors: a.errors + b.errors)
    }

    private static func fetchData(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeoutSeconds
        request.setValue(
            "EditForth-AskForth/1.0 (URL context; +https://github.com/Win32Forth/EditForth)",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("text/html,text/plain,application/xhtml+xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200...299).contains(code) else {
            throw URLError(.badServerResponse)
        }
        if data.count > maxBytesPerPage {
            return data.prefix(maxBytesPerPage)
        }
        return data
    }

    /// Prefer UTF-8; fall back to ISO Latin-1. Strip tags when Content looks like HTML.
    static func plainText(from data: Data, url: URL) -> String {
        let raw = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""
        let pathExt = url.pathExtension.lowercased()
        let looksHTML = pathExt == "html" || pathExt == "htm"
            || raw.range(of: "<html", options: .caseInsensitive) != nil
            || raw.range(of: "<body", options: .caseInsensitive) != nil
            || raw.range(of: "<!DOCTYPE html", options: .caseInsensitive) != nil
        if looksHTML {
            return htmlToText(raw)
        }
        return raw
    }

    /// Lightweight HTML → text (no WebKit). Good enough for standard pages and READMEs.
    static func htmlToText(_ html: String) -> String {
        var s = html
        // Drop script/style blocks.
        s = replace(pattern: #"(?is)<script[^>]*>.*?</script>"#, in: s, with: "\n")
        s = replace(pattern: #"(?is)<style[^>]*>.*?</style>"#, in: s, with: "\n")
        s = replace(pattern: #"(?is)<noscript[^>]*>.*?</noscript>"#, in: s, with: "\n")
        // Block breaks.
        s = replace(pattern: #"(?i)<br\s*/?>"#, in: s, with: "\n")
        s = replace(pattern: #"(?i)</p>"#, in: s, with: "\n\n")
        s = replace(pattern: #"(?i)</(h[1-6]|div|tr|li|pre|section|article)>"#, in: s, with: "\n")
        s = replace(pattern: #"(?i)<(h[1-6]|p|div|li|tr|section|article)[^>]*>"#, in: s, with: "\n")
        // Remaining tags.
        s = replace(pattern: #"<[^>]+>"#, in: s, with: "")
        // Entities.
        s = decodeBasicEntities(s)
        s = s.replacingOccurrences(of: "\r\n", with: "\n")
        s = s.replacingOccurrences(of: "\r", with: "\n")
        s = replace(pattern: #"[ \t]+\n"#, in: s, with: "\n")
        s = replace(pattern: #"\n{3,}"#, in: s, with: "\n\n")
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func replace(pattern: String, in text: String, with template: String) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return re.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: template)
    }

    private static func decodeBasicEntities(_ text: String) -> String {
        var s = text
        let pairs: [(String, String)] = [
            ("&nbsp;", " "),
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&#39;", "'"),
            ("&apos;", "'"),
            ("&mdash;", "—"),
            ("&ndash;", "–"),
        ]
        for (ent, ch) in pairs {
            s = s.replacingOccurrences(of: ent, with: ch)
        }
        // Numeric &#NNN;
        if let re = try? NSRegularExpression(pattern: #"&#(\d+);"#) {
            let ns = s as NSString
            let matches = re.matches(in: s, range: NSRange(location: 0, length: ns.length))
            for match in matches.reversed() {
                guard match.numberOfRanges >= 2 else { continue }
                let numStr = ns.substring(with: match.range(at: 1))
                if let v = Int(numStr), let scalar = UnicodeScalar(v) {
                    let full = match.range
                    s = (s as NSString).replacingCharacters(in: full, with: String(Character(scalar)))
                }
            }
        }
        return s
    }
}
