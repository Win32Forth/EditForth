//
//  OllamaClient.swift
//  EditForth
//
//  Local Ollama HTTP client (http://127.0.0.1:11434). First AI backend;
//  swap later for MLX behind LLMClient without changing the panel.
//

import Foundation

struct OllamaClient: LLMClient {
    var providerName: String { "Ollama" }

    /// Override for tests; default is the local daemon.
    var baseURL: URL

    init(baseURL: URL = URL(string: "http://127.0.0.1:11434")!) {
        self.baseURL = baseURL
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

    func complete(system: String, user: String, model: String) async throws -> String {
        var messages: [LLMChatMessage] = []
        let sys = system.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sys.isEmpty { messages.append(.system(sys)) }
        messages.append(.user(user))
        let msg = try await chat(
            messages: messages,
            tools: nil,
            model: model,
            stream: false,
            onDelta: { _ in }
        )
        let trimmed = msg.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw LLMClientError.emptyResponse }
        return trimmed
    }

    func completeStreaming(
        system: String,
        user: String,
        model: String,
        onDelta: @escaping @Sendable (String) async -> Void
    ) async throws -> String {
        var messages: [LLMChatMessage] = []
        let sys = system.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sys.isEmpty { messages.append(.system(sys)) }
        messages.append(.user(user))
        let msg = try await chat(
            messages: messages,
            tools: nil,
            model: model,
            stream: true,
            onDelta: onDelta
        )
        let trimmed = msg.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw LLMClientError.emptyResponse }
        return trimmed
    }

    func chat(
        messages: [LLMChatMessage],
        tools: [LLMToolDefinition]?,
        model: String,
        stream: Bool,
        onDelta: @escaping @Sendable (String) async -> Void
    ) async throws -> LLMChatMessage {
        let url = baseURL.appendingPathComponent("api/chat")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300

        var body: [String: Any] = [
            "model": model,
            "stream": stream,
            "messages": messages.map { encodeMessage($0) }
        ]
        if let tools, !tools.isEmpty {
            body["tools"] = tools.map { encodeTool($0) }
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        if stream {
            return try await readChatStream(request: request, onDelta: onDelta)
        }
        return try await readChatOnce(request: request, onDelta: onDelta)
    }

    private func encodeMessage(_ message: LLMChatMessage) -> [String: Any] {
        var dict: [String: Any] = [
            "role": message.role.rawValue,
            "content": message.content
        ]
        if let calls = message.toolCalls, !calls.isEmpty {
            dict["tool_calls"] = calls.map { call -> [String: Any] in
                var fn: [String: Any] = ["name": call.name]
                if let data = call.argumentsJSON.data(using: .utf8),
                   let obj = try? JSONSerialization.jsonObject(with: data) {
                    fn["arguments"] = obj
                } else if !call.argumentsJSON.isEmpty {
                    fn["arguments"] = call.argumentsJSON
                } else {
                    fn["arguments"] = [String: Any]()
                }
                var entry: [String: Any] = ["function": fn]
                if let id = call.id { entry["id"] = id }
                return entry
            }
        }
        if message.role == .tool {
            if let name = message.toolName { dict["name"] = name }
            if let id = message.toolCallID { dict["tool_call_id"] = id }
        }
        return dict
    }

    private func encodeTool(_ tool: LLMToolDefinition) -> [String: Any] {
        [
            "type": "function",
            "function": [
                "name": tool.name,
                "description": tool.description,
                "parameters": tool.parametersJSONSchema
            ] as [String: Any]
        ]
    }

    private func decodeMessage(from message: [String: Any]) -> LLMChatMessage {
        let roleRaw = (message["role"] as? String) ?? "assistant"
        let role = LLMChatMessage.Role(rawValue: roleRaw) ?? .assistant
        let content = (message["content"] as? String) ?? ""
        var toolCalls: [LLMToolCall]?
        if let rawCalls = message["tool_calls"] as? [[String: Any]], !rawCalls.isEmpty {
            toolCalls = rawCalls.compactMap { entry in
                let id = entry["id"] as? String
                let fn = entry["function"] as? [String: Any] ?? [:]
                let name = (fn["name"] as? String) ?? ""
                guard !name.isEmpty else { return nil }
                let argsJSON: String
                if let args = fn["arguments"] as? [String: Any],
                   let data = try? JSONSerialization.data(withJSONObject: args),
                   let s = String(data: data, encoding: .utf8) {
                    argsJSON = s
                } else if let s = fn["arguments"] as? String {
                    argsJSON = s
                } else {
                    argsJSON = "{}"
                }
                return LLMToolCall(id: id, name: name, argumentsJSON: argsJSON)
            }
        }
        return LLMChatMessage(
            role: role,
            content: content,
            toolCalls: toolCalls,
            toolName: message["name"] as? String,
            toolCallID: message["tool_call_id"] as? String
        )
    }

    private func readChatOnce(
        request: URLRequest,
        onDelta: @escaping @Sendable (String) async -> Void
    ) async throws -> LLMChatMessage {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw LLMClientError.unreachable(error.localizedDescription)
        }

        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200...299).contains(code) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw LLMClientError.badStatus(code, text)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMClientError.decoding("not JSON")
        }
        if let message = json["message"] as? [String: Any] {
            let decoded = decodeMessage(from: message)
            let hasTools = !(decoded.toolCalls ?? []).isEmpty
            let trimmed = decoded.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if !hasTools, trimmed.isEmpty {
                throw LLMClientError.emptyResponse
            }
            if !trimmed.isEmpty {
                await onDelta(trimmed)
            }
            return decoded
        }
        if let content = json["response"] as? String {
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { throw LLMClientError.emptyResponse }
            await onDelta(trimmed)
            return LLMChatMessage(role: .assistant, content: trimmed)
        }
        throw LLMClientError.decoding("missing message.content")
    }

    /// NDJSON stream from `/api/chat` with `stream: true`.
    private func readChatStream(
        request: URLRequest,
        onDelta: @escaping @Sendable (String) async -> Void
    ) async throws -> LLMChatMessage {
        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await URLSession.shared.bytes(for: request)
        } catch {
            throw LLMClientError.unreachable(error.localizedDescription)
        }

        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200...299).contains(code) else {
            var errBody = ""
            for try await line in bytes.lines {
                errBody += line
                if errBody.count > 400 { break }
            }
            throw LLMClientError.badStatus(code, errBody)
        }

        var assembled = ""
        var toolCalls: [LLMToolCall] = []
        var sawDone = false
        for try await line in bytes.lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { continue }
            guard let data = trimmedLine.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            if let message = json["message"] as? [String: Any] {
                if let piece = message["content"] as? String, !piece.isEmpty {
                    assembled += piece
                    await onDelta(piece)
                }
                if let rawCalls = message["tool_calls"] as? [[String: Any]], !rawCalls.isEmpty {
                    let decoded = decodeMessage(from: message)
                    if let calls = decoded.toolCalls {
                        toolCalls.append(contentsOf: calls)
                    }
                }
            } else if let piece = json["response"] as? String, !piece.isEmpty {
                assembled += piece
                await onDelta(piece)
            }
            if json["done"] as? Bool == true {
                sawDone = true
                break
            }
        }

        let trimmed = assembled.trimmingCharacters(in: .whitespacesAndNewlines)
        if toolCalls.isEmpty, trimmed.isEmpty {
            throw LLMClientError.emptyResponse
        }
        _ = sawDone
        return LLMChatMessage(
            role: .assistant,
            content: assembled,
            toolCalls: toolCalls.isEmpty ? nil : toolCalls
        )
    }
}
