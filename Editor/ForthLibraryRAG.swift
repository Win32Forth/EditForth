//
//  ForthLibraryRAG.swift
//  EditForth
//
//  Lightweight Library retrieval for Ask Forth: score .fth/.md/.swift hits for query
//  tokens and return capped source snippets (not embeddings).
//

import Foundation

struct ForthLibrarySnippet: Sendable {
    var relativePath: String
    var startLine: Int  // 1-based
    var text: String
    var score: Int
}

struct ForthLibraryRAGResult: Sendable {
    var snippets: [ForthLibrarySnippet]
    var rootPath: String
    var queryTokens: [String]

    var isEmpty: Bool { snippets.isEmpty }

    /// Block to append to the model user message.
    func contextBlock(maxChars: Int) -> String {
        guard !snippets.isEmpty else { return "" }
        var out = "Library context (excerpts from \(rootPath); prefer these real words/APIs when writing Forth):\n"
        for snip in snippets {
            let header = "\n--- \(snip.relativePath):\(snip.startLine) (score \(snip.score)) ---\n"
            if out.count + header.count + snip.text.count > maxChars {
                break
            }
            out += header
            out += snip.text
            if !snip.text.hasSuffix("\n") { out += "\n" }
        }
        return out
    }
}

enum ForthLibraryRAG {
    private static let skipDirNames: Set<String> = [
        ".git", "DerivedData", "PI", "VED64", "__pycache__",
        // EditForth / Xcode project trees (safe to point Library… at the repo root)
        "finetune", "Build", "build", ".build", "xcuserdata",
        "Pods", "node_modules", "models", "adapters", "fused_model",
    ]
    private static let sourceExtensions: Set<String> = [
        "fth", "fs", "4th", "f", "txt",
        "md", "swift",
    ]
    /// Same Forth-ish token characters as TextMatch / Whole Word.
    private static let wordChars = CharacterSet.alphanumerics.union(
        CharacterSet(charactersIn: "_-?!'.+*/<>=@$")
    )

