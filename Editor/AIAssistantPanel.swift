//
//  AIAssistantPanel.swift
//  EditForth
//
//  Trailing Ask-Forth inspector. Replies stream into one AskForth-N.fth
//  session until New session. Agent transcript is optional / collapsed.
//

import SwiftUI
import AppKit

struct AIAssistantPanel: View {
    @ObservedObject var model: AIAssistantModel
    @EnvironmentObject private var workspace: WorkspaceModel

    /// Same key as View → Ask Forth / tab-bar inspector button.
    @AppStorage("showAIAssistant") private var showAIAssistant = false
    /// Trailing inspector (true) vs floating Ask Forth window (false).
    @AppStorage("askForthDocked") private var askForthDocked = true

    /// Prompt TextEditor height only — agent pane fills whatever is left below the splitter.
    @AppStorage("aiPromptEditorHeight") private var storedPromptHeight = 40.0
    @State private var promptHeight = 40.0
    @State private var promptDragStart: CGFloat?
    @State private var showLibrarySettings = false
    @State private var showModelsSettings = false
    /// Last path component of the Library RAG folder (Library button title).
    @State private var libraryFolderLeaf = ""
    /// Full Library RAG folder path (Library button tooltip).
    @State private var libraryFolderPath = ""

    /// About two lines of monospaced body text.
    private static let promptMinHeight: CGFloat = 36
    private static let promptMaxHeight: CGFloat = 180
    private static let promptDefaultHeight: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            chatSection
                .frame(maxWidth: .infinity, alignment: .topLeading)

            AIAssistantVSplitter(
                onDrag: { translationY in
                    // Drag down grows the prompt; drag up shrinks it (agent takes the rest).
                    let base = promptDragStart ?? promptHeight
                    if promptDragStart == nil { promptDragStart = promptHeight }
                    promptHeight = min(
                        max(base + translationY, Self.promptMinHeight),
                        Self.promptMaxHeight
                    )
                },
                onEnd: {
                    promptDragStart = nil
                    storedPromptHeight = Double(promptHeight)
                }
            )

