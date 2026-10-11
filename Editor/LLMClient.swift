//
//  LLMClient.swift
//  EditForth
//
//  Thin backend seam for local (Ollama) or later MLX / SpaceXAI providers.
//  UI talks only to this protocol — never to a concrete HTTP host.
//

import Foundation

enum LLMClientError: LocalizedError {
    case unreachable(String)
    case badStatus(Int, String)
    case emptyResponse
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .unreachable(let detail):
            return "Cannot reach the language model (\(detail)). Is Ollama running?"
        case .badStatus(let code, let body):
            let snippet = body.trimmingCharacters(in: .whitespacesAndNewlines)
            let short = snippet.isEmpty ? "" : ": \(String(snippet.prefix(180)))"
            return "Model request failed (HTTP \(code))\(short)"
        case .emptyResponse:
            return "The model returned an empty reply."
        case .decoding(let detail):
            return "Could not read the model reply (\(detail))."
        }
    }
}

protocol LLMClient: Sendable {
    /// Short label for Settings / status (e.g. "Ollama").
    var providerName: String { get }

    /// True when the local (or remote) endpoint answers.
    func ping() async -> Bool

    /// One-shot completion. `system` may be empty.
    func complete(system: String, user: String, model: String) async throws -> String
}
