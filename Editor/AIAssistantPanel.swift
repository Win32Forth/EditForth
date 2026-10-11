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
        }
        .sheet(isPresented: $showLibrarySettings) {
            LibraryRAGSettingsSheet()
        }
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
                Type in your Prompt (question), click Ask, and your reply will be sent to a file AskForth-N.fth in Documents/EditForth which will be opened at the left. Then Click Agent Enhance Reply to ask the agent to improve the answer, which will be appended to the same file. Library defaults to Library/Sample.

                The Model entered here must be an Ollama compatible model that you have already downloaded and selected for use in the Ollama app for a conversation. Cloud based Models compatible with Ollama can also be used.
                """
            )

            HStack(spacing: 6) {
                Text("Model")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("gemma4:e4b", text: $model.modelName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
                    .onSubmit { model.persistModelName() }
            }

            HStack(spacing: 8) {
                Toggle("Include Library context", isOn: $model.includeLibraryContext)
                    .font(.caption)
                    .help("Search the configured Library folder for matching .fth excerpts and add them to Ask / Enhance")
                    .onChange(of: model.includeLibraryContext) { _, _ in
                        model.persistLibraryRAG()
                    }
                Button("Library…") {
                    showLibrarySettings = true
                }
                .font(.caption)
                .help("Folder path, snippet count, context lines, and max characters")
            }

            Toggle("Fetch URLs in Prompt", isOn: $model.fetchURLsInPrompt)
                .font(.caption)
                .help("Fetch http(s) links in the Prompt, and auto-fetch forth-standard.org pages when the Prompt looks like a word lookup (`DUP`, “what does OPEN-FILE”)")
                .onChange(of: model.fetchURLsInPrompt) { _, _ in
                    model.persistURLFetch()
                }

            Toggle("Include web search", isOn: $model.includeWebSearch)
                .font(.caption)
                .help("Opt-in: search the web (DuckDuckGo Lite, no API key) using the Prompt text and add top hit titles, URLs, and snippets to Ask / Agent Enhance Reply. Default off.")
                .onChange(of: model.includeWebSearch) { _, _ in
                    model.persistWebSearch()
                }

            Button("Capture Selected to Prompt") {
                model.captureSelectedToPrompt(from: workspace)
            }
            .disabled(model.isBusy)

            Text("Prompt")
                .font(.caption)
                .foregroundStyle(.secondary)
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
                .help("Eval the latest Ask Forth reply via 64Forth --agent (Autoload on), then append an Agent Enhanced Reply section to the same file")

                Toggle("Show Agent Transcript", isOn: $model.showAgentTranscript)
                    .font(.caption)
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

            Text("Ask Forth searches this folder for .fth / .txt excerpts matching your prompt. Default is Documents/EditForth/Library/Sample. Library/Reference (Forth 2012 Standard text) is always searched too. Only the top-scoring snippets are sent — not the whole tree.")
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
        .frame(width: 560)
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
