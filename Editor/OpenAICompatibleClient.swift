//
//  OpenAICompatibleClient.swift
//  EditForth
//
//  OpenAI-compatible HTTP chat client (SpaceXAI / xAI default: api.x.ai/v1).
//  Implements LLMClient for Ask Forth beside OllamaClient.
//

import Foundation

struct OpenAICompatibleClient: LLMClient {
    var providerName: String { "OpenAI-compat" }

    var baseURL: URL
    /// Called per request so Keychain / env updates apply without rebuilding the client.
    var apiKeyProvider: @Sendable () -> String?
    /// Sampling temperature (`temperature` field on chat/completions).
    var temperature: Double

    init(
        baseURL: URL = URL(string: AskForthLLMSettings.defaultOpenAIBaseURL)!,
        apiKeyProvider: @escaping @Sendable () -> String? = { AskForthLLMSettings.resolveAPIKey() },
        temperature: Double = AskForthLLMSettings.defaultTemperature
    ) {
        self.baseURL = baseURL
        self.apiKeyProvider = apiKeyProvider
        self.temperature = AskForthLLMSettings.clampTemperature(temperature)
    }

    func ping() async -> Bool {
        // Transport check only. Auth failures (401/400) still mean the host is reachable;
        // the real Ask call surfaces those with the API’s error text.
        guard let key = apiKeyProvider(), !key.isEmpty else { return false }
        let url = modelsURL()
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            // Any HTTP response counts as reachable (including 401 Incorrect API key).
            return response is HTTPURLResponse
        } catch {
            return false
        }
    }

    private func modelsURL() -> URL {
        var base = baseURL.absoluteString
        while base.hasSuffix("/") { base.removeLast() }
        if base.hasSuffix("/models") {
            return URL(string: base)!
        }
        return URL(string: base + "/models")!
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
        guard let key = apiKeyProvider(), !key.isEmpty else {
            throw LLMClientError.unreachable("no API key — set one in Ask Forth or export XAI_API_KEY")
        }

        let url = chatCompletionsURL()
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 600

        var body: [String: Any] = [
            "model": model,
            "stream": stream,
            "messages": messages.map { encodeMessage($0) },
            // mlx_lm / LM Studio often default to a short cap; raise for full Forth listings.
            "max_tokens": LLMGenerationLimits.maxCompletionTokens,
            "temperature": temperature
        ]
        if let tools, !tools.isEmpty {
            body["tools"] = tools.map { encodeTool($0) }
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        if stream {
            return try await readSSEStream(request: request, onDelta: onDelta)
        }
        return try await readOnce(request: request, onDelta: onDelta)
    }

    // MARK: - URL / encode

    private func chatCompletionsURL() -> URL {
        var base = baseURL.absoluteString
        while base.hasSuffix("/") { base.removeLast() }
        if base.hasSuffix("/chat/completions") {
            return URL(string: base)!
        }
        return URL(string: base + "/chat/completions")!
    }

    private func encodeMessage(_ message: LLMChatMessage) -> [String: Any] {
        var dict: [String: Any] = [
            "role": message.role.rawValue
        ]
        if message.role == .assistant, let calls = message.toolCalls, !calls.isEmpty {
            // OpenAI allows null content when tool_calls are present.
            if message.content.isEmpty {
                dict["content"] = NSNull()
            } else {
                dict["content"] = message.content
            }
            dict["tool_calls"] = calls.map { call -> [String: Any] in
                var entry: [String: Any] = [
                    "type": "function",
                    "function": [
                        "name": call.name,
                        "arguments": call.argumentsJSON.isEmpty ? "{}" : call.argumentsJSON
                    ] as [String: Any]
                ]
                if let id = call.id {
                    entry["id"] = id
                } else {
                    entry["id"] = "call_\(call.name)"
                }
                return entry
            }
        } else {
            dict["content"] = message.content
        }
        if message.role == .tool {
            if let id = message.toolCallID {
                dict["tool_call_id"] = id
            } else if let name = message.toolName {
                dict["tool_call_id"] = "call_\(name)"
            }
            // Some servers also want name on tool messages.
            if let name = message.toolName {
                dict["name"] = name
            }
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

    private func decodeAssistantMessage(from message: [String: Any]) -> LLMChatMessage {
        let content = message["content"] as? String ?? ""
        var toolCalls: [LLMToolCall]?
        if let rawCalls = message["tool_calls"] as? [[String: Any]], !rawCalls.isEmpty {
            toolCalls = rawCalls.compactMap { entry in
                let id = entry["id"] as? String
                let fn = entry["function"] as? [String: Any] ?? [:]
                let name = (fn["name"] as? String) ?? ""
                guard !name.isEmpty else { return nil }
                let argsJSON: String
                if let s = fn["arguments"] as? String {
                    argsJSON = s
                } else if let obj = fn["arguments"] as? [String: Any],
                          let data = try? JSONSerialization.data(withJSONObject: obj),
                          let s = String(data: data, encoding: .utf8) {
                    argsJSON = s
                } else {
                    argsJSON = "{}"
                }
                return LLMToolCall(id: id, name: name, argumentsJSON: argsJSON)
            }
        }
        return LLMChatMessage(role: .assistant, content: content, toolCalls: toolCalls)
    }

    // MARK: - Non-stream

    private func readOnce(
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
        let text = String(data: data, encoding: .utf8) ?? ""
        guard (200...299).contains(code) else {
            throw LLMClientError.badStatus(code, Self.apiErrorSummary(from: data, fallback: text))
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMClientError.decoding("not JSON")
        }
        if let error = json["error"] as? [String: Any] {
            let msg = (error["message"] as? String)
                ?? (error["error"] as? String)
                ?? "API error"
            throw LLMClientError.badStatus(code, msg)
        }
        if let errStr = json["error"] as? String {
            throw LLMClientError.badStatus(code, errStr)
        }
        guard let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any] else {
            throw LLMClientError.decoding("missing choices[0].message")
        }
        let decoded = decodeAssistantMessage(from: message)
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

    // MARK: - SSE stream

    private func readSSEStream(
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
        // Accumulate streamed tool call fragments by index.
        var toolAcc: [Int: (id: String?, name: String, args: String)] = [:]

        for try await line in bytes.lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedLine.hasPrefix("data:") else { continue }
            let payload = trimmedLine.dropFirst(5).trimmingCharacters(in: .whitespacesAndNewlines)
            if payload == "[DONE]" { break }
            guard let data = payload.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            if let error = json["error"] as? [String: Any] {
                let msg = (error["message"] as? String) ?? "stream error"
                throw LLMClientError.decoding(msg)
            }
            guard let choices = json["choices"] as? [[String: Any]],
                  let first = choices.first else { continue }
            if let delta = first["delta"] as? [String: Any] {
                if let piece = delta["content"] as? String, !piece.isEmpty {
                    assembled += piece
                    await onDelta(piece)
                }
                if let calls = delta["tool_calls"] as? [[String: Any]] {
                    for call in calls {
                        let idx = call["index"] as? Int ?? 0
                        var cur = toolAcc[idx] ?? (id: nil, name: "", args: "")
                        if let id = call["id"] as? String { cur.id = id }
                        if let fn = call["function"] as? [String: Any] {
                            if let name = fn["name"] as? String, !name.isEmpty {
                                cur.name += name
                            }
                            if let args = fn["arguments"] as? String {
                                cur.args += args
                            }
                        }
                        toolAcc[idx] = cur
                    }
                }
            }
        }

        var toolCalls: [LLMToolCall]?
        if !toolAcc.isEmpty {
            toolCalls = toolAcc.keys.sorted().compactMap { idx in
                guard let cur = toolAcc[idx], !cur.name.isEmpty else { return nil }
                return LLMToolCall(id: cur.id, name: cur.name, argumentsJSON: cur.args.isEmpty ? "{}" : cur.args)
            }
        }

        let trimmed = assembled.trimmingCharacters(in: .whitespacesAndNewlines)
        if (toolCalls ?? []).isEmpty, trimmed.isEmpty {
            throw LLMClientError.emptyResponse
        }
        return LLMChatMessage(role: .assistant, content: assembled, toolCalls: toolCalls)
    }

    /// Prefer xAI / OpenAI JSON error fields over a raw body dump.
    private static func apiErrorSummary(from data: Data, fallback: String) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let error = json["error"] as? [String: Any] {
                if let msg = error["message"] as? String, !msg.isEmpty { return msg }
                if let msg = error["error"] as? String, !msg.isEmpty { return msg }
            }
            if let msg = json["error"] as? String, !msg.isEmpty { return msg }
        }
        let trimmed = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "request failed" : String(trimmed.prefix(240))
    }
}
