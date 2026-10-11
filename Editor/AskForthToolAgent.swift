//
//  AskForthToolAgent.swift
//  EditForth
//
//  Opt-in Ollama tool loop for Ask Forth: web_search, fetch_url, library_search.
//

import Foundation

enum AskForthToolAgent {
    static let maxRounds = 4
    static let maxToolResultChars = 6_000

    static let toolDefinitions: [LLMToolDefinition] = [
        LLMToolDefinition(
            name: "web_search",
            description: "Search the web (DuckDuckGo Lite) and return top hit titles, URLs, and snippets. Use when you need current docs or examples not in Library.",
            parametersJSONSchema: [
                "type": "object",
                "properties": [
                    "query": [
                        "type": "string",
                        "description": "Search query, e.g. Forth OPEN-FILE stack effect"
                    ]
                ],
                "required": ["query"]
            ]
        ),
        LLMToolDefinition(
            name: "fetch_url",
            description: "Fetch one http(s) page and return plain text (HTML stripped, capped). Use for a specific documentation URL.",
            parametersJSONSchema: [
                "type": "object",
                "properties": [
                    "url": [
                        "type": "string",
                        "description": "Full http or https URL to fetch"
                    ]
                ],
                "required": ["url"]
            ]
        ),
        LLMToolDefinition(
            name: "library_search",
            description: "Search the EditForth Library folder (and Reference) for matching Forth/.txt excerpts. Prefer this for local samples and the Forth 2012 standard text.",
            parametersJSONSchema: [
                "type": "object",
                "properties": [
                    "query": [
                        "type": "string",
                        "description": "Forth words or topic to find in Library"
                    ]
                ],
                "required": ["query"]
            ]
        )
    ]

    /// Extra system guidance when tools are enabled.
    static func systemAddon() -> String {
        """
        You may call tools when they help answer accurately: web_search, fetch_url, library_search.
        Prefer library_search for local Sample/Reference knowledge; use web_search or fetch_url only when Library is insufficient.
        After tools return, give the final Forth-oriented answer. Do not invent tool results.
        """
    }

    struct RunResult: Sendable {
        var answer: String
        var transcript: String
        var rounds: Int
        var toolCallCount: Int
    }

    /// Multi-round chat with tools; streams only the final text answer via `onDelta`.
    static func run(
        client: LLMClient,
        system: String,
        user: String,
        model: String,
        onStatus: @escaping @MainActor (String) -> Void,
        onDelta: @escaping @Sendable (String) async -> Void
    ) async throws -> RunResult {
        var messages: [LLMChatMessage] = [
            .system(system + "\n" + systemAddon()),
            .user(user)
        ]
        var transcriptLines: [String] = []
        var toolCallCount = 0
        var rounds = 0

        for round in 1...maxRounds {
            rounds = round
            await onStatus("Tool agent round \(round)…")
            let reply = try await client.chat(
                messages: messages,
                tools: toolDefinitions,
                model: model,
                stream: false,
                onDelta: { _ in }
            )

            if let calls = reply.toolCalls, !calls.isEmpty {
                messages.append(reply)
                for call in calls {
                    toolCallCount += 1
                    let argSummary = summarizeArgs(call.argumentsJSON)
                    transcriptLines.append("→ \(call.name)(\(argSummary))")
                    await onStatus("Tool: \(call.name)…")
                    let resultText = await execute(call: call)
                    let capped = String(resultText.prefix(maxToolResultChars))
                    let preview = capped
                        .replacingOccurrences(of: "\n", with: " ")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    transcriptLines.append("← \(String(preview.prefix(160)))\(preview.count > 160 ? "…" : "")")
                    messages.append(.tool(name: call.name, content: capped, toolCallID: call.id))
                }
                continue
            }

            // Final answer — stream for UI parity with plain Ask.
            let content = reply.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if content.isEmpty {
                throw LLMClientError.emptyResponse
            }
            await onDelta(content)
            return RunResult(
                answer: content,
                transcript: transcriptLines.joined(separator: "\n"),
                rounds: rounds,
                toolCallCount: toolCallCount
            )
        }

        // Cap hit: one more turn without tools to force an answer.
        await onStatus("Tool agent finishing…")
        messages.append(.user("Tool budget exhausted. Answer now using the tool results already provided. Do not call tools."))
        let final = try await client.chat(
            messages: messages,
            tools: nil,
            model: model,
            stream: true,
            onDelta: onDelta
        )
        let content = final.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if content.isEmpty { throw LLMClientError.emptyResponse }
        transcriptLines.append("(stopped after \(maxRounds) tool rounds)")
        return RunResult(
            answer: content,
            transcript: transcriptLines.joined(separator: "\n"),
            rounds: rounds,
            toolCallCount: toolCallCount
        )
    }

    /// Audit comment lines for the AskForth file.
    static func auditCommentLines(transcript: String, toolCallCount: Int) -> [String] {
        guard toolCallCount > 0 else { return [] }
        var lines = ["\\ Tool agent: \(toolCallCount) call(s)"]
        for raw in transcript.split(separator: "\n", omittingEmptySubsequences: false) {
            let s = String(raw)
            if s.hasPrefix("→ ") {
                lines.append("\\   \(s)")
            }
        }
        return lines
    }

    // MARK: - Execute

    private static func execute(call: LLMToolCall) async -> String {
        let args = parseArgs(call.argumentsJSON)
        switch call.name {
        case "web_search":
            let query = stringArg(args, "query") ?? ""
            guard !query.isEmpty else { return "Error: missing query" }
            let result = await AskForthWebSearch.search(prompt: query)
            if result.isEmpty {
                return result.error.map { "Search error: \($0)" } ?? "No search hits."
            }
            return result.contextBlock(maxChars: maxToolResultChars)

        case "fetch_url":
            let urlText = stringArg(args, "url") ?? ""
            guard let url = URL(string: urlText),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https" else {
                return "Error: invalid http(s) URL"
            }
            let fetched = await AskForthURLFetch.fetchExcerpts(urls: [url])
            if fetched.isEmpty {
                let err = fetched.errors.first?.message ?? "empty"
                return "Fetch error: \(err)"
            }
            return fetched.contextBlock(maxChars: maxToolResultChars)

        case "library_search":
            let query = stringArg(args, "query") ?? ""
            guard !query.isEmpty else { return "Error: missing query" }
            let settings = ForthLibraryRAGSettings.load()
            let rag = await Task.detached(priority: .userInitiated) {
                ForthLibraryRAG.retrieve(for: query, settings: settings)
            }.value
            if rag.isEmpty {
                return "Library: no hits for “\(query)”."
            }
            return rag.contextBlock(maxChars: min(settings.maxChars, maxToolResultChars))

        default:
            return "Error: unknown tool \(call.name)"
        }
    }

    private static func parseArgs(_ json: String) -> [String: Any] {
        let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let data = trimmed.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return obj
    }

    private static func stringArg(_ args: [String: Any], _ key: String) -> String? {
        if let s = args[key] as? String { return s }
        if let n = args[key] as? NSNumber { return n.stringValue }
        return nil
    }

    private static func summarizeArgs(_ json: String) -> String {
        let args = parseArgs(json)
        if args.isEmpty { return json.isEmpty ? "" : String(json.prefix(80)) }
        let parts = args.keys.sorted().compactMap { key -> String? in
            guard let v = stringArg(args, key) else { return "\(key)=…" }
            let short = v.count > 60 ? String(v.prefix(60)) + "…" : v
            return "\(key)=“\(short)”"
        }
        return parts.joined(separator: ", ")
    }
}