    /// Resolve the search root from settings; fall back to companion Resources/Library.
    static func resolveRoot(settings: ForthLibraryRAGSettings) -> URL? {
        let preferred = settings.folderURL
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: preferred.path, isDirectory: &isDir), isDir.boolValue {
            return preferred
        }
        if let app = SixtyFourForthLocator.locateApp() {
            let bundled = app
                .appendingPathComponent("Contents/Resources/Library", isDirectory: true)
            if FileManager.default.fileExists(atPath: bundled.path, isDirectory: &isDir), isDir.boolValue {
                return bundled
            }
        }
        return nil
    }

    /// `Library/Reference` (Forth-2012 text, etc.) is always searched in addition to the
    /// configured folder, unless that folder is already the whole Library (enumerator covers it).
    static func referenceSearchRoots(primaryRoot: URL) -> [URL] {
        if primaryRoot.lastPathComponent == "Library" {
            return []
        }
        var roots: [URL] = []
        let fm = FileManager.default
        func add(_ url: URL) {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else { return }
            let std = url.standardizedFileURL
            if std == primaryRoot.standardizedFileURL { return }
            if roots.contains(where: { $0.standardizedFileURL == std }) { return }
            roots.append(std)
        }
        add(primaryRoot.deletingLastPathComponent().appendingPathComponent("Reference", isDirectory: true))
        add(ForthMenuSupport.userTreeURL.appendingPathComponent("Library/Reference", isDirectory: true))
        if let app = SixtyFourForthLocator.locateApp() {
            add(app.appendingPathComponent("Contents/Resources/Library/Reference", isDirectory: true))
        }
        return roots
    }

    static func retrieve(
        for query: String,
        settings: ForthLibraryRAGSettings = .load(),
        maxFileBytes: Int = 500_000
    ) -> ForthLibraryRAGResult {
        let tokens = significantTokens(in: query)
        guard !tokens.isEmpty else {
            return ForthLibraryRAGResult(snippets: [], rootPath: "", queryTokens: [])
        }

        guard let root = resolveRoot(settings: settings) else {
            return ForthLibraryRAGResult(snippets: [], rootPath: "", queryTokens: tokens)
        }
        let maxSnippets = settings.maxSnippets
        let contextLines = settings.contextLines

        var scored: [(URL, Int, String)] = []  // url, score, relative
        collectScoredFiles(
            under: root,
            relativePrefix: "",
            tokens: tokens,
            maxFileBytes: maxFileBytes,
            into: &scored
        )
        for refRoot in referenceSearchRoots(primaryRoot: root) {
            collectScoredFiles(
                under: refRoot,
                relativePrefix: "Reference/",
                tokens: tokens,
                maxFileBytes: maxFileBytes,
                into: &scored
            )
        }

        // Dedupe by standardized path (Reference may appear twice via sibling + user tree).
        var seen = Set<String>()
        scored = scored.filter { item in
            let key = item.0.standardizedFileURL.path
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }

        scored.sort { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
            return lhs.2 < rhs.2
        }

        var snippets: [ForthLibrarySnippet] = []
        for (url, score, rel) in scored.prefix(maxSnippets * 2) {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            if let snip = bestSnippet(
                in: text,
                relativePath: rel,
                tokens: tokens,
                score: score,
                contextLines: contextLines
            ) {
                snippets.append(snip)
            }
            if snippets.count >= maxSnippets { break }
        }

        let rootLabel: String
        if referenceSearchRoots(primaryRoot: root).isEmpty {
            rootLabel = root.path
        } else {
            rootLabel = root.path + " + Reference"
        }
        return ForthLibraryRAGResult(
            snippets: snippets,
            rootPath: rootLabel,
            queryTokens: tokens
        )
    }

    private static func collectScoredFiles(
        under root: URL,
        relativePrefix: String,
        tokens: [String],
        maxFileBytes: Int,
        into scored: inout [(URL, Int, String)]
    ) {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for case let url as URL in enumerator {
            let name = url.lastPathComponent
            if url.hasDirectoryPath {
                if skipDirNames.contains(name) || name.hasSuffix(".app") {
                    enumerator.skipDescendants()
                }
                continue
            }
            let ext = url.pathExtension.lowercased()
            guard sourceExtensions.contains(ext) else { continue }
            if name == "HYPER.NDX" || name.hasSuffix(".emit.log") { continue }

            let vals = try? url.resourceValues(forKeys: [.fileSizeKey])
            if let size = vals?.fileSize, size > maxFileBytes { continue }

            guard let data = try? Data(contentsOf: url),
                  let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
            else { continue }

            let score = scoreFile(text: text, tokens: tokens)
            guard score > 0 else { continue }
            var rel = url.path.replacingOccurrences(of: root.path + "/", with: "")
            if !relativePrefix.isEmpty {
                if rel.hasPrefix("Reference/") {
                    // already labeled
                } else {
                    rel = relativePrefix + rel
                }
            }
            scored.append((url, score, rel))
        }
    }

    // MARK: - Tokens / scoring

    static func significantTokens(in text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        for ch in text {
            if ch.unicodeScalars.allSatisfy({ wordChars.contains($0) }) {
                current.append(ch)
            } else if !current.isEmpty {
                considerToken(current, into: &tokens)
                current = ""
            }
        }
        if !current.isEmpty {
            considerToken(current, into: &tokens)
        }
        // Prefer longer / rarer-looking tokens first for scoring weight.
        let unique = Array(Set(tokens))
        return unique.sorted { a, b in
            if a.count != b.count { return a.count > b.count }
            return a < b
        }
    }

    private static let stopWords: Set<String> = [
        "the", "and", "for", "with", "from", "this", "that", "what", "how",
        "write", "forth", "word", "code", "please", "using", "into", "then",
        "when", "else", "true", "false", "null", "stack", "comment"
    ]

    private static func considerToken(_ raw: String, into tokens: inout [String]) {
        let t = raw.lowercased()
        guard t.count >= 2 else { return }
        if stopWords.contains(t) { return }
        // Pure digits are weak queries.
        if t.unicodeScalars.allSatisfy({ CharacterSet.decimalDigits.contains($0) }) { return }
        tokens.append(t)
    }

    private static func scoreFile(text: String, tokens: [String]) -> Int {
        let lower = text.lowercased()
        var score = 0
        for token in tokens {
            var searchFrom = lower.startIndex
            var hits = 0
            while let r = lower.range(of: token, range: searchFrom..<lower.endIndex) {
                hits += 1
                searchFrom = r.upperBound
                if hits >= 8 { break }
            }
            if hits == 0 { continue }
            // Longer tokens weigh more; definition-like ": token" bonus via crude check.
            let weight = max(1, token.count / 2)
            score += hits * weight
            if lower.contains(": \(token)") || lower.contains(": \(token)\n") {
                score += 10
            }
        }
        return score
    }

    private static func bestSnippet(
        in text: String,
        relativePath: String,
        tokens: [String],
        score: Int,
        contextLines: Int
    ) -> ForthLibrarySnippet? {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard !lines.isEmpty else { return nil }
        let lowerLines = lines.map { $0.lowercased() }

        var bestLine = 0
        var bestHits = 0
        for (i, line) in lowerLines.enumerated() {
            var hits = 0
            for token in tokens where line.contains(token) {
                hits += 1
            }
            if hits > bestHits {
                bestHits = hits
                bestLine = i
            }
        }
        guard bestHits > 0 else { return nil }

        let start = max(0, bestLine - contextLines)
        let end = min(lines.count - 1, bestLine + contextLines)
        let slice = lines[start...end].joined(separator: "\n")
        // Cap individual snippet size.
        // Per-snippet cap scales with context window; keep one excerpt bounded.
        let perSnippetCap = max(1200, contextLines * 120)
        let capped = String(slice.prefix(perSnippetCap))
        return ForthLibrarySnippet(
            relativePath: relativePath,
            startLine: start + 1,
            text: capped,
            score: score
        )
    }
}
