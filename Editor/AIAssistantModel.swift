//
//  AIAssistantModel.swift
//  EditForth
//
//  Ask-Forth panel state: prompt → local LLM → one AskForth-N.fth session.
//  Follow-up Asks keep that file. Earlier drafts are line-commented.
//  Agent Enhance tests the live section, then replaces it.
//

import Foundation
import AppKit
import Combine

@MainActor
final class AIAssistantModel: ObservableObject {
    static let libraryRAGKey = "aiAssistantLibraryRAG"
    static let urlFetchKey = "aiAssistantURLFetch"
    static let webSearchKey = "aiAssistantWebSearch"
    static let toolAgentKey = "aiAssistantToolAgent"
    static let showAgentTranscriptKey = "aiAssistantShowAgentTranscript"

    @Published var prompt: String = ""
    /// Latest model segment (current Ask or Fix body) — used by Eval Reply and Agent Fix.
    @Published var reply: String = ""
    @Published var agentTranscript: String = ""
    @Published var status: String = ""
    @Published var isBusy = false
    /// In-flight Ask / Enhance / agent Task; cancelled by `stop()`.
    private var activeJob: Task<Void, Never>?
    /// When true, Ask / Fix retrieve Library .fth excerpts into the prompt.
    @Published var includeLibraryContext: Bool
    /// When true, fetch http(s) URLs found in the Prompt and add page text to the LLM context.
    @Published var fetchURLsInPrompt: Bool
    /// When true, run an opt-in DuckDuckGo Lite web search and add hit snippets to the LLM context.
    @Published var includeWebSearch: Bool
    /// When true, Ask / Enhance use an Ollama tool loop (web_search / fetch_url / library_search).
    @Published var useToolAgent: Bool
    /// When true, show the headless --agent transcript box.
    @Published var showAgentTranscript: Bool
    /// Open editor file sent as read-only context. Empty means (none).
    @Published var referenceFilePath: String
    /// Active profile id (panel picker). Details edited in Models….
    @Published var activeProfileID: UUID
    @Published var profiles: [AskForthModelProfile]
    /// Convenience mirrors of the active profile (Ask path + status strings).
    @Published var modelName: String
    @Published var provider: AskForthLLMProvider
    @Published var openAIBaseURLString: String
    /// Draft API key for the Models sheet (active or selected profile).
    @Published var apiKeyDraft: String = ""
    @Published var apiKeyStatus: String = ""
    /// Setup / Library prepare tip shown under the Ask Forth help panel (Ollama, models, index).
    @Published var setupBanner: String = ""

    /// Tab / path that receives streamed Ask / Fix output.
    private(set) var askOutputTabID: UUID?
    private(set) var askOutputFileURL: URL?
    /// UTF-16 offset where the live section starts, after the `\ --- live ---` marker.
    private var askStreamBodyStart: Int?
    /// Session text from before this turn's archive rewrite. Restored if the model returns nothing.
    private var sessionSnapshot: String?
    /// Earlier prompts and previous live Forth for a follow-up. Not sent to web search.
    private var pendingSessionPreface: String = ""
    /// Read-only reference captured when the Ask or Enhance started.
    private var pendingReferencePath: String?
    /// Prepended to the done status when this Ask had to start a new file.
    private var sessionStatusPrefix: String = ""

    static let sessionFileKey = "askForthSessionFilePath"
    static let referenceFileKey = "askForthReferenceFilePath"

    private var client: LLMClient

    init(client: LLMClient? = nil) {
        let list = AskForthLLMSettings.ensureProfiles()
        let active = AskForthLLMSettings.activeProfile
        self.profiles = list
        self.activeProfileID = active.id
        self.provider = active.provider
        self.openAIBaseURLString = active.resolvedBaseURLString
        self.modelName = AskForthLLMSettings.activeModel
        self.client = client ?? AskForthLLMSettings.makeClient()
        if UserDefaults.standard.object(forKey: Self.libraryRAGKey) == nil {
            self.includeLibraryContext = true
        } else {
            self.includeLibraryContext = UserDefaults.standard.bool(forKey: Self.libraryRAGKey)
        }
        if UserDefaults.standard.object(forKey: Self.urlFetchKey) == nil {
            self.fetchURLsInPrompt = true
        } else {
            self.fetchURLsInPrompt = UserDefaults.standard.bool(forKey: Self.urlFetchKey)
        }
        // Default off (privacy / network).
        self.includeWebSearch = UserDefaults.standard.bool(forKey: Self.webSearchKey)
        // Default off (slower; model-driven browsing).
        self.useToolAgent = UserDefaults.standard.bool(forKey: Self.toolAgentKey)
        self.showAgentTranscript = UserDefaults.standard.bool(forKey: Self.showAgentTranscriptKey)
        self.referenceFilePath = UserDefaults.standard.string(forKey: Self.referenceFileKey) ?? ""
        if let path = UserDefaults.standard.string(forKey: Self.sessionFileKey), !path.isEmpty {
            let url = URL(fileURLWithPath: path).standardizedFileURL
            if FileManager.default.fileExists(atPath: url.path) {
                self.askOutputFileURL = url
                if let text = try? String(contentsOf: url, encoding: .utf8) {
                    let live = AskForthSession.parse(text).live
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !live.isEmpty {
                        self.reply = live
                    }
                }
            } else {
                UserDefaults.standard.removeObject(forKey: Self.sessionFileKey)
                self.status = "Previous Ask Forth session file is missing. The next Ask starts a new session."
            }
        }
        refreshAPIKeyStatus()
    }

    var providerLabel: String { client.providerName }

    var activeProfileCaption: String {
        profiles.first(where: { $0.id == activeProfileID })?.caption
            ?? AskForthLLMSettings.activeProfile.caption
    }

    var askOutputFileName: String? {
        askOutputFileURL?.lastPathComponent
    }

