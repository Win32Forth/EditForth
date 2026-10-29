//
//  ForthLibraryEmbedIndex.swift
//  EditForth
//
//  Chunk + embed Library Sample (or configured folder) and always
//  System/Reference (ANS Forth-2012 txt) via nomic-embed-text. On-disk index
//  under Application Support; incremental by file mtime/size.
//  Auto-rebuild when Library folder or file set drifts (ensureFresh).
//

import Foundation

/// Coalesces concurrent auto-rebuilds (MainActor — module default isolation).
@MainActor
enum ForthLibraryEmbedRefreshGate {
    static var inFlight: Task<ForthLibraryEmbedStore, Error>?
}

// MARK: - Stored types

struct ForthLibraryEmbedChunk: Codable, Sendable, Identifiable {
    var id: String
    var relativePath: String
    var absolutePath: String
    var startLine: Int
    var endLine: Int
    var text: String
    var embedding: [Float]
    var sourceMTime: TimeInterval
    var sourceSize: Int
}

struct ForthLibraryEmbedStore: Codable, Sendable {
    static let currentVersion = 1

    var version: Int
    var model: String
    var dimensions: Int
    var roots: [String]
    var builtAt: Date
    var chunks: [ForthLibraryEmbedChunk]

    var isEmpty: Bool { chunks.isEmpty }
}

struct ForthLibraryEmbedHit: Sendable {
    var chunk: ForthLibraryEmbedChunk
    var score: Float

    func asSnippet(scoreScale: Int = 1000) -> ForthLibrarySnippet {
        ForthLibrarySnippet(
            relativePath: chunk.relativePath,
            startLine: chunk.startLine,
            text: chunk.text,
            score: Int((score * Float(scoreScale)).rounded())
        )
    }
}

// MARK: - Index

enum ForthLibraryEmbedIndex {
    /// Soft cap so a huge project root does not explode the index in Phase 1.
    static let maxFileBytes = 500_000
    /// Target lines per chunk (ANS glossary entries stay mostly intact).
    static let chunkLines = 50
    /// Overlap so definitions split across boundaries still match.
    static let chunkOverlapLines = 10
    /// Max characters stored/embedded per chunk.
    static let chunkMaxChars = 4_000
    static let embedBatchSize = 16

    /// True while `ensureFresh` / `buildOrRefresh` is running for the shared gate.
    @MainActor
    static var isRefreshing: Bool { ForthLibraryEmbedRefreshGate.inFlight != nil }

    private static let indexFileName = "library-embed-v1.json"

    // MARK: Paths

