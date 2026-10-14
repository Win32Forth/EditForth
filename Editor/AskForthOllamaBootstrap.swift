//
//  AskForthOllamaBootstrap.swift
//  EditForth
//
//  Local Ollama reachability, model list, and /api/pull for Ask Forth setup.
//  Used to guide users (install Ollama + chat model) and to auto-pull
//  nomic-embed-text for Library Hybrid/Semantic indexing.
//

import Foundation

enum AskForthOllamaBootstrapError: LocalizedError, Sendable {
    case unreachable
    case badStatus(Int, String)
    case pullFailed(String)

    nonisolated var errorDescription: String? {
        switch self {
        case .unreachable:
            return "Ollama is not reachable at 127.0.0.1:11434."
        case .badStatus(let code, let body):
            let snippet = body.trimmingCharacters(in: .whitespacesAndNewlines)
            let short = snippet.isEmpty ? "" : ": \(String(snippet.prefix(160)))"
            return "Ollama request failed (HTTP \(code))\(short)"
        case .pullFailed(let detail):
            return "Could not download the Ollama model (\(detail))."
        }
    }
}

/// Networking helpers stay off the main actor (module default isolation is MainActor).
enum AskForthOllamaBootstrap: Sendable {
    nonisolated static let defaultBaseURL = URL(string: "http://127.0.0.1:11434")!
    nonisolated static let embedModel = "nomic-embed-text"
    nonisolated static let defaultChatModel = "gemma4:e4b"

    nonisolated static func isReachable(baseURL: URL = defaultBaseURL) async -> Bool {
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

    /// Model names from `/api/tags` (e.g. `gemma4:e4b`, `nomic-embed-text:latest`).
    nonisolated static func installedModels(baseURL: URL = defaultBaseURL) async throws -> [String] {
        let url = baseURL.appendingPathComponent("api/tags")
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AskForthOllamaBootstrapError.unreachable
        }
        guard let http = response as? HTTPURLResponse else {
            throw AskForthOllamaBootstrapError.unreachable
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AskForthOllamaBootstrapError.badStatus(http.statusCode, body)
        }
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = obj["models"] as? [[String: Any]]
        else {
            return []
        }
        return models.compactMap { $0["name"] as? String }
    }

    nonisolated static func hasModel(_ want: String, in names: [String]) -> Bool {
        let needle = want.lowercased()
        return names.contains { name in
            let n = name.lowercased()
            if n == needle { return true }
            if n.hasPrefix(needle + ":") { return true }
            if needle.hasPrefix(n + ":") { return true }
            // `nomic-embed-text:latest` vs `nomic-embed-text`
            let nBase = n.split(separator: ":", maxSplits: 1).first.map(String.init) ?? n
            let wBase = needle.split(separator: ":", maxSplits: 1).first.map(String.init) ?? needle
            return nBase == wBase
        }
    }

    nonisolated static func hasModel(_ want: String, baseURL: URL = defaultBaseURL) async -> Bool {
        (try? await installedModels(baseURL: baseURL)).map { hasModel(want, in: $0) } ?? false
    }

    /// Stream `POST /api/pull` until success (or error).
    nonisolated static func pullModel(
        _ model: String,
        baseURL: URL = defaultBaseURL,
        progress: (@Sendable (String) -> Void)? = nil
    ) async throws {
        let url = baseURL.appendingPathComponent("api/pull")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 3_600
        let body: [String: Any] = [
            "model": model,
            "stream": true
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await URLSession.shared.bytes(for: request)
        } catch {
            throw AskForthOllamaBootstrapError.unreachable
        }
        guard let http = response as? HTTPURLResponse else {
            throw AskForthOllamaBootstrapError.unreachable
        }
        guard (200...299).contains(http.statusCode) else {
            throw AskForthOllamaBootstrapError.badStatus(http.statusCode, "")
        }

        var sawSuccess = false
        for try await line in bytes.lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  let data = trimmed.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }

            if let err = obj["error"] as? String, !err.isEmpty {
                throw AskForthOllamaBootstrapError.pullFailed(err)
            }
            let status = (obj["status"] as? String) ?? ""
            if let total = obj["total"] as? Int, let completed = obj["completed"] as? Int, total > 0 {
                let pct = min(100, Int((Double(completed) / Double(total)) * 100.0))
                progress?("Downloading \(model)… \(pct)%")
            } else if !status.isEmpty {
                progress?("\(model): \(status)")
            }
            if status == "success" {
                sawSuccess = true
                break
            }
        }
        if !sawSuccess {
            // Some Ollama builds end the stream without a final "success" line after verify.
            if await hasModel(model, baseURL: baseURL) {
                progress?("Downloaded \(model).")
                return
            }
            throw AskForthOllamaBootstrapError.pullFailed("download did not report success")
        }
        progress?("Downloaded \(model).")
    }

    /// Human-readable setup tip, or nil when Ollama + (if Ollama chat) model look OK.
    /// Embeddings readiness is handled separately by Library prepare.
    nonisolated static func chatSetupBanner(
        provider: AskForthLLMProvider,
        chatModel: String
    ) async -> String? {
        let reachable = await isReachable()
        if provider == .ollama {
            if !reachable {
                return "Ask Forth needs Ollama. Install from https://ollama.com , start the app, then run: ollama pull \(chatModel.isEmpty ? defaultChatModel : chatModel)"
            }
            let names = (try? await installedModels()) ?? []
            let model = chatModel.trimmingCharacters(in: .whitespacesAndNewlines)
            let want = model.isEmpty ? defaultChatModel : model
            if !hasModel(want, in: names) {
                return "Ollama is running, but “\(want)” is not installed. In Terminal: ollama pull \(want)"
            }
            return nil
        }
        // OpenAI-compatible: still mention Ollama when Hybrid Library needs embeds.
        return nil
    }

    nonisolated static func libraryEmbedSetupBanner(
        retrieveMode: ForthLibraryRetrieveMode,
        indexReady: Bool,
        indexPresent: Bool = false,
        chunkCount: Int = 0
    ) async -> String? {
        guard retrieveMode != .keyword else { return nil }
        if !(await isReachable()) {
            return "Library Hybrid/Semantic needs Ollama for nomic-embed-text. Install from https://ollama.com and leave it running."
        }
        let names = (try? await installedModels()) ?? []
        if !hasModel(embedModel, in: names) {
            return "Library Hybrid/Semantic will download “\(embedModel)” (~274 MB) via Ollama when you open Ask Forth or Rebuild Index…"
        }
        if !indexReady {
            if indexPresent {
                return "Library embed index is out of date (\(chunkCount) chunks) — updating in the background (new or changed Library files)."
            }
            return "Library embed index not built yet — EditForth will build it in the background (Sample + Reference)."
        }
        return nil
    }
}

/// Pull nomic-embed-text if needed, then build/refresh the Library embed index (background-friendly).
enum AskForthLibraryPrepare {
    /// Coalesce concurrent prepare runs.
    private static var inFlight: Task<Void, Never>?

    @MainActor
    static var isBusy: Bool { inFlight != nil }

    /// Start once; later callers share the same task.
    @MainActor
    static func startIfNeeded(
        settings: ForthLibraryRAGSettings,
        progress: (@Sendable (String) -> Void)? = nil
    ) {
        guard settings.retrieveMode != .keyword else {
            progress?("")
            return
        }
        if inFlight != nil { return }
        inFlight = Task { @MainActor in
            defer { AskForthLibraryPrepare.inFlight = nil }
            await run(settings: settings, progress: progress)
        }
    }

    /// Networking off the main actor; index checks/builds hop back to MainActor.
    nonisolated static func run(
        settings: ForthLibraryRAGSettings,
        progress: (@Sendable (String) -> Void)? = nil
    ) async {
        guard settings.retrieveMode != .keyword else { return }

        let client = AskForthEmbeddingClient()
        guard await AskForthOllamaBootstrap.isReachable(baseURL: client.baseURL) else {
            progress?(
                "Library Hybrid/Semantic needs Ollama (https://ollama.com). Install, start it, then reopen Ask Forth."
            )
            return
        }

        let hasEmbed = await AskForthOllamaBootstrap.hasModel(client.model, baseURL: client.baseURL)
        if !hasEmbed {
            progress?("Downloading \(client.model) for Library search…")
            do {
                try await AskForthOllamaBootstrap.pullModel(
                    client.model,
                    baseURL: client.baseURL,
                    progress: progress
                )
            } catch {
                progress?("Could not download \(client.model): \(error.localizedDescription)")
                return
            }
        }

        let stale = await MainActor.run {
            ForthLibraryEmbedIndex.needsRefresh(settings: settings, model: client.model)
        }
        if stale {
            progress?("Building Library embed index in background…")
            do {
                _ = try await ForthLibraryEmbedIndex.ensureFresh(
                    settings: settings,
                    client: client,
                    progress: progress
                )
            } catch {
                progress?("Library index failed: \(error.localizedDescription)")
                return
            }
        }
        // Always clear when finished successfully (no “index ready” toast).
        progress?("")
    }
}