    /// Refresh Ollama/chat/Library setup tips and start background embed prepare when needed.
    func prepareAskForthEnvironment() {
        Task { await refreshSetupBanner() }
        guard includeLibraryContext else { return }
        let settings = ForthLibraryRAGSettings.load()
        guard settings.retrieveMode != .keyword else { return }
        AskForthLibraryPrepare.startIfNeeded(settings: settings) { [weak self] note in
            Task { @MainActor in
                guard let self else { return }
                await self.applyLibraryPrepareProgress(note)
            }
        }
    }

    /// Orange banner shows only in-progress / failure notes — never “Indexed / ready” completion text.
    private func applyLibraryPrepareProgress(_ note: String) async {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        let isCompletion =
            trimmed.isEmpty
            || lower.hasPrefix("indexed ")
            || lower.contains("index ready")
            || lower.hasPrefix("library index ready")
        if isCompletion {
            await refreshSetupBanner()
            return
        }
        setupBanner = trimmed
        if !isBusy {
            status = trimmed
        }
        if !AskForthLibraryPrepare.isBusy {
            await refreshSetupBanner()
        }
    }

    func refreshSetupBanner() async {
        var parts: [String] = []
        if let chat = await AskForthOllamaBootstrap.chatSetupBanner(
            provider: provider,
            chatModel: modelName
        ) {
            parts.append(chat)
        }
        let settings = ForthLibraryRAGSettings.load()
        if includeLibraryContext {
            let store = ForthLibraryEmbedIndex.load()
            let indexPresent = store.map { !$0.isEmpty } ?? false
            let chunkCount = store?.chunks.count ?? 0
            let indexReady = indexPresent
                && !(ForthLibraryEmbedIndex.needsRefresh(settings: settings))
            // Only warn when Library embed setup is incomplete or updating — never a green/ready toast.
            if let lib = await AskForthOllamaBootstrap.libraryEmbedSetupBanner(
                retrieveMode: settings.retrieveMode,
                indexReady: indexReady,
                indexPresent: indexPresent,
                chunkCount: chunkCount
            ) {
                parts.append(lib)
            }
        }
        setupBanner = parts.joined(separator: "\n")
    }

    /// Reload profiles from disk after the Models sheet closes or edits.
    func reloadProfilesFromSettings() {
        profiles = AskForthLLMSettings.loadProfiles()
        let active = AskForthLLMSettings.activeProfile
        activeProfileID = active.id
        applyActiveProfileToState(rebuildClient: true)
        refreshAPIKeyStatus(for: active.id)
    }

    /// Switch the active saved profile (panel picker).
    func selectProfile(id: UUID) {
        guard profiles.contains(where: { $0.id == id }) else { return }
        AskForthLLMSettings.selectProfile(id: id)
        activeProfileID = id
        applyActiveProfileToState(rebuildClient: true)
        refreshAPIKeyStatus(for: id)
        let name = profiles.first(where: { $0.id == id })?.name ?? "profile"
        status = "Model profile: \(name)."
    }

    private func applyActiveProfileToState(rebuildClient: Bool) {
        let active = AskForthLLMSettings.activeProfile
        provider = active.provider
        modelName = AskForthLLMSettings.activeModel
        openAIBaseURLString = active.resolvedBaseURLString
        if rebuildClient {
            client = AskForthLLMSettings.makeClient()
        }
    }

    func refreshAPIKeyStatus(for profileID: UUID? = nil) {
        let id = profileID ?? activeProfileID
        let profile = profiles.first(where: { $0.id == id }) ?? AskForthLLMSettings.activeProfile
        guard profile.provider == .openAICompatible else {
            apiKeyStatus = ""
            return
        }
        if AskForthLLMSettings.hasKeychainAPIKey(for: id) {
            apiKeyStatus = "Key saved in Keychain"
        } else if ProcessInfo.processInfo.environment["XAI_API_KEY"]?.isEmpty == false {
            apiKeyStatus = "Using XAI_API_KEY from environment"
        } else {
            apiKeyStatus = "No API key — Save one or export XAI_API_KEY"
        }
    }

    func saveAPIKeyDraft(for profileID: UUID? = nil) {
        let id = profileID ?? activeProfileID
        do {
            try AskForthLLMSettings.saveAPIKey(apiKeyDraft, for: id)
            apiKeyDraft = ""
            refreshAPIKeyStatus(for: id)
            if id == activeProfileID, provider == .openAICompatible {
                client = AskForthLLMSettings.makeClient()
            }
            status = "API key saved."
        } catch {
            status = error.localizedDescription
        }
    }

    func clearAPIKey(for profileID: UUID? = nil) {
        let id = profileID ?? activeProfileID
        do {
            try AskForthLLMSettings.deleteAPIKey(for: id)
            apiKeyDraft = ""
            refreshAPIKeyStatus(for: id)
            if id == activeProfileID {
                client = AskForthLLMSettings.makeClient()
            }
            status = "API key cleared."
        } catch {
            status = error.localizedDescription
        }
    }

    /// Cancel the in-flight Ask / Enhance / headless-agent job and clear busy state.
    func stop() {
        guard isBusy || activeJob != nil else { return }
        activeJob?.cancel()
        activeJob = nil
        isBusy = false
        status = "Stopped."
    }

    private func attachJob(_ task: Task<Void, Never>) {
        activeJob?.cancel()
        activeJob = task
    }

    private func finishJobIfCurrent(_ task: Task<Void, Never>?) {
        guard let task else { return }
        if activeJob == task {
            activeJob = nil
        }
    }

    /// Lets a Task body clear `activeJob` after `let job = Task { … }` finishes initializing.
    private final class JobHandle: @unchecked Sendable {
        var task: Task<Void, Never>?
    }

    private func statusForCaughtError(_ error: Error) -> String {
        if error is CancellationError { return "Stopped." }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain, ns.code == NSURLErrorCancelled {
            return "Stopped."
        }
        return error.localizedDescription
    }

    func persistLibraryRAG() {
        UserDefaults.standard.set(includeLibraryContext, forKey: Self.libraryRAGKey)
    }

