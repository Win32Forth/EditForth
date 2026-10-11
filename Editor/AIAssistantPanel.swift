//
//  AIAssistantPanel.swift
//  EditForth
//
//  Trailing Ask-Forth inspector: local Ollama chat with editor context.
//  Bordered Prompt / Reply / Agent boxes; horizontal splitter above the agent area.
//

import SwiftUI
import AppKit

struct AIAssistantPanel: View {
    @ObservedObject var model: AIAssistantModel
    @EnvironmentObject private var workspace: WorkspaceModel

    /// Height of the agent block (transcript + controls below the horizontal splitter).
    @AppStorage("aiAgentPaneHeight") private var storedAgentHeight = 200.0
    @State private var agentHeight = 200.0
    @State private var agentDragStart: CGFloat?
    @State private var showLibrarySettings = false

    private static let agentMinHeight: CGFloat = 120
    private static let chatMinHeight: CGFloat = 160

    var body: some View {
        GeometryReader { geo in
            let splitterH = AIAssistantVSplitter.height
            let maxAgent = max(
                Self.agentMinHeight,
                geo.size.height - Self.chatMinHeight - splitterH - 8
            )
            let clampedAgent = min(max(agentHeight, Self.agentMinHeight), maxAgent)

            VStack(alignment: .leading, spacing: 0) {
                chatSection
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                AIAssistantVSplitter(
                    onDrag: { translationY in
                        let base = agentDragStart ?? clampedAgent
                        if agentDragStart == nil { agentDragStart = clampedAgent }
                        // Drag up (negative Y) grows the agent pane.
                        let next = min(
                            max(base - translationY, Self.agentMinHeight),
                            maxAgent
                        )
                        agentHeight = next
                    },
                    onEnd: {
                        agentDragStart = nil
                        storedAgentHeight = agentHeight
                    }
                )

                agentSection
                    .frame(height: clampedAgent)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onAppear {
                agentHeight = max(storedAgentHeight, Self.agentMinHeight)
            }
            .onChange(of: geo.size.height) { _, _ in
                if agentHeight > maxAgent {
                    agentHeight = maxAgent
                    storedAgentHeight = Double(maxAgent)
                }
            }
            .sheet(isPresented: $showLibrarySettings) {
                LibraryRAGSettingsSheet()
            }
        }
    }

    // MARK: - Chat (prompt / reply)

    private var chatSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Ask Forth")
                    .font(.headline)
                Spacer()
                Text(model.providerLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Local Ollama · Capture or type a question · Ask · Eval on 64Forth --agent · Fix from Agent to revise. Library… chooses the search folder and snippet limits.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Text("Model")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("gemma4:e4b", text: $model.modelName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
                    .onSubmit { model.persistModelName() }
            }

            Toggle("Prefer selection / caret context", isOn: $model.includeSelection)
                .font(.caption)

            HStack(spacing: 8) {
                Toggle("Include Library context", isOn: $model.includeLibraryContext)
                    .font(.caption)
                    .help("Search the configured Library folder for matching .fth excerpts and add them to Ask / Fix")
                    .onChange(of: model.includeLibraryContext) { _, _ in
                        model.persistLibraryRAG()
                    }
                Button("Library…") {
                    showLibrarySettings = true
                }
                .font(.caption)
                .help("Folder path, snippet count, context lines, and max characters")
            }

            HStack(spacing: 8) {
                Button("Capture Context") {
                    model.captureContext(from: workspace)
                }
                .disabled(model.isBusy)

                Button(model.isBusy ? "Asking…" : "Ask") {
                    model.ask(workspace: workspace)
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(model.isBusy || model.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.borderedProminent)
            }

            Text("Prompt")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $model.prompt)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(6)
                .frame(minHeight: 88, idealHeight: 110, maxHeight: 140)
                .askForthBoxChrome()

            Text("Reply")
                .font(.caption)
                .foregroundStyle(.secondary)
            ScrollView {
                Text(model.reply.isEmpty ? " " : model.reply)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .padding(6)
            .askForthBoxChrome()
            .frame(maxHeight: .infinity)

            HStack(spacing: 8) {
                Button("Copy Reply") {
                    model.copyReply()
                }
                .disabled(model.reply.isEmpty)

                Button("Insert into Editor") {
                    model.insertReply(into: workspace)
                }
                .disabled(model.reply.isEmpty || workspace.selectedTab == nil)

                Spacer()
            }

            Text(model.status)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    // MARK: - Agent

    private var agentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("64Forth agent")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Toggle("Autoload Library before eval", isOn: $model.agentAutoload)
                .font(.caption)
                .onChange(of: model.agentAutoload) { _, _ in
                    model.persistAutoload()
                }

            HStack(spacing: 8) {
                Button("Eval Reply") {
                    model.evalReply(workspace: workspace)
                }
                .disabled(model.isBusy || model.reply.isEmpty)
                .help("Run Forth from the reply (fenced block if present) via 64Forth --agent")

                Button("Eval Prompt") {
                    model.evalPrompt(workspace: workspace)
                }
                .disabled(model.isBusy || model.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Run Forth from the prompt box via 64Forth --agent")

                Button("Fix from Agent") {
                    model.askFixFromAgent(workspace: workspace)
                }
                .disabled(model.isBusy || model.agentTranscript.isEmpty)
                .help("Send the agent transcript and prior reply back to the model for a corrected answer")
            }

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

            Text("Ask Forth searches this folder for .fth excerpts matching your prompt. Only the top-scoring snippets are sent — not the whole tree.")
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
    /// Visible border so Prompt / Reply / Agent boxes read as fields.
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

/// Drag handle between Ask chat and 64Forth agent; drag up to grow the agent pane.
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
        .accessibilityLabel("Resize Ask Forth agent pane")
        .accessibilityAddTraits(.isButton)
    }
}