            agentSection
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            // Older builds stored ~80; clamp down to a two-line default when still large.
            let stored = storedPromptHeight
            let initial = stored > 60 ? Self.promptDefaultHeight : stored
            promptHeight = min(max(initial, Self.promptMinHeight), Self.promptMaxHeight)
            if stored != Double(promptHeight) {
                storedPromptHeight = Double(promptHeight)
            }
            refreshLibraryFolderLeaf()
            model.reloadProfilesFromSettings()
            model.prepareAskForthEnvironment()
            model.detachSessionIfDisplaced(in: workspace)
        }
        .onChange(of: sessionTabPath) { _, _ in
            model.detachSessionIfDisplaced(in: workspace)
        }
        .onChange(of: showLibrarySettings) { _, isOpen in
            if !isOpen {
                refreshLibraryFolderLeaf()
                model.prepareAskForthEnvironment()
            }
        }
        .onChange(of: showModelsSettings) { _, isOpen in
            if !isOpen {
                model.reloadProfilesFromSettings()
                model.prepareAskForthEnvironment()
            }
        }
        .onChange(of: model.includeLibraryContext) { _, _ in
            model.prepareAskForthEnvironment()
        }
        .onChange(of: model.activeProfileID) { _, _ in
            Task { await model.refreshSetupBanner() }
        }
        .sheet(isPresented: $showLibrarySettings) {
            LibraryRAGSettingsSheet()
        }
        .sheet(isPresented: $showModelsSettings) {
            AskForthModelsSettingsSheet(model: model)
        }
    }

    private func refreshLibraryFolderLeaf() {
        let path = ForthLibraryRAGSettings.load().folderPath
        libraryFolderPath = path
        let leaf = URL(fileURLWithPath: path, isDirectory: true).lastPathComponent
        libraryFolderLeaf = leaf.isEmpty ? "—" : leaf
    }

    /// Open `~/Documents/EditForth/AskForth` in Finder (create if missing).
    private func openAskForthOutputFolder() {
        let dir = ForthMenuSupport.userTreeURL.appendingPathComponent("AskForth", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        NSWorkspace.shared.open(dir)
    }

    // MARK: - Chat (prompt only — reply lives in AskForth-N.fth)

    private var chatSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Ask Forth")
                    .font(.headline)
                askForthInfoHint(
                    """
                    Type a prompt and click Ask. The reply is written to Documents/EditForth/AskForth/AskForth-N.fth and opened in the editor. Later Asks keep that same file: earlier drafts stay as line comments, and only the newest section is live Forth. New session keeps the old file and starts a new one on the next Ask. Renaming, moving, or Save As of that file also starts a new session; the next Ask creates a new file in the AskForth folder.

                    Reference is an optional read-only file already open in the editor. Ask Forth never writes that file. Changing it does not start a new session.

                    Agent Enhance Reply runs the latest live section in a headless 64Forth --agent, then replaces that live section. Use INCLUDE in the status strip when you want the session file in the live console. Library defaults to Library/Sample.

                    Local Ask needs Ollama (https://ollama.com) running and a chat model (default: ollama pull gemma4:e4b). Library Hybrid/Semantic also needs nomic-embed-text — EditForth downloads that automatically when Ollama is available and builds the Library index in the background.

                    Pick a saved model profile below (Ollama, SpaceXAI, local mlx, …). Use Models… to add or edit names, base URLs, and per-profile API keys.
                    """
                )
                Spacer()
                Text(model.providerLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if askForthDocked {
                    Button("Undock") {
                        askForthDocked = false
                    }
                    .font(.caption)
                    .help("Open Ask Forth in a floating window.")
                }
                Button {
                    showAIAssistant = false
                } label: {
                    Image(systemName: "sidebar.trailing")
                        .imageScale(.medium)
                }
                .buttonStyle(.borderless)
                .help("Hide Ask Forth (⌥⌘A)")
                .accessibilityLabel("Hide Ask Forth")
            }

            if !model.setupBanner.isEmpty {
                Text(model.setupBanner)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .accessibilityLabel("Ask Forth setup")
            }

            HStack(spacing: 6) {
                Text("Model")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("", selection: Binding(
                    get: { model.activeProfileID },
                    set: { model.selectProfile(id: $0) }
                )) {
                    ForEach(model.profiles) { profile in
                        Text(profile.name).tag(profile.id)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .help("Saved Ask Forth profiles. Switch anytime; details stay in Models….")
                Button("Models…") {
                    showModelsSettings = true
                }
                .font(.caption)
                .help("Add, rename, or edit model profiles (provider, model id, Base URL, API key).")
            }
            Text(model.activeProfileCaption)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .help("Active profile provider and endpoint / model summary.")

            HStack(spacing: 8) {
                Toggle("Include Library context", isOn: $model.includeLibraryContext)
                    .font(.caption)
                    .help("Leave on for everyday Ask. Pulls matching .fth/.txt/.md/.swift from Library… (default Sample) plus always Library/Reference (Forth 2012). Point Library… at the EditForth project for app/UI questions. Best when you want answers that match local samples, docs, and source.")
                    .onChange(of: model.includeLibraryContext) { _, _ in
                        model.persistLibraryRAG()
                    }
                Button {
                    showLibrarySettings = true
                } label: {
                    Text(libraryFolderLeaf.isEmpty ? "Library…" : "\(libraryFolderLeaf)…")
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .font(.caption)
                .help(
                    libraryFolderPath.isEmpty
                        ? "Choose which Library folder to search, and tweak snippet count / context lines / max characters."
                        : "Library folder: \(libraryFolderPath)\nClick to change folder or snippet limits."
                )
                Spacer(minLength: 0)
            }

            Toggle("Fetch URLs in Prompt", isOn: $model.fetchURLsInPrompt)
                .font(.caption)
                .help("Leave on when the Prompt has http(s) links, or for word lookups (`DUP`, “what does OPEN-FILE”) so forth-standard.org can auto-boost. Turn off to stay offline aside from Ollama. Ignored while Tool agent is on.")
                .onChange(of: model.fetchURLsInPrompt) { _, _ in
                    model.persistURLFetch()
                }

            Toggle("Include web search", isOn: $model.includeWebSearch)
                .font(.caption)
                .help("Turn on only when Library isn’t enough (obscure topics, “how do others do X”). Searches DuckDuckGo Lite and adds top hits — default off, uses the network. Disabled while Tool agent is on (the model can call web_search itself).")
                .onChange(of: model.includeWebSearch) { _, _ in
                    model.persistWebSearch()
                }
                .disabled(model.useToolAgent)

            Toggle("Tool agent", isOn: $model.useToolAgent)
                .font(.caption)
                .help("Turn on when you want the model to decide to search, fetch a URL, or dig in Library before answering. Slower; needs a tools-capable model (e.g. gemma4:e4b). Use Show Agent Transcript to see tool steps. Default off — skip for ordinary Ask.")
                .onChange(of: model.useToolAgent) { _, _ in
                    model.persistToolAgent()
                }

            HStack(spacing: 6) {
                Text("Session")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(model.askOutputFileName ?? "New on next Ask")
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(model.askOutputFileURL?.path ?? "The next Ask creates AskForth-N.fth.")
                Spacer(minLength: 4)
                Button("New session") {
                    model.startNewSession()
                }
                .font(.caption)
                .disabled(model.isBusy || model.askOutputFileURL == nil)
                .help("Keep this AskForth file and start the next Ask in a new file. Does not delete the previous file.")
            }

            HStack(spacing: 6) {
                Text("Reference")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Reference", selection: referenceSelection) {
                    Text("(none)").tag("")
                    ForEach(referenceChoices) { choice in
                        Text(choice.label).tag(choice.path)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
                .help("Read-only file already open in the editor. Ask Forth sends it as context and never writes it. Changing this does not start a new session or rewrite earlier prompts.")
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("Prompt")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Button("Output") {
                        openAskForthOutputFolder()
                    }
                    .font(.caption)
                    .help("Show the Ask Forth output folder. Ask Forth result files accumulate and should be cleaned up occasionally.")
                }
                TextEditor(text: $model.prompt)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .frame(height: promptHeight)
                    .askForthBoxChrome()
            }
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    if let name = model.askOutputFileName {
                        Text("Output: \(name)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(model.status.isEmpty ? " " : model.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if model.isBusy {
                    Button("Stop") {
                        model.stop()
                    }
                    .help("Cancel the current Ask, Enhance, or headless agent run. Stops EditForth’s request; unload the model or stop the local server if generation continues there.")
                    .keyboardShortcut(.cancelAction)
                }
                Button(askButtonTitle) {
                    model.ask(workspace: workspace)
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(model.isBusy || model.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
    }

    /// Path of the open session tab. Changes when that tab is renamed or Save As'd.
    private var sessionTabPath: String {
        guard let id = model.askOutputTabID,
              let tab = workspace.tab(id: id) else { return "" }
        return tab.fileURL?.standardizedFileURL.path ?? ""
    }

    private struct AskForthReferenceChoice: Identifiable {
        var id: String { path }
        var path: String
        var label: String
    }

    /// Open file tabs only. The session file is excluded. Duplicate names show the parent folder.
    private var referenceChoices: [AskForthReferenceChoice] {
        let session = model.askOutputFileURL?.standardizedFileURL.path
        var rows: [(path: String, leaf: String)] = []
        var seen = Set<String>()
        for tab in workspace.tabs {
            guard let url = tab.fileURL?.standardizedFileURL else { continue }
            let path = url.path
            if path == session || seen.contains(path) { continue }
            seen.insert(path)
            rows.append((path, url.lastPathComponent))
        }
        var counts: [String: Int] = [:]
        for row in rows {
            counts[row.leaf, default: 0] += 1
        }
        return rows.map { row in
            let label: String
            if counts[row.leaf, default: 0] > 1 {
                let parent = URL(fileURLWithPath: row.path).deletingLastPathComponent().lastPathComponent
                label = parent.isEmpty ? row.path : "\(parent)/\(row.leaf)"
            } else {
                label = row.leaf
            }
            return AskForthReferenceChoice(path: row.path, label: label)
        }
    }

    private var referenceSelection: Binding<String> {
        Binding(
            get: {
                let path = model.referenceFilePath
                guard !path.isEmpty else { return "" }
                let standard = URL(fileURLWithPath: path).standardizedFileURL.path
                if referenceChoices.contains(where: { $0.path == standard }) { return standard }
                return ""
            },
            set: { newValue in
                model.referenceFilePath = newValue
                model.persistReferenceFile()
            }
        )
    }

    /// Compact help affordance beside a section title (hover for the full tip).
    private func askForthInfoHint(_ text: String) -> some View {
        Image(systemName: "info.circle")
            .imageScale(.medium)
            .foregroundStyle(.secondary)
            .help(text)
            .accessibilityLabel("Help")
            .accessibilityHint(text)
    }

    private var askButtonTitle: String {
        if !model.isBusy { return "Ask" }
        if model.reply.isEmpty { return "Asking…" }
        return "Streaming…"
    }

    private var enhanceButtonTitle: String {
        guard model.isBusy else { return "Agent Enhance Reply" }
        let s = model.status.lowercased()
        if s.contains("enhanc") { return "Enhancing…" }
        if s.contains("agent") { return "Evaluating…" }
        return "Enhancing…"
    }

    // MARK: - Agent

    private var agentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text("64Forth Agent")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                askForthInfoHint(
                    "Agent Enhance Reply evaluates the latest live Forth in a headless 64Forth --agent (Autoload on), then asks the model for an improved answer. The previous live section stays in the file as line comments. Only the new section is loaded by INCLUDE. The transcript stays in this panel. Ask Forth does not modify the Reference file."
                )
            }

            HStack(alignment: .center, spacing: 10) {
                Button(enhanceButtonTitle) {
                    model.evalReplyAndAgentFix(workspace: workspace)
                }
                .disabled(model.isBusy || model.reply.isEmpty)
                .help("Run the latest live section in a headless 64Forth --agent (Autoload on), then replace that section with an improved answer. Earlier drafts stay as line comments. Does not type into the live console — use INCLUDE on the session file when you want it loaded.")

                if model.isBusy {
                    Button("Stop") {
                        model.stop()
                    }
                    .help("Cancel the current Ask, Enhance, or headless agent run.")
                }

                Toggle("Show Agent Transcript", isOn: $model.showAgentTranscript)
                    .font(.caption)
                    .help("Show the headless --agent eval output and Tool agent steps (→ web_search / ← …). Turn on when debugging Enhance or Tool agent; leave off to save panel space.")
                    .onChange(of: model.showAgentTranscript) { _, _ in
                        model.persistShowAgentTranscript()
                    }
            }

            if model.showAgentTranscript {
                Text("Agent transcript")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ScrollView {
                    Text(model.agentTranscript.isEmpty ? " " : model.agentTranscript)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .padding(6)
                .askForthBoxChrome()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !model.agentTranscript.isEmpty {
                Text("Transcript ready (\(model.agentTranscript.count) chars) — turn on Show Agent Transcript to read it.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Model profiles sheet

private struct AskForthModelsSettingsSheet: View {
    @ObservedObject var model: AIAssistantModel
    @Environment(\.dismiss) private var dismiss

    @State private var profiles: [AskForthModelProfile] = []
    @State private var selectedID: UUID?
    @State private var revealAPIKey = false
    @State private var draftKey = ""
    @State private var keyStatus = ""
    @State private var formError = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Ask Forth models")
                .font(.title2.weight(.semibold))

            Text("Save named profiles for Ollama and OpenAI-compatible endpoints. The Ask Forth panel picker switches among these without retyping Base URL or model id. Each OpenAI-compatible profile has its own Keychain API key.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Profiles")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    List(selection: $selectedID) {
                        ForEach(profiles) { profile in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.name)
                                    .font(.body)
                                Text(profile.caption)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .tag(profile.id)
                        }
                    }
                    .frame(minWidth: 200, maxWidth: 240, minHeight: 220)
                    .listStyle(.bordered)

                    HStack(spacing: 8) {
                        Button("Add") { addProfile() }
                        Button("Duplicate") { duplicateSelected() }
                            .disabled(selectedID == nil)
                        Button("Delete") { deleteSelected() }
                            .disabled(selectedID == nil || profiles.count <= 1)
                    }
                    .font(.caption)
                }

                VStack(alignment: .leading, spacing: 10) {
                    if let binding = selectedBinding {
                        profileEditor(binding)
                    } else {
                        Text("Select a profile to edit.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            if !formError.isEmpty {
                Text(formError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Done") {
                    commitAndDismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 4)
        }
        .padding(20)
        // Tall enough for OpenAI fields (Base URL + API key + Temperature) with room to grow.
        .frame(width: 720, height: 600)
        .onAppear {
            profiles = AskForthLLMSettings.loadProfiles()
            selectedID = model.activeProfileID
            if selectedID == nil {
                selectedID = profiles.first?.id
            }
            refreshKeyUI()
        }
        .onChange(of: selectedID) { _, _ in
            draftKey = ""
            revealAPIKey = false
            refreshKeyUI()
            formError = ""
        }
    }

    private var selectedBinding: Binding<AskForthModelProfile>? {
        guard let id = selectedID,
              let idx = profiles.firstIndex(where: { $0.id == id }) else { return nil }
        return $profiles[idx]
    }

    @ViewBuilder
    private func profileEditor(_ binding: Binding<AskForthModelProfile>) -> some View {
        let profile = binding.wrappedValue
        VStack(alignment: .leading, spacing: 10) {
            labeledField("Name") {
                TextField("Profile name", text: binding.name)
                    .textFieldStyle(.roundedBorder)
            }
            labeledField("Provider") {
                Picker("", selection: binding.provider) {
                    ForEach(AskForthLLMProvider.allCases) { p in
                        Text(p.menuTitle).tag(p)
                    }
                }
                .labelsHidden()
                .help(profile.provider.help)
            }
            labeledField("Model") {
                TextField(
                    profile.provider == .ollama
                        ? AskForthLLMSettings.defaultOllamaModel
                        : AskForthLLMSettings.defaultOpenAIModel,
                    text: binding.model
                )
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .help(profile.provider == .ollama
                      ? "Ollama tag you have pulled (e.g. gemma4:e4b)."
                      : "OpenAI-compatible model id or full local MLX path.")
            }
            labeledField("Temperature") {
                HStack(spacing: 10) {
                    Slider(
                        value: Binding(
                            get: { binding.wrappedValue.temperature },
                            set: { binding.wrappedValue.temperature = AskForthLLMSettings.clampTemperature($0) }
                        ),
                        in: AskForthLLMSettings.temperatureRange,
                        step: 0.05
                    )
                    Text(String(format: "%.2f", profile.temperature))
                        .font(.system(.body, design: .monospaced))
                        .frame(minWidth: 44, alignment: .trailing)
                }
                .help("Lower (e.g. 0.2–0.4) for steadier Forth; higher for more variety. EditForth default is 0.3. Sent on every Ask / Enhance request so the server default is not used.")
            }
            labeledField("Context window") {
                Picker("", selection: Binding(
                    get: { binding.wrappedValue.contextTokens },
                    set: { binding.wrappedValue.contextTokens = AskForthLLMSettings.clampContextTokens($0) }
                )) {
                    ForEach(AskForthLLMSettings.contextChoices, id: \.self) { tokens in
                        Text(AskForthLLMSettings.contextLabel(tokens)).tag(tokens)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .help("Ollama options.num_ctx. This is the token budget for the prompt and the reply together. 32K matches qwen2.5-coder:7b and :14b. Use 8K for a model whose card says 256K, or Ollama reserves that whole window. OpenAI-compatible calls do not send this value.")
            }
            if profile.provider == .openAICompatible {
                labeledField("Base URL") {
                    TextField(AskForthLLMSettings.defaultOpenAIBaseURL, text: binding.baseURL)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .help("OpenAI-compatible root, e.g. https://api.x.ai/v1 or http://127.0.0.1:1234/v1. For local MLX, start a server first (see Ask-Forth.md): source ~/mlx-forth-venv/bin/activate && python -m mlx_lm.server --model <path> --host 127.0.0.1 --port 1234. An LM Studio chat window alone is not enough.")
                }
                labeledField("API key") {
                    HStack(spacing: 8) {
                        Group {
                            if revealAPIKey {
                                TextField("paste key, then Save", text: $draftKey)
                            } else {
                                SecureField("paste key, then Save", text: $draftKey)
                            }
                        }
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        Button(revealAPIKey ? "Hide" : "Show") {
                            revealAPIKey.toggle()
                        }
                        Button("Save") {
                            saveKey(for: profile.id)
                        }
                        .disabled(draftKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button("Clear") {
                            clearKey(for: profile.id)
                        }
                        .disabled(!AskForthLLMSettings.hasKeychainAPIKey(for: profile.id))
                    }
                }
                if !keyStatus.isEmpty {
                    Text(keyStatus)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func labeledField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func refreshKeyUI() {
        guard let id = selectedID,
              let profile = profiles.first(where: { $0.id == id }),
              profile.provider == .openAICompatible else {
            keyStatus = ""
            return
        }
        if AskForthLLMSettings.hasKeychainAPIKey(for: id) {
            keyStatus = "Key saved in Keychain for this profile"
        } else if ProcessInfo.processInfo.environment["XAI_API_KEY"]?.isEmpty == false {
            keyStatus = "No Keychain key — XAI_API_KEY env will be used if set"
        } else {
            keyStatus = "No API key for this profile"
        }
    }

    private func saveKey(for id: UUID) {
        do {
            try AskForthLLMSettings.saveAPIKey(draftKey, for: id)
            draftKey = ""
            revealAPIKey = false
            refreshKeyUI()
            formError = ""
        } catch {
            formError = error.localizedDescription
        }
    }

    private func clearKey(for id: UUID) {
        do {
            try AskForthLLMSettings.deleteAPIKey(for: id)
            draftKey = ""
            refreshKeyUI()
            formError = ""
        } catch {
            formError = error.localizedDescription
        }
    }

    private func addProfile() {
        persistProfiles()
        let profile = AskForthModelProfile(
            name: "New profile",
            provider: .ollama,
            model: AskForthLLMSettings.defaultOllamaModel
        )
        profiles.append(profile)
        selectedID = profile.id
        persistProfiles()
    }

    private func duplicateSelected() {
        guard let id = selectedID,
              let src = profiles.first(where: { $0.id == id }) else { return }
        persistProfiles()
        var copy = src
        copy.id = UUID()
        copy.name = src.name.hasSuffix(" copy") ? src.name : "\(src.name) copy"
        profiles.append(copy)
        selectedID = copy.id
        if src.provider == .openAICompatible,
           let key = AskForthLLMSettings.resolveAPIKey(for: src.id),
           AskForthLLMSettings.hasKeychainAPIKey(for: src.id) {
            // Copy Keychain secret only when it came from Keychain (not env-only).
            try? AskForthLLMSettings.saveAPIKey(key, for: copy.id)
        }
        persistProfiles()
        refreshKeyUI()
    }

    private func deleteSelected() {
        guard let id = selectedID, profiles.count > 1 else { return }
        profiles.removeAll { $0.id == id }
        AskForthLLMSettings.saveProfiles(profiles)
        try? AskForthLLMSettings.deleteAPIKey(for: id)
        if AskForthLLMSettings.activeProfileID == id {
            AskForthLLMSettings.activeProfileID = profiles.first?.id
        }
        selectedID = AskForthLLMSettings.activeProfileID ?? profiles.first?.id
        refreshKeyUI()
    }

    private func persistProfiles() {
        // Normalize empty names.
        for i in profiles.indices {
            let trimmed = profiles[i].name.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                profiles[i].name = profiles[i].provider == .ollama
                    ? "Ollama \(profiles[i].model)"
                    : "OpenAI \(profiles[i].model)"
            }
        }
        AskForthLLMSettings.saveProfiles(profiles)
        if let id = selectedID {
            AskForthLLMSettings.selectProfile(id: id)
        }
    }

    private func commitAndDismiss() {
        persistProfiles()
        model.reloadProfilesFromSettings()
        dismiss()
    }
}

// MARK: - Library RAG settings sheet

private struct LibraryRAGSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings = ForthLibraryRAGSettings.load()
    @State private var indexStatus: String = ""
    @State private var isRebuildingIndex = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Library context")
                .font(.title2.weight(.semibold))

            Text("Ask Forth searches this folder for .fth / .txt / .md / .swift excerpts matching your prompt. Default is Documents/EditForth/Library/Sample. You can point at the EditForth project (Editor/, Docs/) for app questions — heavy folders like .git, DerivedData, and finetune are skipped. Library/Reference (Forth 2012 + stack-effects cheat sheet) is always searched too when your folder is under Library. Hybrid/Semantic use nomic-embed-text via local Ollama; the index auto-updates when the folder or files change (or use Rebuild Index…).")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                Text("Folder")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    TextField("Library folder path", text: $settings.folderPath)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    Button("Choose…") {
                        chooseFolder()
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Retrieve mode")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Retrieve mode", selection: $settings.retrieveMode) {
                    ForEach(ForthLibraryRetrieveMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .help("Hybrid = nomic-embed-text + keyword (recommended). Semantic = embed only. Keyword = original token search. Needs Ollama nomic-embed-text and Rebuild Index… for Hybrid/Semantic.")
            }

            HStack(alignment: .top, spacing: 16) {
                stepperField(
                    title: "Max snippets",
                    help: "How many file excerpts to include",
                    value: $settings.maxSnippets,
                    range: 1...40
                )
                stepperField(
                    title: "Context lines",
                    help: "Lines above/below each hit (keyword windows)",
                    value: $settings.contextLines,
                    range: 2...40
                )
                stepperField(
                    title: "Max characters",
                    help: "Hard cap on Library text sent to the model",
                    value: $settings.maxChars,
                    range: 2000...64000,
                    step: 1000
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Button(isRebuildingIndex ? "Working…" : "Prepare…") {
                        prepareEmbeddings()
                    }
                    .disabled(isRebuildingIndex)
                    .help("Download nomic-embed-text if missing, then build/refresh the Library embed index (background-friendly).")
                    Button(isRebuildingIndex ? "Indexing…" : "Rebuild Index…") {
                        rebuildEmbedIndex()
                    }
                    .disabled(isRebuildingIndex)
                    .help("Force a full re-embed of Sample + Reference (including the stack-effects cheat sheet).")
                    Text(indexStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }

            HStack {
                Button("Reset Defaults") {
                    settings = ForthLibraryRAGSettings(
                        folderPath: ForthLibraryRAGSettings.defaultFolderPath,
                        maxSnippets: 12,
                        contextLines: 12,
                        maxChars: 16_000,
                        retrieveMode: .hybrid
                    )
                }
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Save") {
                    let previous = ForthLibraryRAGSettings.load()
                    settings.save()
                    let folderChanged = previous.folderPath != settings.folderPath
                    let modeNeedsEmbed = settings.retrieveMode != .keyword
                    dismiss()
                    // Pull nomic if needed and refresh index when Hybrid/Semantic needs it.
                    if modeNeedsEmbed,
                       folderChanged || ForthLibraryEmbedIndex.needsRefresh(settings: settings) {
                        AskForthLibraryPrepare.startIfNeeded(settings: settings)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 660)
        .onAppear { refreshIndexStatus() }
    }

    private func refreshIndexStatus() {
        if let store = ForthLibraryEmbedIndex.load(), !store.isEmpty {
            let when = store.builtAt.formatted(date: .abbreviated, time: .shortened)
            indexStatus = "Index: \(store.chunks.count) chunks · \(store.model) · \(when)"
        } else {
            indexStatus = "No embed index yet — Prepare… or open Ask Forth (needs Ollama)"
        }
    }

    private func prepareEmbeddings() {
        isRebuildingIndex = true
        indexStatus = "Preparing…"
        settings.save()
        let snap = settings
        AskForthLibraryPrepare.startIfNeeded(settings: snap) { note in
            Task { @MainActor in
                if !note.isEmpty {
                    indexStatus = note
                }
                if !AskForthLibraryPrepare.isBusy {
                    isRebuildingIndex = false
                    refreshIndexStatus()
                    if indexStatus.hasPrefix("No embed") , !note.isEmpty {
                        indexStatus = note
                    }
                }
            }
        }
        // If startIfNeeded no-op'd because already running, still clear busy when that finishes.
        Task {
            while AskForthLibraryPrepare.isBusy {
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
            await MainActor.run {
                isRebuildingIndex = false
                refreshIndexStatus()
            }
        }
    }

    private func rebuildEmbedIndex() {
        isRebuildingIndex = true
        indexStatus = "Starting…"
        let folderPath = settings.folderPath
        Task {
            do {
                // Ensure embed model exists, then full rebuild.
                let client = AskForthEmbeddingClient()
                if await AskForthOllamaBootstrap.isReachable(),
                   !(await AskForthOllamaBootstrap.hasModel(client.model)) {
                    try await AskForthOllamaBootstrap.pullModel(client.model) { note in
                        Task { @MainActor in indexStatus = note }
                    }
                }
                var snap = ForthLibraryRAGSettings.load()
                snap.folderPath = folderPath
                let store = try await ForthLibraryEmbedIndex.buildOrRefresh(
                    settings: snap,
                    client: client,
                    forceFullRebuild: true,
                    progress: { note in
                        Task { @MainActor in
                            indexStatus = note
                        }
                    }
                )
                await MainActor.run {
                    isRebuildingIndex = false
                    let when = store.builtAt.formatted(date: .abbreviated, time: .shortened)
                    indexStatus = "Index: \(store.chunks.count) chunks · \(store.model) · \(when)"
                }
            } catch {
                await MainActor.run {
                    isRebuildingIndex = false
                    indexStatus = "Index failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func stepperField(
        title: String,
        help: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int = 1
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .help(help)
            Stepper(value: value, in: range, step: step) {
                Text("\(value.wrappedValue)")
                    .font(.system(.body, design: .monospaced))
                    .frame(minWidth: 56, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.message = "Choose the Library folder for Ask Forth context"
        panel.directoryURL = settings.folderURL
        if panel.runModal() == .OK, let url = panel.url {
            settings.folderPath = url.path
        }
    }
}

// MARK: - Box chrome

private extension View {
    /// Visible border so Prompt / Agent boxes read as fields.
    func askForthBoxChrome() -> some View {
        self
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
            )
    }
}

// MARK: - Horizontal splitter (chat ↔ agent)

/// Drag handle between Prompt and 64Forth agent; drag up to shrink the prompt (agent fills the rest).
private struct AIAssistantVSplitter: View {
    static let height: CGFloat = 10

    var onDrag: (CGFloat) -> Void
    var onEnd: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.55))
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 2)
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .onHover { inside in
                    if inside {
                        NSCursor.resizeUpDown.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 1, coordinateSpace: .global)
                        .onChanged { value in
                            onDrag(value.translation.height)
                        }
                        .onEnded { _ in
                            onEnd()
                        }
                )
        }
        .frame(height: Self.height)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .accessibilityLabel("Resize Ask Forth prompt")
        .accessibilityAddTraits(.isButton)
    }
}