    func persistURLFetch() {
        UserDefaults.standard.set(fetchURLsInPrompt, forKey: Self.urlFetchKey)
    }

    func persistWebSearch() {
        UserDefaults.standard.set(includeWebSearch, forKey: Self.webSearchKey)
    }

    func persistToolAgent() {
        UserDefaults.standard.set(useToolAgent, forKey: Self.toolAgentKey)
    }

    func persistShowAgentTranscript() {
        UserDefaults.standard.set(showAgentTranscript, forKey: Self.showAgentTranscriptKey)
    }

    func persistReferenceFile() {
        UserDefaults.standard.set(referenceFilePath, forKey: Self.referenceFileKey)
    }

    /// Keep the current AskForth file and start a new one on the next Ask.
    func startNewSession(status message: String? = nil) {
        guard !isBusy else { return }
        UserDefaults.standard.removeObject(forKey: Self.sessionFileKey)
        askOutputTabID = nil
        askOutputFileURL = nil
        askStreamBodyStart = nil
        sessionSnapshot = nil
        pendingSessionPreface = ""
        pendingReferencePath = nil
        sessionStatusPrefix = ""
        reply = ""
        agentTranscript = ""
        status = message ?? "New session. The next Ask starts a new file. The previous file was kept."
    }

    /// Drop the session when its file is gone from the AskForth folder, or the open tab was renamed or Save As'd elsewhere.
    /// The next Ask creates a new AskForth-N.fth in that folder. Returns true when a session was dropped.
    @discardableResult
    func detachSessionIfDisplaced(in workspace: WorkspaceModel) -> Bool {
        guard !isBusy else { return false }
        guard let stored = askOutputFileURL?.standardizedFileURL else { return false }
        guard let reason = sessionDisplacementReason(stored: stored, workspace: workspace) else { return false }
        startNewSession(status: reason)
        return true
    }

    /// Reference path only when that file is still an open editor tab, and it is not the session file.
    func effectiveReferencePath(in workspace: WorkspaceModel) -> String? {
        let raw = referenceFilePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        let path = URL(fileURLWithPath: raw).standardizedFileURL.path
        if path == askOutputFileURL?.standardizedFileURL.path { return nil }
        guard workspace.tabs.contains(where: { $0.fileURL?.standardizedFileURL.path == path }) else { return nil }
        return path
    }

    /// Copy the editor selection into the Prompt box.
    func captureSelectedToPrompt(from workspace: WorkspaceModel) {
        guard let tab = workspace.selectedTab else {
            status = "No file tab selected."
            return
        }
        guard let sel = tab.selectedText(), !sel.isEmpty else {
            status = "Select text in the editor first."
            return
        }
        prompt = sel
        status = "Using selection (\(sel.count) characters)."
    }

    func ask(workspace: WorkspaceModel) {
        guard !isBusy else { return }
        let userPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userPrompt.isEmpty else {
            status = "Enter a question or capture editor context first."
            return
        }
        // New question: drop the previous Eval transcript so Show Agent Transcript is not stale.
        let displaced = detachSessionIfDisplaced(in: workspace)
        agentTranscript = ""
        sessionStatusPrefix = displaced
            ? "Started a new session in the AskForth folder. "
            : ""
        let reference = effectiveReferencePath(in: workspace)
        let continuing = sessionFileIsPresent
        let fileHint = reference.map { URL(fileURLWithPath: $0).lastPathComponent }
        let destination: StreamDestination = continuing
            ? .continueSession(prompt: userPrompt, referencePath: reference)
            : .newSession(prompt: userPrompt, referencePath: reference)
        runCompletion(
            workspace: workspace,
            system: Self.systemPrompt(fileName: fileHint, continuing: continuing),
            user: userPrompt,
            ragQuery: userPrompt,
            destination: destination,
            busyStatus: "Asking \(client.providerName) (\(modelName))…",
            doneStatus: continuing ? "Continued session." : "Done."
        )
    }

    /// Send the live section and agent transcript back to the model. The new reply replaces the live section.
    private func askFixFromAgent(workspace: WorkspaceModel) {
        let transcript = agentTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else {
            status = "Agent produced no transcript to fix from."
            return
        }
        let priorReply = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        let priorPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !priorReply.isEmpty || !priorPrompt.isEmpty else {
            status = "Need a prompt or prior Ask reply to fix."
            return
        }

        sessionStatusPrefix = ""
        let reference = effectiveReferencePath(in: workspace)
        var parts: [String] = [
            "The previous Forth answer was evaluated with a headless 64Forth --agent process.",
            "Fix the Forth so it works on EditForth / 64Forth (ANS-style ITC). Prefer a single ```forth fenced block with the corrected source. Briefly note what you changed.",
            "Return only the corrected live Forth. The host comments out the previous live section. Do not repeat the session header or earlier drafts."
        ]
        if !priorPrompt.isEmpty {
            parts.append("Original request / context:\n\(priorPrompt)")
        }
        if !priorReply.isEmpty {
            parts.append("Previous answer:\n\(priorReply)")
        }
        parts.append("Agent transcript (exit status is in the status line if shown):\n\(transcript)")

        let ragQuery = [priorPrompt, priorReply, transcript].joined(separator: "\n")
        let fileHint = reference.map { URL(fileURLWithPath: $0).lastPathComponent }
        runCompletion(
            workspace: workspace,
            system: Self.systemPrompt(fileName: fileHint, continuing: true)
                + "\nYou are correcting Forth that failed or needs improvement after a real kernel eval."
                + " Prefer System/Reference stack effects and Sample idioms when they match."
                + " Do not claim a fix unless the change is concrete; keep stack comments accurate.",
            user: parts.joined(separator: "\n\n"),
            ragQuery: ragQuery,
            destination: .enhanceReply(referencePath: reference),
            busyStatus: "Asking \(client.providerName) to enhance reply…",
            doneStatus: "Agent Enhanced Reply written."
        )
    }

    private enum StreamDestination {
        case newSession(prompt: String, referencePath: String?)
        case continueSession(prompt: String, referencePath: String?)
        case enhanceReply(referencePath: String?)
    }

