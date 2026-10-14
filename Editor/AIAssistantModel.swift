//
//  AIAssistantModel.swift
//  EditForth
//
//  Ask-Forth panel state: prompt → local LLM → AskForth-N.fth in the editor,
//  then optional headless 64Forth --agent eval and Fix-from-Agent append.
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
    /// UTF-16 offset in the AskForth tab where the current streamed body starts (wrap target).
    private var askStreamBodyStart: Int?

    private static let askFileWrapWidth = 80

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
        askStreamBodyStart = nil
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
        let userPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userPrompt.isEmpty else {
            status = "Enter a question or capture editor context first."
            return
        }
        // New question: drop the previous Eval transcript so Show Agent Transcript is not stale.
        agentTranscript = ""
        runCompletion(
            workspace: workspace,
            system: Self.systemPrompt(fileName: nil),
            user: userPrompt,
            ragQuery: userPrompt,
            destination: .newAskFile(prompt: userPrompt),
            busyStatus: "Asking \(client.providerName) (\(modelName))…",
            doneStatus: "Done."
        )
    }

    /// Send prior reply + agent transcript back to the model; append Fix into the Ask file.
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

        var parts: [String] = [
            "The previous Forth answer was evaluated with a headless 64Forth --agent process.",
            "Fix the Forth so it works on EditForth / 64Forth (ANS-style ITC). Prefer a single ```forth fenced block with the corrected source. Briefly note what you changed."
        ]
        if !priorPrompt.isEmpty {
            parts.append("Original request / context:\n\(priorPrompt)")
        }
        if !priorReply.isEmpty {
            parts.append("Previous answer:\n\(priorReply)")
        }
        parts.append("Agent transcript (exit status is in the status line if shown):\n\(transcript)")

        let ragQuery = [priorPrompt, priorReply, transcript].joined(separator: "\n")
        let fileHint = askOutputFileName ?? workspace.selectedTab?.fileURL?.lastPathComponent
        runCompletion(
            workspace: workspace,
            system: Self.systemPrompt(fileName: fileHint)
                + "\nYou are correcting Forth that failed or needs improvement after a real kernel eval."
                + " Prefer Library/Reference stack effects and Sample idioms when they match."
                + " Do not claim a fix unless the change is concrete; keep stack comments accurate.",
            user: parts.joined(separator: "\n\n"),
            ragQuery: ragQuery,
            destination: .appendFix,
            busyStatus: "Asking \(client.providerName) to enhance reply…",
            doneStatus: "Agent Enhanced Reply appended."
        )
    }

    private enum StreamDestination {
        case newAskFile(prompt: String)
        case appendFix
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
                }
                return
            }

            // Prepare editor destination before streaming.
            let prepared: Bool = await MainActor.run {
                switch destination {
                case .newAskFile(let askPrompt):
                    let header = self.askFileHeader(prompt: askPrompt)
                    guard let tab = workspace.createAskForthFile(initialText: header) else {
                        self.isBusy = false
                        self.status = "Could not create AskForth file."
                        return false
                    }
                    self.askOutputTabID = tab.id
                    self.askOutputFileURL = tab.fileURL
                    self.askStreamBodyStart = (tab.text as NSString).length
                    self.status = "Streaming into \(tab.fileURL?.lastPathComponent ?? "AskForth")…"
                    return true
                case .appendFix:
                    guard let tab = self.resolveAskOutputTab(in: workspace) else {
                        self.isBusy = false
                        self.status = "No AskForth file to append — Ask first."
                        return false
                    }
                    workspace.selectedTabID = tab.id
                    tab.appendStreamingText("\n\nAgent Enhanced Reply\n\n")
                    self.askStreamBodyStart = (tab.text as NSString).length
                    self.status = "Streaming Agent Enhanced Reply into \(tab.fileURL?.lastPathComponent ?? "AskForth")…"
                    return true
                }
            }
            guard prepared else { return }

            var contextPrefix = ""
            var contextNote = ""

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
                                self.writeWrappedStreamBody(self.reply, in: workspace)
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
                            self.writeWrappedStreamBody(self.reply, in: workspace)
                        }
                    }
                }
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        self.reply = trimmed
                    }
                    self.writeWrappedStreamBody(self.reply, in: workspace)
                    if let tab = self.resolveAskOutputTab(in: workspace) {
                        _ = workspace.saveTab(tab)
                    }
                    self.askStreamBodyStart = nil
                    self.isBusy = false
                    let fileNote = self.askOutputFileName.map { " · \($0)" } ?? ""
                    self.status = doneStatus + fileNote + contextNote
                }
            } catch {
                await MainActor.run {
                    if !self.reply.isEmpty {
                        self.writeWrappedStreamBody(self.reply, in: workspace)
                    }
                    if let tab = self.resolveAskOutputTab(in: workspace) {
                        _ = workspace.saveTab(tab)
                    }
                    self.askStreamBodyStart = nil
                    // stop() already cleared busy + status; don't overwrite with a network error.
                    if Task.isCancelled || error is CancellationError {
                        if self.isBusy {
                            self.isBusy = false
                            self.status = "Stopped."
                        }
                        return
                    }
                    self.isBusy = false
                    self.status = self.statusForCaughtError(error)
                }
            }
        }
        handle.task = job
        attachJob(job)
    }

    /// Replace the current streamed body in the AskForth tab with `body` wrapped at 80 columns.
    /// Keeps `reply` unwrapped for Eval; only the file/editor buffer is wrapped.
    private func writeWrappedStreamBody(_ body: String, in workspace: WorkspaceModel) {
        guard let tab = resolveAskOutputTab(in: workspace),
              let start = askStreamBodyStart else { return }
        let ns = tab.text as NSString
        let safeStart = min(max(0, start), ns.length)
        let prefix = ns.substring(to: safeStart)
        let wrapped = Self.wrapToWidth(body, width: Self.askFileWrapWidth)
        tab.text = prefix + wrapped
        tab.isDirty = true
        // Do not move selection to end on every chunk — that forces the editor to
        // fight the user when they scroll up to read while Ask / Enhance streams.
    }

    /// Word-wrap each existing line to `width` columns (hard-break only if a word is longer).
    private static func wrapToWidth(_ text: String, width: Int) -> String {
        guard width > 0 else { return text }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var out: [String] = []
        out.reserveCapacity(lines.count)
        for line in lines {
            out.append(contentsOf: wrapSingleLine(String(line), width: width))
        }
        return out.joined(separator: "\n")
    }

    private static func wrapSingleLine(_ line: String, width: Int) -> [String] {
        if line.isEmpty { return [""] }
        if line.count <= width { return [line] }

        var result: [String] = []
        var remaining = Substring(line)
        while remaining.count > width {
            let end = remaining.index(remaining.startIndex, offsetBy: width)
            let window = remaining[..<end]
            if let space = window.lastIndex(of: " "), space > remaining.startIndex {
                result.append(String(remaining[..<space]))
                remaining = remaining[remaining.index(after: space)...]
            } else {
                result.append(String(window))
                remaining = remaining[end...]
            }
        }
        result.append(String(remaining))
        return result
    }

    private func resolveAskOutputTab(in workspace: WorkspaceModel) -> EditorTab? {
        if let id = askOutputTabID, let tab = workspace.tab(id: id) {
            return tab
        }
        if let url = askOutputFileURL {
            let tab = workspace.openURL(url, viewMode: false, line: nil)
            askOutputTabID = tab?.id
            return tab
        }
        return nil
    }

    /// Headless eval of the latest Ask/Fix segment, then Fix from Agent (append improved answer).
    func evalReplyAndAgentFix(workspace: WorkspaceModel) {
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

    /// F-PC block comment (`\\` … `{`) with Ask settings and the user Prompt.
    private func askFileHeader(prompt: String) -> String {
        let profile = profiles.first(where: { $0.id == activeProfileID })
            ?? AskForthLLMSettings.activeProfile
        let model = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        let temperature = String(format: "%.2f", profile.temperature)

        var lines: [String] = [
            "\\\\ Ask Forth",
            "\\ Model: \(model.isEmpty ? "(none)" : model)",
            "\\ Temperature: \(temperature)",
        ]

        if includeLibraryContext {
            let settings = ForthLibraryRAGSettings.load()
            lines.append("\\ Include Library context: on")
            lines.append("\\ Library: \(settings.folderPath)")
            lines.append("\\ Retrieve mode: \(settings.retrieveMode.displayName)")
            lines.append("\\ Max snippets: \(settings.maxSnippets)")
            lines.append("\\ Context lines: \(settings.contextLines)")
            lines.append("\\ Max characters: \(settings.maxChars)")
        }
        if fetchURLsInPrompt {
            lines.append("\\ Fetch URLs in Prompt: on")
        }
        if includeWebSearch {
            lines.append("\\ Include web search: on")
        }
        if useToolAgent {
            lines.append("\\ Tool agent: on")
        }

        lines.append("\\")
        lines.append("\\ Prompt:")
        for raw in prompt.split(separator: "\n", omittingEmptySubsequences: false) {
            lines.append("\\ \(raw)")
        }
        lines.append("{")
        lines.append("")
        lines.append("")
        return lines.joined(separator: "\n")
    }

    private static func systemPrompt(fileName: String?) -> String {
        var lines = [
            "You are a Forth programming assistant for EditForth / 64Forth (ANS-style ITC Forth on Apple Silicon).",
            "Prefer idiomatic Forth: clear stack comments ( a b -- c ), short words, and explanations that match classic Forth style.",
            "When asked for code, return Forth source the user can paste inside a ```forth fenced block when possible.",
            "Never invent ANS or 64Forth word names, stack effects, or APIs. If you are unsure, say so and suggest looking in Library/Reference or forth-standard.org.",
            "Stack comments must match real argument order (e.g. c-addr u for strings, not a single invented string cell).",
            "Be concise."
        ]
        if let fileName, !fileName.isEmpty {
            lines.append("The user is editing: \(fileName).")
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
