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
            "stream": false,
            "messages": messages
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

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
        // Non-streaming chat: { message: { content: "..." } }
        if let message = json["message"] as? [String: Any],
           let content = message["content"] as? String {
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { throw LLMClientError.emptyResponse }
            return trimmed
        }
        // Some builds nest under "response"
        if let content = json["response"] as? String {
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { throw LLMClientError.emptyResponse }
            return trimmed
        }
        throw LLMClientError.decoding("missing message.content")
    }
}