    private func runCompletion(
        workspace: WorkspaceModel,
        system: String,
        user: String,
        ragQuery: String,
        destination: StreamDestination,
        busyStatus: String,
        doneStatus: String
    ) {
        guard !isBusy else { return }

        persistLibraryRAG()
        persistURLFetch()
        persistWebSearch()
        persistToolAgent()
        // If the user pasted a key but forgot Save, persist it before the request.
        if provider == .openAICompatible,
           !apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            saveAPIKeyDraft(for: activeProfileID)
        }
        // Rebuild client from the active profile.
        client = AskForthLLMSettings.makeClient()
        applyActiveProfileToState(rebuildClient: false)
        isBusy = true
        status = busyStatus
        reply = ""
        sessionSnapshot = nil
        pendingSessionPreface = ""
        pendingReferencePath = nil

        let model = modelName
        let client = self.client
        let useRAG = includeLibraryContext
        let useURLFetch = fetchURLsInPrompt
        let useWebSearch = includeWebSearch
        let useTools = useToolAgent
        let urlSource = prompt
        let providerSnapshot = provider
        let baseURLSnapshot = openAIBaseURLString
        let profileIDSnapshot = activeProfileID

        let handle = JobHandle()
        let job = Task {
            defer {
                Task { @MainActor in
                    self.finishJobIfCurrent(handle.task)
                }
            }
            if providerSnapshot == .openAICompatible, !AskForthLLMSettings.hasAPIKey(for: profileIDSnapshot) {
                await MainActor.run {
                    self.isBusy = false
                    self.status = "No API key — open Models…, paste a key, and click Save (or export XAI_API_KEY)."
                    self.recoverReplyIfEmpty(in: workspace)
                }
                return
            }
            try? Task.checkCancellation()
            let reachable = await client.ping()
            guard !Task.isCancelled else { return }
            guard reachable else {
                await MainActor.run {
                    self.isBusy = false
                    switch providerSnapshot {
                    case .ollama:
                        self.status = "Ollama is not reachable at 127.0.0.1:11434."
                    case .openAICompatible:
                        self.status = "Cannot reach \(baseURLSnapshot) (network). Check Base URL in Models… and connectivity."
                    }
                    self.recoverReplyIfEmpty(in: workspace)
                }
                return
            }

            // Prepare the session file before streaming. A failed request restores the previous text.
            let prepared: Bool = await MainActor.run {
                self.prepareDestination(destination, workspace: workspace)
            }
            guard prepared else {
                await MainActor.run {
                    self.recoverReplyIfEmpty(in: workspace)
                }
                return
            }

            var contextPrefix = ""
            var contextNote = ""

            // Session history and the read-only reference go to the model only.
            // Web search still uses the Prompt box, not the reference file or the session.
            let sessionBits: (String, String) = await MainActor.run {
                let preface = self.pendingSessionPreface
                let block = self.referenceContextBlock(in: workspace, path: self.pendingReferencePath)
                return (preface, block)
            }
            if !sessionBits.0.isEmpty {
                contextPrefix += sessionBits.0 + "\n\n"
            }
            if !sessionBits.1.isEmpty {
                contextPrefix += sessionBits.1 + "\n\n"
            }

            // Tool agent decides when to browse/search; skip automatic URL/web pre-fetch.
            if !useTools {
                if useURLFetch {
                    let promptURLs = AskForthURLFetch.extractURLs(from: urlSource)
                    let standardURLs = AskForthStandardBoost.standardURLs(for: urlSource)
                    if !promptURLs.isEmpty || !standardURLs.isEmpty {
                        await MainActor.run {
                            self.status = standardURLs.isEmpty ? "Fetching URLs…" : "Fetching standard / URLs…"
                        }
                        var web = await AskForthURLFetch.fetchExcerpts(urls: promptURLs)
                        if !standardURLs.isEmpty {
                            let boost = await AskForthURLFetch.fetchExcerpts(urls: standardURLs)
                            web = AskForthURLFetch.merge(web, boost)
                        }
                        if !web.isEmpty {
                            let block = web.contextBlock(maxChars: 16_000)
                            if !block.isEmpty {
                                contextPrefix += block + "\n\n"
                            }
                        }
                        contextNote += web.statusNote
                        if !standardURLs.isEmpty {
                            let names = AskForthStandardBoost.candidateWords(in: urlSource).prefix(3).joined(separator: ", ")
                            if !names.isEmpty {
                                contextNote += " · Standard \(names)"
                            }
                        }
                    }
                }

                if useWebSearch {
                    await MainActor.run {
                        self.status = "Searching the web…"
                    }
                    let search = await AskForthWebSearch.search(prompt: urlSource)
                    if !search.isEmpty {
                        let block = search.contextBlock(maxChars: AskForthWebSearch.maxContextChars)
                        if !block.isEmpty {
                            contextPrefix += block + "\n\n"
                        }
                        await MainActor.run {
                            self.appendWebSearchAudit(search, in: workspace)
                        }
                    }
                    contextNote += search.statusNote
                }
            }

            // Passive Library RAG still helps when Tool agent is on; tools can deepen it.
            var libraryHadHits = false
            var libraryWasSearched = false
            if useRAG {
                libraryWasSearched = true
                await MainActor.run {
                    self.status = "Searching Library…"
                }
                let settings = ForthLibraryRAGSettings.load()
                // Hybrid/semantic await Ollama embeddings; auto-rebuild if Library drifted.
                let rag = await ForthLibraryRAG.retrieveAsync(
                    for: ragQuery,
                    settings: settings,
                    embedClient: AskForthEmbeddingClient(),
                    embedProgress: { note in
                        Task { @MainActor in
                            self.status = note
                        }
                    }
                )
                if !rag.isEmpty {
                    let block = rag.contextBlock(maxChars: settings.maxChars)
                    if !block.isEmpty {
                        contextPrefix += block + "\n\n"
                        libraryHadHits = true
                    }
                    let names = rag.snippets.map(\.relativePath).prefix(4).joined(separator: ", ")
                    contextNote += " · Library \(rag.snippets.count) \(rag.retrieveModeLabel): \(names)"
                } else {
                    contextNote += " · Library: no hits (\(settings.retrieveMode.statusLabel))"
                }
            }

            let effectiveSystem = system + Self.libraryGroundingAddon(
                searched: libraryWasSearched,
                hasHits: libraryHadHits
            )

            let finalUser: String
            if libraryHadHits {
                finalUser = contextPrefix
                    + Self.libraryUserReminderWithHits
                    + "\n\nUser request:\n"
                    + user
            } else if libraryWasSearched {
                let emptyNote = Self.libraryUserReminderNoHits
                if contextPrefix.isEmpty {
                    finalUser = emptyNote + "\n\nUser request:\n" + user
                } else {
                    finalUser = contextPrefix + emptyNote + "\n\nUser request:\n" + user
                }
            } else if contextPrefix.isEmpty {
                finalUser = user
            } else {
                finalUser = contextPrefix + "User request:\n" + user
            }

            await MainActor.run {
                if let name = self.askOutputFileName {
                    self.status = useTools ? "Tool agent → \(name)…" : "Streaming into \(name)…"
                } else {
                    self.status = busyStatus
                }
            }

            do {
                let text: String
                if useTools {
                    let result = try await AskForthToolAgent.run(
                        client: client,
                        system: effectiveSystem,
                        user: finalUser,
                        model: model,
                        onStatus: { note in
                            self.status = note
                        },
                        onDelta: { delta in
                            await MainActor.run {
                                self.reply += delta
                                self.writeLiveStreamBody(self.reply, in: workspace, closeParens: false)
                            }
                        }
                    )
                    text = result.answer
                    await MainActor.run {
                        if !result.transcript.isEmpty {
                            let prior = self.agentTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
                            let block = "Tool agent\n" + result.transcript
                            self.agentTranscript = prior.isEmpty ? block : prior + "\n\n" + block
                        }
                        self.appendToolAgentAudit(result, in: workspace)
                        contextNote += " · Tools \(result.toolCallCount) call(s)/\(result.rounds) round(s)"
                    }
                } else {
                    text = try await client.completeStreaming(
                        system: effectiveSystem,
                        user: finalUser,
                        model: model
                    ) { delta in
                        await MainActor.run {
                            self.reply += delta
                            self.writeLiveStreamBody(self.reply, in: workspace, closeParens: false)
                        }
                    }
                }
                await MainActor.run {
                    if Task.isCancelled {
                        self.finishInterruptedStream(in: workspace, cancelled: true, error: nil)
                        return
                    }
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    let body = trimmed.isEmpty
                        ? self.reply.trimmingCharacters(in: .whitespacesAndNewlines)
                        : trimmed
                    if body.isEmpty {
                        let restored = self.sessionSnapshot != nil
                        self.recoverReplyIfEmpty(in: workspace)
                        self.askStreamBodyStart = nil
                        self.pendingSessionPreface = ""
                        self.isBusy = false
                        self.sessionStatusPrefix = ""
                        self.status = restored
                            ? "The model returned nothing. The session file was left unchanged."
                            : "The model returned nothing."
                        return
                    }
                    self.commitLiveReply(body, in: workspace)
                    self.askStreamBodyStart = nil
                    self.pendingSessionPreface = ""
                    self.isBusy = false
                    let fileNote = self.askOutputFileName.map { " · \($0)" } ?? ""
                    self.status = self.sessionStatusPrefix + doneStatus + fileNote + contextNote
                    self.sessionStatusPrefix = ""
                }
            } catch {
                await MainActor.run {
                    self.finishInterruptedStream(
                        in: workspace,
                        cancelled: Task.isCancelled || error is CancellationError,
                        error: error
                    )
                }
            }
        }
        handle.task = job
        attachJob(job)
    }

    /// Replace the live section. Does not wrap columns: wrapping can split a comment into code.
    /// `reply` stays the latest answer. The file gets the sanitized text.
    private func writeLiveStreamBody(_ body: String, in workspace: WorkspaceModel, closeParens: Bool) {
        guard let tab = resolveAskOutputTab(in: workspace),
              let start = askStreamBodyStart else { return }
        let ns = tab.text as NSString
        let safeStart = min(max(0, start), ns.length)
        let prefix = ns.substring(to: safeStart)
        let safe = AskForthSession.sanitizeLive(body, closeParens: closeParens)
        tab.text = prefix + safe
        tab.isDirty = true
        // Do not move selection to end on every chunk — that forces the editor to
        // fight the user when they scroll up to read while Ask / Enhance streams.
    }

    private func resolveAskOutputTab(in workspace: WorkspaceModel) -> EditorTab? {
        guard let stored = askOutputFileURL?.standardizedFileURL,
              sessionFileIsInAskForthFolder(stored),
              FileManager.default.fileExists(atPath: stored.path) else {
            return nil
        }
        if let id = askOutputTabID, let tab = workspace.tab(id: id) {
            if tab.fileURL?.standardizedFileURL.path == stored.path {
                return tab
            }
            // Save As / rename changed this tab. Do not follow it.
            askOutputTabID = nil
        }
        let tab = workspace.openURL(stored, viewMode: false, line: nil)
        askOutputTabID = tab?.id
        return tab
    }

    /// Headless eval of the latest live section, then replace that section with the enhanced reply.
    func evalReplyAndAgentFix(workspace: WorkspaceModel) {
        if detachSessionIfDisplaced(in: workspace) {
            return
        }
        syncReplyFromSession(in: workspace)
        let source = ForthAgentRunner.extractForthSource(from: reply)
        runAgent(source: source, workspace: workspace, label: "reply") { [weak self] ok in
            guard let self, ok else { return }
            self.askFixFromAgent(workspace: workspace)
        }
    }

    /// Run `64Forth --agent` with Autoload always on. `onFinished(true)` when a transcript was captured.
    private func runAgent(
        source: String,
        workspace: WorkspaceModel,
        label: String,
        onFinished: ((Bool) -> Void)? = nil
    ) {
        let code = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else {
            status = "No Forth source in \(label) to evaluate."
            onFinished?(false)
            return
        }
        guard !isBusy else {
            onFinished?(false)
            return
        }

        isBusy = true
        agentTranscript = ""
        status = "Running 64Forth --agent on \(label)…"

        let cwd = agentWorkingDirectory(workspace: workspace)

        let handle = JobHandle()
        let job = Task {
            defer {
                Task { @MainActor in
                    self.finishJobIfCurrent(handle.task)
                }
            }
            do {
                try Task.checkCancellation()
                let result = try await ForthAgentRunner.evaluate(
                    source: code,
                    cwd: cwd,
                    autoload: true
                )
                await MainActor.run {
                    guard !Task.isCancelled else {
                        onFinished?(false)
                        return
                    }
                    self.agentTranscript = result.transcript.isEmpty
                        ? "(no transcript, exit \(result.exitCode))"
                        : result.transcript
                    self.isBusy = false
                    if result.exitCode == 0 {
                        self.status = "Agent OK (exit 0) — enhancing…"
                    } else {
                        self.status = "Agent exit \(result.exitCode) — enhancing…"
                    }
                    onFinished?(true)
                }
            } catch {
                await MainActor.run {
                    if Task.isCancelled || error is CancellationError {
                        if self.isBusy {
                            self.isBusy = false
                            self.status = "Stopped."
                        }
                        onFinished?(false)
                        return
                    }
                    self.isBusy = false
                    self.agentTranscript = ""
                    self.status = self.statusForCaughtError(error)
                    onFinished?(false)
                }
            }
        }
        handle.task = job
        attachJob(job)
    }

    private func agentWorkingDirectory(workspace: WorkspaceModel) -> URL {
        if let url = askOutputFileURL?.deletingLastPathComponent(),
           FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        if let dir = workspace.selectedTab?.fileURL?.deletingLastPathComponent(),
           FileManager.default.fileExists(atPath: dir.path) {
            return dir
        }
        let docs = ForthMenuSupport.userTreeURL
        if FileManager.default.fileExists(atPath: docs.path) {
            return docs
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    /// Insert `\ Web search: …` audit lines before the current stream body, then bump the body start.
    private func appendWebSearchAudit(_ search: AskForthWebSearchResult, in workspace: WorkspaceModel) {
        appendAskFileAuditComments(search.auditCommentLines(), in: workspace)
    }

    private func appendToolAgentAudit(_ result: AskForthToolAgent.RunResult, in workspace: WorkspaceModel) {
        appendAskFileAuditComments(
            AskForthToolAgent.auditCommentLines(transcript: result.transcript, toolCallCount: result.toolCallCount),
            in: workspace
        )
    }

    private func appendAskFileAuditComments(_ comments: [String], in workspace: WorkspaceModel) {
        guard let tab = resolveAskOutputTab(in: workspace),
              let start = askStreamBodyStart else { return }
        guard !comments.isEmpty else { return }
        let block = comments.joined(separator: "\n") + "\n\n"
        let ns = tab.text as NSString
        let safeStart = min(max(0, start), ns.length)
        let prefix = ns.substring(to: safeStart)
        let suffix = ns.substring(from: safeStart)
        tab.text = prefix + block + suffix
        tab.isDirty = true
        askStreamBodyStart = safeStart + (block as NSString).length
    }

    private var sessionFileIsPresent: Bool {
        guard let url = askOutputFileURL?.standardizedFileURL else { return false }
        return sessionFileIsInAskForthFolder(url) && FileManager.default.fileExists(atPath: url.path)
    }

    private func sessionFileIsInAskForthFolder(_ url: URL) -> Bool {
        let folder = ForthMenuSupport.userTreeURL
            .appendingPathComponent("AskForth", isDirectory: true)
            .standardizedFileURL
        return url.deletingLastPathComponent().standardizedFileURL.path == folder.path
    }

    /// Nil when this session should continue. A string when the next Ask must create a new file in the AskForth folder.
    private func sessionDisplacementReason(stored: URL, workspace: WorkspaceModel) -> String? {
        if !sessionFileIsInAskForthFolder(stored) || !FileManager.default.fileExists(atPath: stored.path) {
            return "The Ask Forth session file is not in the AskForth folder. Started a new session. The next Ask creates a new file there."
        }
        if let id = askOutputTabID,
           let tab = workspace.tab(id: id),
           let current = tab.fileURL?.standardizedFileURL.path,
           current != stored.path {
            return "The Ask Forth file was renamed or saved elsewhere. Started a new session. The next Ask creates a new file in the AskForth folder."
        }
        return nil
    }

    private func prepareDestination(_ destination: StreamDestination, workspace: WorkspaceModel) -> Bool {
        switch destination {
        case .newSession(let prompt, let reference):
            return prepareNewSession(prompt: prompt, reference: reference, workspace: workspace)
        case .continueSession(let prompt, let reference):
            if let tab = resolveAskOutputTab(in: workspace) {
                return prepareContinuation(
                    tab: tab,
                    workspace: workspace,
                    newPrompt: prompt,
                    reference: reference,
                    enhanceNote: nil
                )
            }
            UserDefaults.standard.removeObject(forKey: Self.sessionFileKey)
            askOutputFileURL = nil
            askOutputTabID = nil
            sessionStatusPrefix = "Previous session file was missing. "
            return prepareNewSession(prompt: prompt, reference: reference, workspace: workspace)
        case .enhanceReply(let reference):
            guard let tab = resolveAskOutputTab(in: workspace) else {
                isBusy = false
                status = "No Ask Forth session file — Ask first."
                return false
            }
            let note = AskForthSession.agentEnhanceNote(from: agentTranscript)
            return prepareContinuation(
                tab: tab,
                workspace: workspace,
                newPrompt: nil,
                reference: reference,
                enhanceNote: note
            )
        }
    }

    private func prepareNewSession(prompt: String, reference: String?, workspace: WorkspaceModel) -> Bool {
        let header = makeSessionHeader(
            entries: [.prompt(text: prompt, reference: reference)],
            sessionReference: reference
        )
        let initial = AskForthSession.renderPrefix(header: header, archive: "")
        guard let tab = workspace.createAskForthFile(initialText: initial) else {
            isBusy = false
            status = "Could not create AskForth file."
            return false
        }
        rememberSession(tab)
        pendingSessionPreface = ""
        pendingReferencePath = reference
        sessionSnapshot = nil
        status = "Streaming into \(tab.fileURL?.lastPathComponent ?? "AskForth")…"
        return true
    }

    private func prepareContinuation(
        tab: EditorTab,
        workspace: WorkspaceModel,
        newPrompt: String?,
        reference: String?,
        enhanceNote: String?
    ) -> Bool {
        let previous = tab.text
        let parsed = AskForthSession.parse(previous)
        var entries = parsed.entries
        if let newPrompt {
            pendingSessionPreface = AskForthSession.modelPreface(
                entries: parsed.entries,
                previousLive: parsed.live
            )
            entries.append(.prompt(text: newPrompt, reference: reference))
        } else {
            pendingSessionPreface = ""
        }
        if let enhanceNote {
            entries.append(.note(enhanceNote))
        }
        let sessionRef = newPrompt != nil ? reference : (reference ?? lastReference(in: parsed.entries))
        let archive = AskForthSession.combineArchive(
            existing: parsed.archive,
            added: AskForthSession.archiveLive(parsed.live)
        )
        let header = makeSessionHeader(entries: entries, sessionReference: sessionRef)
        let prefix = AskForthSession.renderPrefix(header: header, archive: archive)
        sessionSnapshot = previous
        // Only an open editor tab is sent. The header can still record an older path.
        pendingReferencePath = reference
        tab.text = prefix
        tab.isDirty = true
        workspace.selectedTabID = tab.id
        rememberSession(tab)
        _ = workspace.saveTab(tab)
        status = "Streaming into \(tab.fileURL?.lastPathComponent ?? "AskForth")…"
        return true
    }

    private func makeSessionHeader(entries: [AskForthSession.Entry], sessionReference: String?) -> String {
        let profile = profiles.first(where: { $0.id == activeProfileID })
            ?? AskForthLLMSettings.activeProfile
        let temperature = String(format: "%.2f", profile.temperature)
        return AskForthSession.renderHeader(
            model: modelName,
            temperature: temperature,
            settingLines: sessionSettingLines(),
            sessionReference: sessionReference,
            entries: entries
        )
    }

    private func sessionSettingLines() -> [String] {
        var lines: [String] = []
        let profile = profiles.first(where: { $0.id == activeProfileID })
            ?? AskForthLLMSettings.activeProfile
        lines.append("Context window: \(profile.contextTokens)")
        if includeLibraryContext {
            let settings = ForthLibraryRAGSettings.load()
            lines.append("Include Library context: on")
            lines.append("Library: \(settings.folderPath)")
            lines.append("Retrieve mode: \(settings.retrieveMode.displayName)")
            lines.append("Max snippets: \(settings.maxSnippets)")
            lines.append("Context lines: \(settings.contextLines)")
            lines.append("Max characters: \(settings.maxChars)")
        }
        if fetchURLsInPrompt {
            lines.append("Fetch URLs in Prompt: on")
        }
        if includeWebSearch {
            lines.append("Include web search: on")
        }
        if useToolAgent {
            lines.append("Tool agent: on")
        }
        return lines
    }

    private func lastReference(in entries: [AskForthSession.Entry]) -> String? {
        for entry in entries.reversed() {
            if case .prompt(_, let reference) = entry, let reference, !reference.isEmpty {
                return reference
            }
        }
        return nil
    }

    private func rememberSession(_ tab: EditorTab) {
        askOutputTabID = tab.id
        if let url = tab.fileURL?.standardizedFileURL {
            askOutputFileURL = url
            UserDefaults.standard.set(url.path, forKey: Self.sessionFileKey)
        }
        askStreamBodyStart = (tab.text as NSString).length
    }

    private func referenceContextBlock(in workspace: WorkspaceModel, path: String?) -> String {
        guard let path, !path.isEmpty else { return "" }
        let tab = workspace.tabs.first { $0.fileURL?.standardizedFileURL.path == path }
        let contents: String?
        if let tab {
            contents = tab.text
        } else {
            contents = try? String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8)
        }
        return AskForthSession.referenceContextBlock(path: path, contents: contents)
    }

    private func currentSessionText(in workspace: WorkspaceModel) -> String? {
        if let id = askOutputTabID, let tab = workspace.tab(id: id) {
            return tab.text
        }
        guard let url = askOutputFileURL, FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    private func syncReplyFromSession(in workspace: WorkspaceModel) {
        guard let text = currentSessionText(in: workspace) else { return }
        let live = AskForthSession.parse(text).live.trimmingCharacters(in: .whitespacesAndNewlines)
        if !live.isEmpty {
            reply = live
        }
    }

    /// Write the sanitized reply into the live section and drop the rollback snapshot.
    private func commitLiveReply(_ text: String, in workspace: WorkspaceModel) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            recoverReplyIfEmpty(in: workspace)
            return
        }
        reply = AskForthSession.sanitizeLive(trimmed, closeParens: true)
        writeLiveStreamBody(reply, in: workspace, closeParens: false)
        if let tab = resolveAskOutputTab(in: workspace) {
            _ = workspace.saveTab(tab)
        }
        sessionSnapshot = nil
    }

    /// Put the previous session text back when this turn produced no reply.
    private func recoverReplyIfEmpty(in workspace: WorkspaceModel) {
        guard reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if sessionSnapshot != nil {
            restoreSessionSnapshot(in: workspace)
            return
        }
        if let text = currentSessionText(in: workspace) {
            reply = AskForthSession.parse(text).live.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func restoreSessionSnapshot(in workspace: WorkspaceModel) {
        guard let snap = sessionSnapshot else { return }
        if let id = askOutputTabID, let tab = workspace.tab(id: id) {
            tab.text = snap
            tab.isDirty = true
            _ = workspace.saveTab(tab)
        } else if let url = askOutputFileURL {
            try? snap.write(to: url, atomically: true, encoding: .utf8)
        }
        reply = AskForthSession.parse(snap).live.trimmingCharacters(in: .whitespacesAndNewlines)
        sessionSnapshot = nil
        askStreamBodyStart = nil
    }

    private func finishInterruptedStream(in workspace: WorkspaceModel, cancelled: Bool, error: Error?) {
        if reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            recoverReplyIfEmpty(in: workspace)
        } else {
            commitLiveReply(reply, in: workspace)
        }
        askStreamBodyStart = nil
        pendingSessionPreface = ""
        isBusy = false
        if cancelled {
            status = "Stopped."
            return
        }
        if let error {
            status = statusForCaughtError(error)
        }
    }

    private static func systemPrompt(fileName: String?, continuing: Bool) -> String {
        var lines = [
            "You are a Forth programming assistant for EditForth / 64Forth (ANS-style ITC Forth on Apple Silicon).",
            "Prefer idiomatic Forth: clear stack comments ( a b -- c ), short words, and explanations that match classic Forth style.",
            "When asked for code, return Forth source the user can paste inside a ```forth fenced block when possible.",
            "Never invent ANS or 64Forth word names, stack effects, or APIs. If you are unsure, say so and suggest looking in System/Reference or forth-standard.org.",
            "Stack comments must match real argument order (e.g. c-addr u for strings, not a single invented string cell).",
            "Line comments use one backslash and run to the end of the line. Never start a word with \\\\, \\S, or \\\\S. Those swallow or stop the rest of an INCLUDE. Close every ( comment with ). Do not wrap Forth to a fixed column width.",
            "Be concise."
        ]
        if continuing {
            lines.append("This is a continuation of an Ask Forth session. The host owns the file header and comments out earlier drafts. Reply with only the new live Forth for the latest request. Do not repeat the header, the prompt log, or earlier drafts.")
        }
        if let fileName, !fileName.isEmpty {
            lines.append("The user has a read-only reference file open: \(fileName). Do not write that file. Put suggestions only in your reply.")
        }
        return lines.joined(separator: "\n")
    }

    /// Extra system rules after Library search (Phase 3 grounding).
    private static func libraryGroundingAddon(searched: Bool, hasHits: Bool) -> String {
        guard searched else { return "" }
        if hasHits {
            return """

            Library context was retrieved for this request (Sample and/or Forth-2012 Reference excerpts).
            Ground your answer in that context: use the cited stack effects, word names, and sample idioms.
            Prefer quoting or paraphrasing stack diagrams from Reference (e.g. COMPARE, MOVE, TYPE) over guessing.
            If the user asks for something not supported by the Library excerpts, say “Not found in the provided Library context” (or similar) for that part, and label any extra suggestion clearly as unverified.
            When citing, mention path:line from the Library headers when helpful.
            """
        }
        return """

            Library search ran but returned no matching excerpts for this prompt.
            Do not invent standard stack effects or Library APIs. Say that Library context had no hits, give only carefully labeled general Forth advice, and prefer “I don’t know / not in Library” over fabricating 64Forth words.
            """
    }

    private static let libraryUserReminderWithHits = """
    Instructions for this answer:
    - Use the Library context above as the source of truth for word names and stack effects.
    - If a needed fact is missing from that context, say it is not in the provided sources instead of inventing it.
    - Put loadable Forth in a ```forth block when you provide code.
    """

    private static let libraryUserReminderNoHits = """
    Instructions for this answer:
    - Library search found no excerpts for this prompt.
    - Do not invent ANS/64Forth stack effects or APIs. Prefer saying you lack Library backing over fabricating a solution.
    """
}

