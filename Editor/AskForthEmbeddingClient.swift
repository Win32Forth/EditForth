//
//  AskForthEmbeddingClient.swift
//  EditForth
//
//  Ollama /api/embed client for Library semantic RAG (nomic-embed-text).
//  Separate from chat LLMClient — embeddings stay on local Ollama even when
//  Ask Forth chat uses SpaceXAI or mlx :1234.
//

import Foundation

enum AskForthEmbeddingError: LocalizedError {
    case unreachable(String)
    case badStatus(Int, String)
    case emptyEmbeddings
    case dimensionMismatch(expected: Int, got: Int)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .unreachable(let detail):
            return "Cannot reach Ollama for embeddings (\(detail))."
        case .badStatus(let code, let body):
            let snippet = body.trimmingCharacters(in: .whitespacesAndNewlines)
            let short = snippet.isEmpty ? "" : ": \(String(snippet.prefix(180)))"
            return "Embedding request failed (HTTP \(code))\(short)"
        case .emptyEmbeddings:
            return "The embedding model returned no vectors."
        case .dimensionMismatch(let expected, let got):
            return "Embedding dimension mismatch (expected \(expected), got \(got))."
        case .decoding(let detail):
            return "Could not read embedding reply (\(detail))."
        }
    }
}

/// Local Ollama embedding HTTP client (`POST /api/embed`).
struct AskForthEmbeddingClient: Sendable {
    /// Default model: Nomic text embeddings (~274 MB, 768-d).
    static let defaultModel = "nomic-embed-text"

    var baseURL: URL
    var model: String

    init(
        baseURL: URL = URL(string: "http://127.0.0.1:11434")!,
        model: String = AskForthEmbeddingClient.defaultModel
    ) {
        self.baseURL = baseURL
        self.model = model
    }

    /// Nomic document prefix for indexed chunks.
    static func documentText(_ body: String) -> String {
        "search_document: \(body)"
    }

    /// Nomic query prefix for Ask prompts.
    static func queryText(_ body: String) -> String {
        "search_query: \(body)"
    }

    func ping() async -> Bool {
        let url = baseURL.appendingPathComponent("api/tags")
        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    /// True when `model` appears in `/api/tags` (exact or `name:` / `name:tag` prefix).
    func hasModel() async -> Bool {
        let url = baseURL.appendingPathComponent("api/tags")
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return false }
            guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let models = obj["models"] as? [[String: Any]]
            else { return false }
            let want = model.lowercased()
            return models.contains { entry in
                guard let name = (entry["name"] as? String)?.lowercased() else { return false }
                if name == want { return true }
                // `nomic-embed-text` matches `nomic-embed-text:latest`
                if name.hasPrefix(want + ":") { return true }
                if want.hasPrefix(name + ":") { return true }
                return false
            }
        } catch {
            return false
        }
    }

    /// Embed one string (already prefixed if using Nomic helpers).
    func embed(_ text: String) async throws -> [Float] {
        let vectors = try await embed(texts: [text])
        guard let first = vectors.first else { throw AskForthEmbeddingError.emptyEmbeddings }
        return first
    }

    /// Embed many strings in one or more `/api/embed` calls.
    func embed(texts: [String], batchSize: Int = 32) async throws -> [[Float]] {
        guard !texts.isEmpty else { return [] }
        let size = max(1, batchSize)
        var out: [[Float]] = []
        out.reserveCapacity(texts.count)
        var expectedDim: Int?
        var i = 0
        while i < texts.count {
            let end = min(i + size, texts.count)
            let batch = Array(texts[i..<end])
            let vectors = try await embedBatch(batch)
            if let dim = vectors.first?.count {
                if let expectedDim, expectedDim != dim {
                    throw AskForthEmbeddingError.dimensionMismatch(expected: expectedDim, got: dim)
                }
                expectedDim = dim
            }
            out.append(contentsOf: vectors)
            i = end
        }
        return out
    }

    private func embedBatch(_ texts: [String]) async throws -> [[Float]] {
        let url = baseURL.appendingPathComponent("api/embed")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let body: [String: Any] = [
            "model": model,
            "input": texts.count == 1 ? texts[0] : texts
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AskForthEmbeddingError.unreachable(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw AskForthEmbeddingError.unreachable("no HTTP response")
        }
        guard (200...299).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw AskForthEmbeddingError.badStatus(http.statusCode, bodyText)
        }

        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AskForthEmbeddingError.decoding("root not an object")
        }

        // Ollama `/api/embed` → `embeddings: [[number]]`
        if let embeddings = obj["embeddings"] as? [[Any]] {
            let vectors = try embeddings.map { try Self.floatVector(from: $0) }
            if vectors.isEmpty { throw AskForthEmbeddingError.emptyEmbeddings }
            return vectors
        }
        // Older `/api/embeddings`-style single vector under `embedding`
        if let embedding = obj["embedding"] as? [Any] {
            return [try Self.floatVector(from: embedding)]
        }
        throw AskForthEmbeddingError.decoding("missing embeddings array")
    }

    private static func floatVector(from raw: [Any]) throws -> [Float] {
        var out: [Float] = []
        out.reserveCapacity(raw.count)
        for item in raw {
            if let f = item as? Float {
                out.append(f)
            } else if let d = item as? Double {
                out.append(Float(d))
            } else if let n = item as? NSNumber {
                out.append(n.floatValue)
            } else {
                throw AskForthEmbeddingError.decoding("non-numeric embedding component")
            }
        }
        if out.isEmpty { throw AskForthEmbeddingError.emptyEmbeddings }
        return out
    }
}

// MARK: - Vector math

enum AskForthEmbeddingMath {
    static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Float = 0
        var na: Float = 0
        var nb: Float = 0
        for i in 0..<a.count {
            let x = a[i]
            let y = b[i]
            dot += x * y
            na += x * x
            nb += y * y
        }
        let denom = sqrt(na) * sqrt(nb)
        guard denom > 0 else { return 0 }
        return dot / denom
    }
}
