//
//  AIAssistantModel.swift
//  EditForth
//
//  Ask-Forth panel state: selection/context → local LLM → reply,
//  then optional headless 64Forth --agent eval of prompt or reply.
//

import Foundation
import AppKit
import Combine

@MainActor
final class AIAssistantModel: ObservableObject {
    static let defaultModelKey = "aiAssistantModel"
    static let defaultModel = "gemma4:e4b"
    static let autoloadKey = "aiAssistantAgentAutoload"
    static let libraryRAGKey = "aiAssistantLibraryRAG"

    @Published var prompt: String = ""
    @Published var reply: String = ""
    @Published var agentTranscript: String = ""
    @Published var status: String = ""
    @Published var isBusy = false
    @Published var includeSelection = true
    /// When true, agent runs AutoLoad + MAIN before -e/-f (slower; Library words available).
    @Published var agentAutoload: Bool
    /// When true, Ask / Fix retrieve Library .fth excerpts into the prompt.
    @Published var includeLibraryContext: Bool
    @Published var modelName: String

    private let client: LLMClient

    init(client: LLMClient = OllamaClient()) {
        self.client = client
        let stored = UserDefaults.standard.string(forKey: Self.defaultModelKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.modelName = (stored?.isEmpty == false) ? stored! : Self.defaultModel
        self.agentAutoload = UserDefaults.standard.bool(forKey: Self.autoloadKey)
        if UserDefaults.standard.object(forKey: Self.libraryRAGKey) == nil {
            self.includeLibraryContext = true
        } else {
            self.includeLibraryContext = UserDefaults.standard.bool(forKey: Self.libraryRAGKey)
        }
    }

    var providerLabel: String { client.providerName }

    func persistModelName() {
        UserDefaults.standard.set(modelName, forKey: Self.defaultModelKey)
    }

    func persistAutoload() {
        UserDefaults.standard.set(agentAutoload, forKey: Self.autoloadKey)
    }

    func persistLibraryRAG() {
        UserDefaults.standard.set(includeLibraryContext, forKey: Self.libraryRAGKey)
    }

    /// Refresh the prompt box from the active editor selection / caret context.
    func captureContext(from workspace: WorkspaceModel) {
        guard let tab = workspace.selectedTab else {
            status = "No file tab selected."
            return
        }
        let sel = tab.selectedText()
        if includeSelection, let sel, !sel.isEmpty {
            prompt = sel
            status = "Using selection (\(sel.count) characters)."
        } else if let token = tab.forthTokenAtCaret(), !token.isEmpty {
            prompt = token
            status = "Using token under caret."
        } else {
            // A small window around the caret so Ask still has something to work with.
            let window = tab.contextWindow(around: tab.selection, radiusLines: 12)
            prompt = window
            status = window.isEmpty ? "Editor is empty." : "Using lines around the caret."
        }
    }

    func ask(workspace: WorkspaceModel) {
        let userPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userPrompt.isEmpty else {
            status = "Enter a question or capture editor context first."
            return
        }
        let fileHint = workspace.selectedTab?.fileURL?.lastPathComponent
        runCompletion(
            system: Self.systemPrompt(fileName: fileHint),
            user: userPrompt,
            ragQuery: userPrompt,
            busyStatus: "Asking \(client.providerName) (\(modelName))…",
            clearReply: true,
            doneStatus: "Done."
        )
    }

    /// Send prior reply + agent transcript back to the model for a corrected Forth answer.
    func askFixFromAgent(workspace: WorkspaceModel) {
        let transcript = agentTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else {
            status = "Run Eval Reply or Eval Prompt first."
            return
        }
        let priorReply = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        let priorPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !priorReply.isEmpty || !priorPrompt.isEmpty else {
            status = "Need a prompt or reply to fix."
            return
        }

        let fileHint = workspace.selectedTab?.fileURL?.lastPathComponent
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
        runCompletion(
            system: Self.systemPrompt(fileName: fileHint) + "\nYou are correcting Forth that failed or needs improvement after a real kernel eval. Prefer Library context words when they match.",
            user: parts.joined(separator: "\n\n"),
            ragQuery: ragQuery,
            busyStatus: "Asking \(client.providerName) to fix from agent…",
            clearReply: true,
            doneStatus: "Fix suggestion ready — Eval Reply to re-test."
        )
    }

    private func runCompletion(
        system: String,
        user: String,
        ragQuery: String,
        busyStatus: String,
        clearReply: Bool,
        doneStatus: String
    ) {
        guard !isBusy else { return }

        persistModelName()
        persistLibraryRAG()
        isBusy = true
        status = busyStatus
        if clearReply { reply = "" }

        let model = modelName
        let client = self.client
        let useRAG = includeLibraryContext

        Task {
            let reachable = await client.ping()
            guard reachable else {
                await MainActor.run {
                    self.isBusy = false
                    self.status = "Ollama is not reachable at 127.0.0.1:11434."
                }
                return
            }

            var finalUser = user
            var ragNote = ""
            if useRAG {
                await MainActor.run {
                    self.status = "Searching Library…"
                }
                let settings = ForthLibraryRAGSettings.load()
                let rag = await Task.detached(priority: .userInitiated) {
                    ForthLibraryRAG.retrieve(for: ragQuery, settings: settings)
                }.value
                if !rag.isEmpty {
                    let block = rag.contextBlock(maxChars: settings.maxChars)
                    finalUser = block + "\n\nUser request:\n" + user
                    let names = rag.snippets.map(\.relativePath).prefix(4).joined(separator: ", ")
                    ragNote = " · Library \(rag.snippets.count) hit(s): \(names)"
                } else {
                    ragNote = " · Library: no hits"
                }
                await MainActor.run {
                    self.status = busyStatus
                }
            }

            do {
                let text = try await client.complete(
                    system: system,
                    user: finalUser,
                    model: model
                )
                await MainActor.run {
                    self.reply = text
                    self.isBusy = false
                    self.status = doneStatus + ragNote
                }
            } catch {
                await MainActor.run {
                    self.isBusy = false
                    self.status = error.localizedDescription
                }
            }
        }
    }

    func copyReply() {
        guard !reply.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(reply, forType: .string)
        status = "Reply copied."
    }

    /// Insert or replace in the selected editable tab.
    func insertReply(into workspace: WorkspaceModel) {
        guard let tab = workspace.selectedTab else {
            status = "No file tab selected."
            return
        }
        guard !tab.isViewMode else {
            status = "Buffer is in Browse Mode — Allow Editing to insert."
            return
        }
        let text = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            status = "Nothing to insert."
            return
        }
        tab.replaceSelection(with: text)
        status = "Inserted into editor."
    }