// MARK: - EditorTab helpers

extension EditorTab {
    /// Selected text, or nil when the selection is empty.
    func selectedText() -> String? {
        let ns = text as NSString
        let sel = Self.clamped(selection, in: ns)
        guard sel.length > 0 else { return nil }
        return ns.substring(with: sel)
    }

    /// A few lines around `range` for caret-only Ask.
    func contextWindow(around range: NSRange, radiusLines: Int) -> String {
        let ns = text as NSString
        guard ns.length > 0 else { return "" }
        let sel = Self.clamped(range, in: ns)
        let caret = min(sel.location, ns.length)
        var lineStart = 0
        var lineEnd = 0
        var lineContentsEnd = 0
        ns.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &lineContentsEnd, for: NSRange(location: caret, length: 0))

        var start = lineStart
        var up = 0
        while up < radiusLines, start > 0 {
            let before = start - 1
            ns.getLineStart(&start, end: &lineEnd, contentsEnd: &lineContentsEnd, for: NSRange(location: before, length: 0))
            up += 1
        }
        var end = lineEnd
        var down = 0
        while down < radiusLines, end < ns.length {
            ns.getLineStart(&lineStart, end: &end, contentsEnd: &lineContentsEnd, for: NSRange(location: end, length: 0))
            down += 1
        }
        return ns.substring(with: NSRange(location: start, length: end - start))
    }

    func replaceSelection(with replacement: String) {
        let ns = text as NSString
        let sel = Self.clamped(selection, in: ns)
        let updated = ns.replacingCharacters(in: sel, with: replacement)
        text = updated
        let newLoc = sel.location + (replacement as NSString).length
        selection = NSRange(location: newLoc, length: 0)
        isDirty = true
    }

    private static func clamped(_ range: NSRange, in ns: NSString) -> NSRange {
        let loc = min(max(0, range.location), ns.length)
        let maxLen = ns.length - loc
        let len = min(max(0, range.length), maxLen)
        return NSRange(location: loc, length: len)
    }
}
