//
//  AskForthWebSearch.swift
//  EditForth
//
//  Opt-in web search for Ask Forth: query DuckDuckGo Lite (no API key),
//  parse title / URL / snippet hits, and return capped text for the LLM.
//

import Foundation

struct AskForthWebSearchHit: Sendable {
    var title: String
    var url: String
    var snippet: String
}

struct AskForthWebSearchResult: Sendable {
    var query: String
    var hits: [AskForthWebSearchHit]
    var error: String?

    var isEmpty: Bool { hits.isEmpty }

    /// Block for the model user message.
    func contextBlock(maxChars: Int) -> String {
        guard !hits.isEmpty else { return "" }
        var out = "Web search results (fetched by EditForth via DuckDuckGo Lite for query “\(query)”; prefer these when relevant; verify before inventing URLs):\n"
        for (i, hit) in hits.enumerated() {
            let n = i + 1
            let header = "\n\(n). \(hit.title)\n   \(hit.url)\n"
            let body = hit.snippet.isEmpty ? "" : "   \(hit.snippet)\n"
            if out.count + header.count + body.count > maxChars {
                let room = max(0, maxChars - out.count - header.count - 20)
                if room < 40 { break }
                out += header
                if room > 0, !hit.snippet.isEmpty {
                    out += "   " + String(hit.snippet.prefix(room)) + "\n…"
                }
                break
            }
            out += header
            out += body
        }
        return out
    }

    /// Comment lines for the AskForth file (audit trail).
    func auditCommentLines() -> [String] {
        guard !hits.isEmpty else { return [] }
        var lines = ["\\ Web search: \(query)"]
        for hit in hits.prefix(Self.maxHits) {
            let title = hit.title.replacingOccurrences(of: "\n", with: " ")
            lines.append("\\   \(hit.url) — \(title)")
        }
        return lines
    }

    var statusNote: String {
        if let error, hits.isEmpty {
            return " · Search: \(error)"
        }
        if hits.isEmpty {
            return " · Search: no hits"
        }
        if let error {
            return " · Search \(hits.count) hit(s) (\(error))"
        }
        return " · Search \(hits.count) hit(s)"
    }

    static let maxHits = 5
}

enum AskForthWebSearch {
    static let maxHits = AskForthWebSearchResult.maxHits
    static let maxQueryChars = 200
    static let maxSnippetChars = 400
    static let maxContextChars = 8_000
    static let timeoutSeconds: TimeInterval = 15
    private static let endpoint = URL(string: "https://lite.duckduckgo.com/lite/")!

