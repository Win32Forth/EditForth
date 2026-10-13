//
//  AIAssistantPanel.swift
//  EditForth
//
//  Trailing Ask-Forth inspector: local Ollama chat; replies stream into
//  AskForth-N.fth in the editor. Agent transcript is optional / collapsed.
//

import SwiftUI
import AppKit

struct AIAssistantPanel: View {
    @ObservedObject var model: AIAssistantModel
    @EnvironmentObject private var workspace: WorkspaceModel

    /// Same key as View → Ask Forth / tab-bar inspector button.
    @AppStorage("showAIAssistant") private var showAIAssistant = false

    /// Prompt TextEditor height only — agent pane fills whatever is left below the splitter.
    @AppStorage("aiPromptEditorHeight") private var storedPromptHeight = 40.0
    @State private var promptHeight = 40.0
    @State private var promptDragStart: CGFloat?
    @State private var showLibrarySettings = false
    /// Last path component of the Library RAG folder (Library button title).
    @State private var libraryFolderLeaf = ""
    /// Full Library RAG folder path (Library button tooltip).
    @State private var libraryFolderPath = ""
    /// When true, API key draft is shown in clear text so paste/prefix can be checked.
    @State private var revealAPIKey = false

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
        }
        .onChange(of: showLibrarySettings) { _, isOpen in
            if !isOpen {
                refreshLibraryFolderLeaf()
            }
        }
        .sheet(isPresented: $showLibrarySettings) {
            LibraryRAGSettingsSheet()
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
            HStack(spacing: 8) {
                Text("Ask Forth")
                    .font(.headline)
                Spacer()
                Text(model.providerLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

            askForthHelpPanel(
                """
                Type in your Prompt (question), click Ask, and your reply will be sent to a file AskForth-N.fth in Documents/EditForth/AskForth which will be opened at the left. Then Click Agent Enhance Reply to ask the agent to improve the answer, which will be appended to the same file. Library defaults to Library/Sample.

                Provider: Ollama (local) or OpenAI-compatible HTTP (default SpaceXAI / xAI at api.x.ai/v1). Hover the Provider and Model controls for details. Model names are stored separately per provider.
                """
            )

            HStack(spacing: 6) {
                Text("Provider")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("", selection: Binding(
                    get: { model.provider },
                    set: { model.selectProvider($0) }
                )) {
                    ForEach(AskForthLLMProvider.allCases) { p in
                        Text(p.menuTitle).tag(p)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 200)
                .help(model.provider.help)
            }

            if model.provider == .openAICompatible {
                HStack(spacing: 6) {
                    Text("Base URL")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField(AskForthLLMSettings.defaultOpenAIBaseURL, text: $model.openAIBaseURLString)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.caption, design: .monospaced))
                        .onSubmit { model.persistOpenAIBaseURL() }
                        .help("OpenAI-compatible root, usually https://api.x.ai/v1. Other servers that speak /v1/chat/completions also work.")
                }
                HStack(spacing: 6) {
                    Text("API key")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Group {
                        if revealAPIKey {
                            TextField("paste key, then Save", text: $model.apiKeyDraft)
                        } else {
                            SecureField("paste key, then Save", text: $model.apiKeyDraft)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
                    .help("Paste your full xAI key (include the xai- prefix if the console shows it). Use Show to verify. Then click Save.")
                    Button(revealAPIKey ? "Hide" : "Show") {
                        revealAPIKey.toggle()
                    }
                    .font(.caption)
                    .help(revealAPIKey
                          ? "Hide the key (black dots again)"
                          : "Show the pasted key in clear text so you can check the xai- prefix")
                    Button("Save") {
                        model.saveAPIKeyDraft()
                        revealAPIKey = false
                    }
                    .font(.caption)
                    .disabled(model.apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .help("Store the pasted API key in the Keychain")
                    Button("Clear") { model.clearAPIKey() }
                        .font(.caption)
                        .disabled(!AskForthLLMSettings.hasKeychainAPIKey)
                        .help("Remove the Keychain API key")
                }
                if !model.apiKeyStatus.isEmpty {
                    Text(model.apiKeyStatus)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 6) {
                Text("Model")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField(model.modelFieldPlaceholder, text: $model.modelName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
                    .onSubmit { model.persistModelName() }
                    .help(model.provider == .ollama
                          ? "Ollama tag you have pulled (e.g. gemma4:e4b). Must match a model in the Ollama app."
                          : "OpenAI-compatible model id (e.g. grok-4.7 for SpaceXAI / xAI).")
            }

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

            Button("Capture Selected to Prompt") {
                model.captureSelectedToPrompt(from: workspace)
            }
            .help("Select some text from a source file and this button will copy and paste it into the Prompt window for evaluation by Ask Forth")
            .disabled(model.isBusy)

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
                Button(askButtonTitle) {
                    model.ask(workspace: workspace)
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(model.isBusy || model.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
    }

    /// About 2½ lines of caption2 (one line shorter than the prior ~3½); scroll for the rest.
    private static let helpPanelHeight: CGFloat = 42

    private func askForthHelpPanel(_ text: String) -> some View {
        ScrollView {
            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(4)
        }
        .frame(height: Self.helpPanelHeight)
        .askForthBoxChrome()
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
            Text("64Forth Agent")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            askForthHelpPanel(
                "Agent Enhance Reply asks the model to evaluate the Ask Forth transcript and to enhance its answer. The enhanced answer is appended to the AskForth-N.fth file with a header \"Agent Enhanced Reply\". Use INCLUDE in the status strip to load edited code into the live Forth console."
            )

            HStack(alignment: .center, spacing: 10) {
                Button(enhanceButtonTitle) {
                    model.evalReplyAndAgentFix(workspace: workspace)
                }
                .disabled(model.isBusy || model.reply.isEmpty)
                .help("After Ask: run the reply in a headless 64Forth --agent (Autoload on), then ask the model to improve it and append “Agent Enhanced Reply” to the same AskForth file. Does not type into the live console — use INCLUDE after you edit.")

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

// MARK: - Library RAG settings sheet

private struct LibraryRAGSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings = ForthLibraryRAGSettings.load()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Library context")
                .font(.title2.weight(.semibold))

            Text("Ask Forth searches this folder for .fth / .txt / .md / .swift excerpts matching your prompt. Default is Documents/EditForth/Library/Sample. You can point at the EditForth project (Editor/, Docs/) for app questions — heavy folders like .git, DerivedData, and finetune are skipped. Library/Reference (Forth 2012 Standard text) is always searched too when your folder is under Library. Only the top-scoring snippets are sent — not the whole tree.")
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

            HStack(alignment: .top, spacing: 16) {
                stepperField(
                    title: "Max snippets",
                    help: "How many file excerpts to include",
                    value: $settings.maxSnippets,
                    range: 1...40
                )
                stepperField(
                    title: "Context lines",
                    help: "Lines above/below each hit",
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

            HStack {
                Button("Reset Defaults") {
                    settings = ForthLibraryRAGSettings(
                        folderPath: ForthLibraryRAGSettings.defaultFolderPath,
                        maxSnippets: 12,
                        contextLines: 12,
                        maxChars: 16_000
                    )
                }
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Save") {
                    settings.save()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 660)
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
