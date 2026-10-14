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
    /// `keyword`, `embed`, `hybrid`, or a fallback note such as `keyword (no embed index)`.
    var retrieveModeLabel: String

    init(
        snippets: [ForthLibrarySnippet],
        rootPath: String,
        queryTokens: [String],
        retrieveModeLabel: String = "keyword"
    ) {
        self.snippets = snippets
        self.rootPath = rootPath
        self.queryTokens = queryTokens
        self.retrieveModeLabel = retrieveModeLabel
    }

    var isEmpty: Bool { snippets.isEmpty }

    /// Block to append to the model user message.
    func contextBlock(maxChars: Int) -> String {
        guard !snippets.isEmpty else { return "" }
        var out = "Library context (excerpts from \(rootPath); \(retrieveModeLabel)). Treat as authoritative for word names and stack effects; answer from these excerpts when possible:\n"
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
    /// Shared with `ForthLibraryEmbedIndex` walk.
    static let skipDirNames: Set<String> = [
        ".git", "DerivedData", "PI", "VED64", "__pycache__",
        // EditForth / Xcode project trees (safe to point Library… at the repo root)
        "finetune", "Build", "build", ".build", "xcuserdata",
        "Pods", "node_modules", "models", "adapters", "fused_model",
    ]
    static let sourceExtensions: Set<String> = [
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
            queryTokens: tokens,
            retrieveModeLabel: "keyword"
        )
    }

    /// Keyword, semantic, or hybrid retrieve according to `settings.retrieveMode`.
    /// Semantic/hybrid auto-refresh the embed index when the Library folder or files drift;
    /// fall back to keyword if the index is missing or embed fails.
    static func retrieveAsync(
        for query: String,
        settings: ForthLibraryRAGSettings = .load(),
        embedClient: AskForthEmbeddingClient = AskForthEmbeddingClient(),
        embedProgress: (@Sendable (String) -> Void)? = nil
    ) async -> ForthLibraryRAGResult {
        switch settings.retrieveMode {
        case .keyword:
            return retrieve(for: query, settings: settings)
        case .semantic:
            await autoRefreshEmbedIndexIfNeeded(
                settings: settings,
                embedClient: embedClient,
                progress: embedProgress
            )
            return await retrieveSemantic(
                for: query,
                settings: settings,
                embedClient: embedClient,
                fallbackToKeyword: true
            )
        case .hybrid:
            await autoRefreshEmbedIndexIfNeeded(
                settings: settings,
                embedClient: embedClient,
                progress: embedProgress
            )
            return await retrieveHybrid(
                for: query,
                settings: settings,
                embedClient: embedClient
            )
        }
    }

    private static func autoRefreshEmbedIndexIfNeeded(
        settings: ForthLibraryRAGSettings,
        embedClient: AskForthEmbeddingClient,
        progress: (@Sendable (String) -> Void)?
    ) async {
        guard ForthLibraryEmbedIndex.needsRefresh(settings: settings, model: embedClient.model) else {
            return
        }
        do {
            _ = try await ForthLibraryEmbedIndex.ensureFresh(
                settings: settings,
                client: embedClient,
                progress: progress
            )
        } catch {
            progress?("Library index update failed — using keyword if needed.")
        }
    }

    private static func retrieveSemantic(
        for query: String,
        settings: ForthLibraryRAGSettings,
        embedClient: AskForthEmbeddingClient,
        fallbackToKeyword: Bool
    ) async -> ForthLibraryRAGResult {
        guard let store = ForthLibraryEmbedIndex.load(), !store.isEmpty else {
            if fallbackToKeyword {
                var kw = retrieve(for: query, settings: settings)
                kw.retrieveModeLabel = "keyword (no embed index)"
                return kw
            }
            return ForthLibraryRAGResult(
                snippets: [],
                rootPath: "",
                queryTokens: significantTokens(in: query),
                retrieveModeLabel: "embed (no index)"
            )
        }
        do {
            let hits = try await ForthLibraryEmbedIndex.search(
                query: query,
                store: store,
                client: embedClient,
                topK: settings.maxSnippets
            )
            let snippets = hits.map { $0.asSnippet() }
            let rootLabel = store.roots.joined(separator: " + ")
            return ForthLibraryRAGResult(
                snippets: snippets,
                rootPath: rootLabel.isEmpty ? "embed-index" : rootLabel,
                queryTokens: significantTokens(in: query),
                retrieveModeLabel: "embed"
            )
        } catch {
            if fallbackToKeyword {
                var kw = retrieve(for: query, settings: settings)
                kw.retrieveModeLabel = "keyword (embed failed)"
                return kw
            }
            return ForthLibraryRAGResult(
                snippets: [],
                rootPath: "",
                queryTokens: significantTokens(in: query),
                retrieveModeLabel: "embed (failed)"
            )
        }
    }

    private static func retrieveHybrid(
        for query: String,
        settings: ForthLibraryRAGSettings,
        embedClient: AskForthEmbeddingClient
    ) async -> ForthLibraryRAGResult {
        let keyword = retrieve(for: query, settings: settings)
        guard let store = ForthLibraryEmbedIndex.load(), !store.isEmpty else {
            var kw = keyword
            kw.retrieveModeLabel = "keyword (no embed index)"
            return kw
        }

        let embedHits: [ForthLibraryEmbedHit]
        do {
            embedHits = try await ForthLibraryEmbedIndex.search(
                query: query,
                store: store,
                client: embedClient,
                topK: max(settings.maxSnippets * 2, 16)
            )
        } catch {
            var kw = keyword
            kw.retrieveModeLabel = "keyword (embed failed)"
            return kw
        }

        let merged = mergeHybrid(
            keyword: keyword.snippets,
            embedHits: embedHits,
            maxSnippets: settings.maxSnippets
        )
        let rootLabel: String
        if keyword.rootPath.isEmpty {
            rootLabel = store.roots.joined(separator: " + ")
        } else if store.roots.isEmpty {
            rootLabel = keyword.rootPath
        } else {
            rootLabel = keyword.rootPath
        }
        return ForthLibraryRAGResult(
            snippets: merged,
            rootPath: rootLabel,
            queryTokens: keyword.queryTokens,
            retrieveModeLabel: "hybrid"
        )
    }

    /// Blend cosine (0…1) with normalized keyword scores. Prefers entries with both signals.
    private static func mergeHybrid(
        keyword: [ForthLibrarySnippet],
        embedHits: [ForthLibraryEmbedHit],
        maxSnippets: Int
    ) -> [ForthLibrarySnippet] {
        struct Acc {
            var path: String
            var startLine: Int
            var text: String
            var embed: Float
            var keyword: Float
        }

        let maxKW = Float(keyword.map(\.score).max() ?? 0)
        var byKey: [String: Acc] = [:]

        func key(_ path: String, _ start: Int) -> String {
            // Bucket nearby line windows so keyword ±context and embed chunks can merge.
            let bucket = (max(1, start) / 40) * 40
            return "\(path)#\(bucket)"
        }

        for snip in keyword {
            let k = key(snip.relativePath, snip.startLine)
            let kn = maxKW > 0 ? Float(snip.score) / maxKW : 0
            if var existing = byKey[k] {
                existing.keyword = max(existing.keyword, kn)
                if snip.text.count > existing.text.count {
                    existing.text = snip.text
                    existing.startLine = snip.startLine
                }
                byKey[k] = existing
            } else {
                byKey[k] = Acc(
                    path: snip.relativePath,
                    startLine: snip.startLine,
                    text: snip.text,
                    embed: 0,
                    keyword: kn
                )
            }
        }

        for hit in embedHits {
            let snip = hit.asSnippet()
            let k = key(snip.relativePath, snip.startLine)
            if var existing = byKey[k] {
                existing.embed = max(existing.embed, hit.score)
                if snip.text.count > existing.text.count {
                    existing.text = snip.text
                    existing.startLine = snip.startLine
                }
                byKey[k] = existing
            } else {
                byKey[k] = Acc(
                    path: snip.relativePath,
                    startLine: snip.startLine,
                    text: snip.text,
                    embed: hit.score,
                    keyword: 0
                )
            }
        }

        let alpha: Float = 0.65  // embed
        let beta: Float = 0.35   // keyword
        var ranked: [(Float, Acc)] = []
        ranked.reserveCapacity(byKey.count)
        for acc in byKey.values {
            let final: Float
            if acc.embed > 0, acc.keyword > 0 {
                final = alpha * acc.embed + beta * acc.keyword
            } else if acc.embed > 0 {
                final = acc.embed
            } else {
                final = acc.keyword
            }
            ranked.append((final, acc))
        }
        ranked.sort { lhs, rhs in
            if lhs.0 != rhs.0 { return lhs.0 > rhs.0 }
            return lhs.1.path < rhs.1.path
        }

        return ranked.prefix(maxSnippets).map { score, acc in
            ForthLibrarySnippet(
                relativePath: acc.path,
                startLine: acc.startLine,
                text: acc.text,
                score: Int((score * 1000).rounded())
            )
        }
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
                if shouldSkipDirectory(named: name) {
                    enumerator.skipDescendants()
                }
                continue
            }
            guard isIndexableSource(url: url) else { continue }

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