    /// Eval Forth extracted from the model reply via a fresh `64Forth --agent` process.
    func evalReply(workspace: WorkspaceModel) {
        let source = ForthAgentRunner.extractForthSource(from: reply)
        runAgent(source: source, workspace: workspace, label: "reply")
    }

    /// Eval the prompt box as Forth (useful for hand-typed snippets).
    func evalPrompt(workspace: WorkspaceModel) {
        let source = ForthAgentRunner.extractForthSource(from: prompt)
        runAgent(source: source, workspace: workspace, label: "prompt")
    }

    private func runAgent(source: String, workspace: WorkspaceModel, label: String) {
        let code = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else {
            status = "No Forth source in \(label) to evaluate."
            return
        }
        guard !isBusy else { return }

        persistAutoload()
        isBusy = true
        agentTranscript = ""
        status = "Running 64Forth --agent on \(label)…"

        let cwd = agentWorkingDirectory(workspace: workspace)
        let autoload = agentAutoload

        Task {
            do {
                let result = try await ForthAgentRunner.evaluate(
                    source: code,
                    cwd: cwd,
                    autoload: autoload
                )
                await MainActor.run {
                    self.agentTranscript = result.transcript.isEmpty
                        ? "(no transcript, exit \(result.exitCode))"
                        : result.transcript
                    self.isBusy = false
                    if result.exitCode == 0 {
                        self.status = "Agent OK (exit 0)."
                    } else {
                        self.status = "Agent finished with exit \(result.exitCode)."
                    }
                }
            } catch {
                await MainActor.run {
                    self.isBusy = false
                    self.agentTranscript = ""
                    self.status = error.localizedDescription
                }
            }
        }
    }

    private func agentWorkingDirectory(workspace: WorkspaceModel) -> URL {
        if let dir = workspace.selectedTab?.fileURL?.deletingLastPathComponent(),
           FileManager.default.fileExists(atPath: dir.path) {
            return dir
        }
        let docs = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/EditForth", isDirectory: true)
        if FileManager.default.fileExists(atPath: docs.path) {
            return docs
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    private static func systemPrompt(fileName: String?) -> String {
        var lines = [
            "You are a Forth programming assistant for EditForth / 64Forth (ANS-style ITC Forth on Apple Silicon).",
            "Prefer idiomatic Forth: clear stack comments ( a b -- c ), short words, and explanations that match classic Forth style.",
            "When asked for code, return Forth source the user can paste inside a ```forth fenced block when possible. Avoid inventing words that are not standard or not in common 64Forth libraries unless you label them as suggestions.",
            "Be concise."
        ]
        if let fileName, !fileName.isEmpty {
            lines.append("The user is editing: \(fileName).")
        }
        return lines.joined(separator: "\n")
    }
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

        // Walk up/down by newline count.
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
