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
            return "Cannot reach the language model (\(detail))."
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

// MARK: - Chat / tools

struct LLMToolCall: Sendable {
    var id: String?
    var name: String
    /// JSON object string of arguments (e.g. `{"query":"…"}`).
    var argumentsJSON: String
}

struct LLMToolDefinition: @unchecked Sendable {
    var name: String
    var description: String
    /// JSON Schema object for `parameters` (as Foundation dictionary).
    var parametersJSONSchema: [String: Any]

    init(name: String, description: String, parametersJSONSchema: [String: Any]) {
        self.name = name
        self.description = description
        self.parametersJSONSchema = parametersJSONSchema
    }
}

struct LLMChatMessage: Sendable {
    enum Role: String, Sendable {
        case system
        case user
        case assistant
        case tool
    }

    var role: Role
    var content: String
    var toolCalls: [LLMToolCall]?
    /// For `role == .tool`, the function name (Ollama).
    var toolName: String?
    /// For `role == .tool`, optional call id.
    var toolCallID: String?

    static func system(_ content: String) -> LLMChatMessage {
        LLMChatMessage(role: .system, content: content)
    }

    static func user(_ content: String) -> LLMChatMessage {
        LLMChatMessage(role: .user, content: content)
    }

    static func tool(name: String, content: String, toolCallID: String? = nil) -> LLMChatMessage {
        LLMChatMessage(role: .tool, content: content, toolName: name, toolCallID: toolCallID)
    }
}

protocol LLMClient: Sendable {
    /// Short label for Settings / status (e.g. "Ollama").
    var providerName: String { get }

    /// True when the local (or remote) endpoint answers.
    func ping() async -> Bool

    /// One-shot completion. `system` may be empty.
    func complete(system: String, user: String, model: String) async throws -> String

    /// Stream completion tokens. Each `onDelta` call receives the next text fragment
    /// (append to show a growing reply). Returns the full assembled reply.
    func completeStreaming(
        system: String,
        user: String,
        model: String,
        onDelta: @escaping @Sendable (String) async -> Void
    ) async throws -> String

    /// Multi-turn chat, optionally with tools. When `stream` is true and the final
    /// message has no tool calls, content deltas are forwarded to `onDelta`.
    func chat(
        messages: [LLMChatMessage],
        tools: [LLMToolDefinition]?,
        model: String,
        stream: Bool,
        onDelta: @escaping @Sendable (String) async -> Void
    ) async throws -> LLMChatMessage
}

extension LLMClient {
    /// Default: one-shot `complete`, then a single delta with the full text.
    func completeStreaming(
        system: String,
        user: String,
        model: String,
        onDelta: @escaping @Sendable (String) async -> Void
    ) async throws -> String {
        let text = try await complete(system: system, user: user, model: model)
        if !text.isEmpty {
            await onDelta(text)
        }
        return text
    }

    /// Default: no tool support — synthesize a single user turn via `complete` / stream.
    func chat(
        messages: [LLMChatMessage],
        tools: [LLMToolDefinition]?,
        model: String,
        stream: Bool,
        onDelta: @escaping @Sendable (String) async -> Void
    ) async throws -> LLMChatMessage {
        if let tools, !tools.isEmpty {
            throw LLMClientError.decoding("This model backend does not support tools")
        }
        var system = ""
        var user = ""
        for msg in messages {
            switch msg.role {
            case .system:
                if !system.isEmpty { system += "\n" }
                system += msg.content
            case .user, .tool:
                if !user.isEmpty { user += "\n\n" }
                user += msg.content
            case .assistant:
                break
            }
        }
        let text: String
        if stream {
            text = try await completeStreaming(system: system, user: user, model: model, onDelta: onDelta)
        } else {
            text = try await complete(system: system, user: user, model: model)
            if !text.isEmpty { await onDelta(text) }
        }
        return LLMChatMessage(role: .assistant, content: text)
    }
}
