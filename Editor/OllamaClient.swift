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
        try await completeStreaming(system: system, user: user, model: model, stream: false) { _ in }
    }

    func completeStreaming(
        system: String,
        user: String,
        model: String,
        onDelta: @escaping @Sendable (String) async -> Void
    ) async throws -> String {
        try await completeStreaming(system: system, user: user, model: model, stream: true, onDelta: onDelta)
    }

    private func completeStreaming(
        system: String,
        user: String,
        model: String,
        stream: Bool,
        onDelta: @escaping @Sendable (String) async -> Void
    ) async throws -> String {
        let url = baseURL.appendingPathComponent("api/chat")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300

        var messages: [[String: String]] = []
        let sys = system.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sys.isEmpty {
            messages.append(["role": "system", "content": sys])
        }
        messages.append(["role": "user", "content": user])

        let body: [String: Any] = [
            "model": model,
            "stream": stream,
            "messages": messages
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        if stream {
            return try await readChatStream(request: request, onDelta: onDelta)
        }

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
        if let message = json["message"] as? [String: Any],
           let content = message["content"] as? String {
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { throw LLMClientError.emptyResponse }
            await onDelta(trimmed)
            return trimmed
        }
        if let content = json["response"] as? String {
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { throw LLMClientError.emptyResponse }
            await onDelta(trimmed)
            return trimmed
        }
        throw LLMClientError.decoding("missing message.content")
    }

    /// NDJSON stream from `/api/chat` with `stream: true`.
    private func readChatStream(
        request: URLRequest,
        onDelta: @escaping @Sendable (String) async -> Void
    ) async throws -> String {
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
        var sawDone = false
        for try await line in bytes.lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { continue }
            guard let data = trimmedLine.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            if let message = json["message"] as? [String: Any],
               let piece = message["content"] as? String,
               !piece.isEmpty {
                assembled += piece
                await onDelta(piece)
            } else if let piece = json["response"] as? String, !piece.isEmpty {
                // /api/generate-style field; keep for robustness
                assembled += piece
                await onDelta(piece)
            }
            if json["done"] as? Bool == true {
                sawDone = true
                break
            }
        }

        let trimmed = assembled.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            throw LLMClientError.emptyResponse
        }
        // Prefer done:true; some servers close without it after the last chunk.
        _ = sawDone
        return trimmed
    }
}