    /// Collapse whitespace, strip bare URLs, cap length — use as the search query.
    static func searchQuery(from prompt: String) -> String {
        var s = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        // Drop http(s) URLs so search focuses on the question text.
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let ns = s as NSString
            let matches = detector.matches(in: s, range: NSRange(location: 0, length: ns.length))
            for match in matches.reversed() {
                s = (s as NSString).replacingCharacters(in: match.range, with: " ")
            }
        }
        s = s.replacingOccurrences(of: "\r\n", with: "\n")
        s = s.replacingOccurrences(of: "\n", with: " ")
        while s.contains("  ") {
            s = s.replacingOccurrences(of: "  ", with: " ")
        }
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.count > maxQueryChars {
            s = String(s.prefix(maxQueryChars))
        }
        return s
    }

    /// Run DuckDuckGo Lite search for `prompt` (query derived via `searchQuery`).
    static func search(prompt: String) async -> AskForthWebSearchResult {
        let query = searchQuery(from: prompt)
        guard !query.isEmpty else {
            return AskForthWebSearchResult(query: "", hits: [], error: "empty query")
        }
        do {
            let html = try await fetchLiteHTML(query: query)
            if html.range(of: "anomaly-modal", options: .caseInsensitive) != nil
                || html.range(of: "bots use DuckDuckGo", options: .caseInsensitive) != nil {
                return AskForthWebSearchResult(query: query, hits: [], error: "blocked by DuckDuckGo")
            }
            let hits = parseLiteResults(html)
            if hits.isEmpty {
                return AskForthWebSearchResult(query: query, hits: [], error: "no hits")
            }
            return AskForthWebSearchResult(query: query, hits: Array(hits.prefix(maxHits)), error: nil)
        } catch {
            return AskForthWebSearchResult(query: query, hits: [], error: error.localizedDescription)
        }
    }

    private static func fetchLiteHTML(query: String) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeoutSeconds
        request.setValue(
            "EditForth-AskForth/1.0 (web search; +https://github.com/Win32Forth/EditForth)",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("text/html,application/xhtml+xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")

        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=")
        let encoded = query.addingPercentEncoding(withAllowedCharacters: allowed) ?? query
        request.httpBody = Data("q=\(encoded)".utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200...299).contains(code) else {
            throw URLError(.badServerResponse)
        }
        return String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""
    }

    /// Parse `result-link` / `result-snippet` pairs from DuckDuckGo Lite HTML.
    static func parseLiteResults(_ html: String) -> [AskForthWebSearchHit] {
        // Anchor may list href before or after class='result-link'.
        guard let linkRe = try? NSRegularExpression(
            pattern: #"<a\b([^>]*class=['\"]result-link['\"][^>]*)>(.*?)</a>"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return [] }
        guard let hrefRe = try? NSRegularExpression(
            pattern: #"href=['\"]([^'\"]+)['\"]"#,
            options: [.caseInsensitive]
        ) else { return [] }
        guard let snipRe = try? NSRegularExpression(
            pattern: #"<td[^>]*class=['\"]result-snippet['\"][^>]*>(.*?)</td>"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return [] }

        let ns = html as NSString
        let full = NSRange(location: 0, length: ns.length)
        let linkMatches = linkRe.matches(in: html, range: full)
        let snipMatches = snipRe.matches(in: html, range: full)

        var hits: [AskForthWebSearchHit] = []
        var seen = Set<String>()

        for (i, match) in linkMatches.enumerated() {
            guard match.numberOfRanges >= 3 else { continue }
            let attrs = ns.substring(with: match.range(at: 1))
            let hrefMatch = hrefRe.firstMatch(in: attrs, range: NSRange(location: 0, length: (attrs as NSString).length))
            guard let hrefMatch, hrefMatch.numberOfRanges >= 2 else { continue }
            let href = (attrs as NSString).substring(with: hrefMatch.range(at: 1))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let titleHTML = ns.substring(with: match.range(at: 2))
            let title = stripTags(titleHTML).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = normalizeResultURL(href), seen.insert(url).inserted else { continue }

            var snippet = ""
            if i < snipMatches.count {
                let snipHTML = ns.substring(with: snipMatches[i].range(at: 1))
                snippet = stripTags(snipHTML).trimmingCharacters(in: .whitespacesAndNewlines)
                if snippet.count > maxSnippetChars {
                    snippet = String(snippet.prefix(maxSnippetChars)) + "…"
                }
            }
            guard !title.isEmpty else { continue }
            hits.append(AskForthWebSearchHit(title: title, url: url, snippet: snippet))
            if hits.count >= maxHits { break }
        }
        return hits
    }

    private static func normalizeResultURL(_ href: String) -> String? {
        var s = href.trimmingCharacters(in: .whitespacesAndNewlines)
        // Some DDG builds wrap redirects; unwrap uddg= if present.
        if let range = s.range(of: "uddg=") {
            let rest = String(s[range.upperBound...])
            let enc = rest.split(separator: "&").first.map(String.init) ?? rest
            if let decoded = enc.removingPercentEncoding, decoded.hasPrefix("http") {
                s = decoded
            }
        }
        guard let url = URL(string: s) else { return nil }
        let scheme = (url.scheme ?? "").lowercased()
        guard scheme == "http" || scheme == "https" else { return nil }
        return url.absoluteString
    }

    private static func stripTags(_ html: String) -> String {
        var s = AskForthURLFetch.htmlToText(html)
        s = s.replacingOccurrences(of: "\n", with: " ")
        while s.contains("  ") {
            s = s.replacingOccurrences(of: "  ", with: " ")
        }
        return s
    }
}