    static func supportDirectoryURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("EditForth/AskForthEmbedIndex", isDirectory: true)
    }

    static func indexFileURL() -> URL {
        supportDirectoryURL().appendingPathComponent(indexFileName, isDirectory: false)
    }

    static func ensureSupportDirectory() throws {
        try FileManager.default.createDirectory(
            at: supportDirectoryURL(),
            withIntermediateDirectories: true
        )
    }

    // MARK: Load / save

    static func load() -> ForthLibraryEmbedStore? {
        let url = indexFileURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let store = try decoder.decode(ForthLibraryEmbedStore.self, from: data)
            guard store.version == ForthLibraryEmbedStore.currentVersion else { return nil }
            return store
        } catch {
            return nil
        }
    }

    static func save(_ store: ForthLibraryEmbedStore) throws {
        try ensureSupportDirectory()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(store)
        try data.write(to: indexFileURL(), options: .atomic)
    }

    // MARK: Roots (Sample/configured + always Reference)

    /// Primary Library folder plus Reference roots (same policy as keyword RAG).
    static func indexRoots(settings: ForthLibraryRAGSettings) -> [URL] {
        var roots: [URL] = []
        var seen = Set<String>()
        func add(_ url: URL?) {
            guard let url else { return }
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
                return
            }
            let std = url.standardizedFileURL
            let key = std.path
            if seen.contains(key) { return }
            seen.insert(key)
            roots.append(std)
        }

        if let primary = ForthLibraryRAG.resolveRoot(settings: settings) {
            add(primary)
            for ref in ForthLibraryRAG.referenceSearchRoots(primaryRoot: primary) {
                add(ref)
            }
        } else {
            // Fall back to user Documents Reference so ANS txt still indexes.
            add(ForthMenuSupport.userTreeURL.appendingPathComponent("System/Reference", isDirectory: true))
        }
        return roots
    }

    // MARK: Stale detection / auto-rebuild

    /// True when there is no index, roots differ from settings, the embedding model
    /// changed, or any source file was added/removed/modified (mtime/size).
    static func needsRefresh(
        settings: ForthLibraryRAGSettings,
        model: String = AskForthEmbeddingClient.defaultModel
    ) -> Bool {
        guard let store = load(), !store.isEmpty else { return true }
        if store.model != model { return true }

        let roots = indexRoots(settings: settings)
        let rootPaths = Set(roots.map(\.path))
        if Set(store.roots) != rootPaths { return true }

        // Only files that actually produce chunks. Empty / tiny sources (e.g. 0–31 byte
        // helpers) are walked by collectSourceFiles but skipped by makePendingChunks
        // (min ~40 chars) — comparing them here falsely kept the index “stale” forever.
        let files = collectSourceFiles(roots: roots).filter { fileYieldsChunks($0) }
        var indexedMeta: [String: (mtime: TimeInterval, size: Int)] = [:]
        for chunk in store.chunks {
            if let prior = indexedMeta[chunk.absolutePath] {
                // Same file should share one mtime/size across chunks.
                if prior.mtime != chunk.sourceMTime || prior.size != chunk.sourceSize {
                    return true
                }
            } else {
                indexedMeta[chunk.absolutePath] = (chunk.sourceMTime, chunk.sourceSize)
            }
        }

        let currentPaths = Set(files.map { $0.url.path })
        if currentPaths != Set(indexedMeta.keys) { return true }

        for file in files {
            guard let meta = indexedMeta[file.url.path],
                  meta.mtime == file.mtime,
                  meta.size == file.size
            else { return true }
        }
        return false
    }

    /// Incremental rebuild when stale; no-op when fresh. Concurrent callers share one task.
    @discardableResult
    static func ensureFresh(
        settings: ForthLibraryRAGSettings,
        client: AskForthEmbeddingClient,
        progress: (@Sendable (String) -> Void)? = nil
    ) async throws -> ForthLibraryEmbedStore {
        if let store = load(), !store.isEmpty,
           !needsRefresh(settings: settings, model: client.model) {
            return store
        }
        if let existing = ForthLibraryEmbedRefreshGate.inFlight {
            return try await existing.value
        }
        let task = Task { @MainActor in
            defer { ForthLibraryEmbedRefreshGate.inFlight = nil }
            progress?("Library index out of date — updating…")
            return try await buildOrRefresh(
                settings: settings,
                client: client,
                forceFullRebuild: false,
                progress: progress
            )
        }
        ForthLibraryEmbedRefreshGate.inFlight = task
        return try await task.value
    }

    // MARK: Build

    /// Build or refresh the on-disk index. Reuses embeddings when path+mtime+size match.
    @discardableResult
    static func buildOrRefresh(
        settings: ForthLibraryRAGSettings,
        client: AskForthEmbeddingClient,
        forceFullRebuild: Bool = false,
        progress: (@Sendable (String) -> Void)? = nil
    ) async throws -> ForthLibraryEmbedStore {
        let roots = indexRoots(settings: settings)
        guard !roots.isEmpty else {
            progress?("No Library roots found to index.")
            let empty = ForthLibraryEmbedStore(
                version: ForthLibraryEmbedStore.currentVersion,
                model: client.model,
                dimensions: 0,
                roots: [],
                builtAt: Date(),
                chunks: []
            )
            try save(empty)
            return empty
        }

        progress?("Scanning Library…")
        let files = collectSourceFiles(roots: roots)
        progress?("Found \(files.count) source file(s).")

        let previous: ForthLibraryEmbedStore? = forceFullRebuild ? nil : load()
        let modelChanged = previous.map { $0.model != client.model } ?? true

        var reused: [ForthLibraryEmbedChunk] = []
        var toEmbed: [(file: SourceFile, chunks: [PendingChunk])] = []

        for file in files {
            let existing = (previous?.chunks ?? []).filter {
                $0.absolutePath == file.url.path
                    && $0.sourceMTime == file.mtime
                    && $0.sourceSize == file.size
                    && !modelChanged
            }
            if !existing.isEmpty {
                reused.append(contentsOf: existing)
                continue
            }
            guard let text = readText(url: file.url) else { continue }
            let pending = makePendingChunks(file: file, text: text)
            if !pending.isEmpty {
                toEmbed.append((file, pending))
            }
        }

        progress?("Reusing \(reused.count) chunk(s); embedding \(toEmbed.reduce(0) { $0 + $1.chunks.count }) new…")

        var fresh: [ForthLibraryEmbedChunk] = []
        var dimensions = previous?.dimensions ?? 0
        if !modelChanged, let previous, previous.dimensions > 0 {
            dimensions = previous.dimensions
        }

        for (fileIndex, item) in toEmbed.enumerated() {
            let (file, pending) = item
            progress?("Embedding \(file.relativePath) (\(fileIndex + 1)/\(toEmbed.count))…")
            let inputs = pending.map { AskForthEmbeddingClient.documentText($0.text) }
            let vectors = try await client.embed(texts: inputs, batchSize: embedBatchSize)
            guard vectors.count == pending.count else {
                throw AskForthEmbeddingError.decoding(
                    "embed count \(vectors.count) != chunks \(pending.count) for \(file.relativePath)"
                )
            }
            if let dim = vectors.first?.count {
                if dimensions == 0 {
                    dimensions = dim
                } else if dimensions != dim {
                    throw AskForthEmbeddingError.dimensionMismatch(expected: dimensions, got: dim)
                }
            }
            for (chunk, vector) in zip(pending, vectors) {
                fresh.append(
                    ForthLibraryEmbedChunk(
                        id: chunk.id,
                        relativePath: file.relativePath,
                        absolutePath: file.url.path,
                        startLine: chunk.startLine,
                        endLine: chunk.endLine,
                        text: chunk.text,
                        embedding: vector,
                        sourceMTime: file.mtime,
                        sourceSize: file.size
                    )
                )
            }
        }

        var all = reused + fresh
        all.sort { lhs, rhs in
            if lhs.relativePath != rhs.relativePath { return lhs.relativePath < rhs.relativePath }
            return lhs.startLine < rhs.startLine
        }

        let store = ForthLibraryEmbedStore(
            version: ForthLibraryEmbedStore.currentVersion,
            model: client.model,
            dimensions: dimensions,
            roots: roots.map(\.path),
            builtAt: Date(),
            chunks: all
        )
        try save(store)
        // Intentionally no user-facing “Indexed / ready” progress — Ask Forth banner
        // should only show while building, then clear.
        progress?("")
        return store
    }

    // MARK: Search (Phase 1 API; Ask wiring in Phase 2)

    static func search(
        query: String,
        store: ForthLibraryEmbedStore,
        client: AskForthEmbeddingClient = AskForthEmbeddingClient(),
        topK: Int = 12
    ) async throws -> [ForthLibraryEmbedHit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !store.chunks.isEmpty else { return [] }
        let vector = try await client.embed(AskForthEmbeddingClient.queryText(trimmed))
        if store.dimensions > 0, vector.count != store.dimensions {
            throw AskForthEmbeddingError.dimensionMismatch(expected: store.dimensions, got: vector.count)
        }

        var hits: [ForthLibraryEmbedHit] = []
        hits.reserveCapacity(store.chunks.count)
        for chunk in store.chunks {
            let score = AskForthEmbeddingMath.cosineSimilarity(vector, chunk.embedding)
            hits.append(ForthLibraryEmbedHit(chunk: chunk, score: score))
        }
        hits.sort { $0.score > $1.score }
        let k = max(1, topK)
        return Array(hits.prefix(k))
    }

    /// Convenience: load index (building if missing), search, map to Library snippets.
    static func retrieveSnippets(
        for query: String,
        settings: ForthLibraryRAGSettings,
        client: AskForthEmbeddingClient,
        topK: Int? = nil,
        buildIfMissing: Bool = true,
        progress: (@Sendable (String) -> Void)? = nil
    ) async throws -> ForthLibraryRAGResult {
        var store = load()
        if store == nil || store?.isEmpty == true {
            guard buildIfMissing else {
                return ForthLibraryRAGResult(snippets: [], rootPath: "", queryTokens: [])
            }
            store = try await buildOrRefresh(settings: settings, client: client, progress: progress)
        }
        guard let store else {
            return ForthLibraryRAGResult(snippets: [], rootPath: "", queryTokens: [])
        }
        let k = topK ?? settings.maxSnippets
        let hits = try await search(query: query, store: store, client: client, topK: k)
        let snippets = hits.map { $0.asSnippet() }
        let rootLabel = store.roots.joined(separator: " + ")
        return ForthLibraryRAGResult(
            snippets: snippets,
            rootPath: rootLabel.isEmpty ? "embed-index" : rootLabel,
            queryTokens: ForthLibraryRAG.significantTokens(in: query),
            retrieveModeLabel: "embed"
        )
    }

    // MARK: File walk / chunk

    private struct SourceFile {
        var url: URL
        var relativePath: String
        var mtime: TimeInterval
        var size: Int
    }

    private struct PendingChunk {
        var id: String
        var startLine: Int
        var endLine: Int
        var text: String
    }

    private static func collectSourceFiles(roots: [URL]) -> [SourceFile] {
        var out: [SourceFile] = []
        var seen = Set<String>()
        for root in roots {
            let isReferenceRoot = root.lastPathComponent == "Reference"
            let prefix = isReferenceRoot ? "Reference/" : ""
            collectFiles(under: root, relativePrefix: prefix, into: &out, seen: &seen)
        }
        out.sort { $0.relativePath < $1.relativePath }
        return out
    }

    private static func collectFiles(
        under root: URL,
        relativePrefix: String,
        into out: inout [SourceFile],
        seen: inout Set<String>
    ) {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        // Mirror ForthLibraryRAG skip / extension policy via shared helpers on that type.
        for case let url as URL in enumerator {
            let name = url.lastPathComponent
            if url.hasDirectoryPath {
                if ForthLibraryRAG.shouldSkipDirectory(named: name) {
                    enumerator.skipDescendants()
                }
                continue
            }
            guard ForthLibraryRAG.isIndexableSource(url: url) else { continue }

            let key = url.standardizedFileURL.path
            if seen.contains(key) { continue }
            seen.insert(key)

            let vals = try? url.resourceValues(forKeys: [
                .fileSizeKey, .contentModificationDateKey
            ])
            let size = vals?.fileSize ?? 0
            if size > maxFileBytes { continue }
            let mtime = vals?.contentModificationDate?.timeIntervalSince1970 ?? 0

            var rel = url.path.replacingOccurrences(of: root.path + "/", with: "")
            if !relativePrefix.isEmpty, !rel.hasPrefix("Reference/") {
                rel = relativePrefix + rel
            }
            out.append(SourceFile(url: url.standardizedFileURL, relativePath: rel, mtime: mtime, size: size))
        }
    }

    private static func readText(url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
    }

    /// True when indexing would emit at least one chunk (matches `makePendingChunks` threshold).
    private static func fileYieldsChunks(_ file: SourceFile) -> Bool {
        // Cheap reject for empty / tiny helpers that can never meet the chunk floor.
        if file.size > 0, file.size < 40 { return false }
        if file.size == 0 { return false }
        guard let text = readText(url: file.url) else { return false }
        return !makePendingChunks(file: file, text: text).isEmpty
    }

    private static func makePendingChunks(file: SourceFile, text: String) -> [PendingChunk] {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard !lines.isEmpty else { return [] }

        let step = max(1, chunkLines - chunkOverlapLines)
        var chunks: [PendingChunk] = []
        var start = 0
        while start < lines.count {
            let end = min(lines.count, start + chunkLines)
            let slice = Array(lines[start..<end])
            let body = slice.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if body.count >= 40 {
                let capped = String(body.prefix(chunkMaxChars))
                let startLine = start + 1
                let endLine = end
                let id = chunkID(
                    path: file.url.path,
                    startLine: startLine,
                    endLine: endLine,
                    mtime: file.mtime,
                    size: file.size
                )
                chunks.append(PendingChunk(id: id, startLine: startLine, endLine: endLine, text: capped))
            }
            if end >= lines.count { break }
            start += step
        }
        return chunks
    }

    private static func chunkID(path: String, startLine: Int, endLine: Int, mtime: TimeInterval, size: Int) -> String {
        // Stable across process launches (unlike `hashValue`).
        let raw = "\(path)|\(startLine)|\(endLine)|\(Int(mtime))|\(size)"
        var hash: UInt64 = 5381
        for byte in raw.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        return String(hash, radix: 16)
    }
}

// MARK: - Shared walk helpers on keyword RAG

extension ForthLibraryRAG {
    /// Directory names skipped when walking Library / project trees.
    static func shouldSkipDirectory(named name: String) -> Bool {
        skipDirNames.contains(name) || name.hasSuffix(".app")
    }

    static func isIndexableSource(url: URL) -> Bool {
        let name = url.lastPathComponent
        if name == "HYPER.NDX" || name.hasSuffix(".emit.log") { return false }
        // Skip URL map JSON; keep ANS *.txt glossary chapters.
        if name == "Forth-2012-word-urls.json" { return false }
        let ext = url.pathExtension.lowercased()
        return sourceExtensions.contains(ext)
    }
}
