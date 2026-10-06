//
//  DockedConsoleView.swift
//  EditForth
//
//  Character console embedded under Ping. Talks to companion 64Forth over edit.sock.
//

import AppKit
import SwiftUI

/// Forth REPL hosted inside the editor (protected output + editable tail).
struct DockedConsoleView: NSViewRepresentable {
    @ObservedObject var forth: ForthConnectionManager

    func makeCoordinator() -> Coordinator {
        Coordinator(forth: forth)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = true
        scroll.backgroundColor = .textBackgroundColor

        let tv = DockedConsoleTextView()
        tv.coordinator = context.coordinator
        tv.isRichText = false
        tv.isEditable = true
        tv.isSelectable = true
        tv.allowsUndo = true
        tv.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        tv.textColor = .labelColor
        tv.backgroundColor = .textBackgroundColor
        tv.insertionPointColor = .labelColor
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.usesFindBar = true

        scroll.documentView = tv
        context.coordinator.attach(textView: tv, scrollView: scroll)
        context.coordinator.bootstrapIfNeeded()
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.forth = forth
        context.coordinator.drainEmit()
        context.coordinator.setConnected(forth.isConnected, debugArmed: forth.isDebugSessionArmed)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var forth: ForthConnectionManager
        private weak var textView: DockedConsoleTextView?
        private weak var scrollView: NSScrollView?
        private var protectedUTF16 = 0
        private var history: [String] = []
        private var historyIndex = -1
        private var lastEmitSeq: UInt = 0
        private var didBootstrap = false
        private var isProgrammatic = false

        init(forth: ForthConnectionManager) {
            self.forth = forth
        }

        /// UTF-16 length of engine-owned (non-editable) prefix.
        var protectedLength: Int { protectedUTF16 }

        func attach(textView: DockedConsoleTextView, scrollView: NSScrollView) {
            self.textView = textView
            self.scrollView = scrollView
            textView.delegate = self
        }

        func bootstrapIfNeeded() {
            guard !didBootstrap, let tv = textView else { return }
            didBootstrap = true
            isProgrammatic = true
            if !forth.consoleTranscript.isEmpty {
                // Remount after Hide/Show (or view recreation): restore session text.
                tv.string = forth.consoleTranscript
            } else {
                // Local paint only — do not mutate ForthConnectionManager here
                // (makeNSView runs inside a view update; @Published writes warn).
                tv.string = EditForthConsoleBanner.text
            }
            protectedUTF16 = (tv.string as NSString).length
            isProgrammatic = false
            // Transcript is authoritative; drop buffered chunks already merged into it
            // so remount/undock does not reprint "Starting EditForth…" / Autoload lines.
            forth.discardPendingConsoleEmit(syncing: &lastEmitSeq)
        }

        func setConnected(_ connected: Bool, debugArmed: Bool) {
            textView?.isEditable = connected && !debugArmed
        }

        func drainEmit() {
            guard let tv = textView else { return }
            let seq = forth.consoleEmitSeq
            guard seq != lastEmitSeq else { return }
            let chunk = forth.takeConsoleEmit(since: &lastEmitSeq)
            guard !chunk.isEmpty else { return }
            if chunk.contains("\u{0c}") {
                // Companion CLS hint.
                isProgrammatic = true
                tv.string = ""
                protectedUTF16 = 0
                isProgrammatic = false
                let rest = chunk.replacingOccurrences(of: "\u{0c}", with: "")
                if !rest.isEmpty {
                    appendEngine(rest)
                }
                return
            }
            appendEngine(chunk)
        }

        private func appendEngine(_ s: String) {
            guard let tv = textView else { return }
            isProgrammatic = true
            let atEnd = tv.selectedRange().location >= (tv.string as NSString).length
            // Apply BS (0x08) against protected text — DEBUG block cursor erase.
            var i = s.startIndex
            while i < s.endIndex {
                let ch = s[i]
                i = s.index(after: i)
                if ch == "\u{8}" {
                    let full = tv.string as NSString
                    if full.length > 0 {
                        let delAt = full.length - 1
                        tv.replaceCharacters(in: NSRange(location: delAt, length: 1), with: "")
                        if protectedUTF16 > delAt {
                            protectedUTF16 = (tv.string as NSString).length
                        }
                    }
                } else {
                    let ns = String(ch)
                    tv.replaceCharacters(
                        in: NSRange(location: (tv.string as NSString).length, length: 0),
                        with: ns
                    )
                    protectedUTF16 = (tv.string as NSString).length
                }
            }
            protectedUTF16 = (tv.string as NSString).length
            if atEnd {
                tv.setSelectedRange(NSRange(location: protectedUTF16, length: 0))
                tv.scrollRangeToVisible(NSRange(location: protectedUTF16, length: 0))
            }
            isProgrammatic = false
        }

        func submitLine() {
            guard let tv = textView, forth.isConnected, !forth.isDebugSessionArmed else { return }
            let full = tv.string as NSString
            let prot = min(protectedUTF16, full.length)
            let user = full.substring(from: prot)
            let line = user.trimmingCharacters(in: .whitespacesAndNewlines)

            isProgrammatic = true
            if !tv.string.hasSuffix("\n") {
                tv.replaceCharacters(in: NSRange(location: full.length, length: 0), with: "\n")
            }
            protectedUTF16 = (tv.string as NSString).length
            tv.setSelectedRange(NSRange(location: protectedUTF16, length: 0))
            isProgrammatic = false

            if !line.isEmpty {
                history.append(line)
                if history.count > 50 { history.removeFirst() }
                historyIndex = -1
            }
            // Empty Return still asks the companion for a fresh ok(n)> (depth-correct).
            forth.send(.executeCommand(command: line))
        }

        func recall(up: Bool) {
            guard let tv = textView, !history.isEmpty else { return }
            if up {
                if historyIndex < 0 { historyIndex = history.count - 1 }
                else if historyIndex > 0 { historyIndex -= 1 }
            } else {
                if historyIndex < 0 { return }
                historyIndex += 1
                if historyIndex >= history.count {
                    historyIndex = -1
                    replaceUserPortion("")
                    return
                }
            }
            guard historyIndex >= 0, historyIndex < history.count else { return }
            replaceUserPortion(history[historyIndex])
        }

        private func replaceUserPortion(_ s: String) {
            guard let tv = textView else { return }
            let full = tv.string as NSString
            let prot = min(protectedUTF16, full.length)
            isProgrammatic = true
            tv.replaceCharacters(in: NSRange(location: prot, length: full.length - prot), with: s)
            let end = (tv.string as NSString).length
            tv.setSelectedRange(NSRange(location: end, length: 0))
            isProgrammatic = false
        }

        func pushTypedCharacter(_ c: Int32) {
            guard forth.isConnected else { return }
            forth.send(.pushKey(code: c))
        }

        func viewWord(_ word: String) {
            forth.viewWord(word)
        }

        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            if isProgrammatic { return true }
            if affectedCharRange.location < protectedUTF16 {
                return false
            }
            return true
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                submitLine()
                return true
            }
            if commandSelector == #selector(NSResponder.moveUp(_:)) {
                recall(up: true)
                return true
            }
            if commandSelector == #selector(NSResponder.moveDown(_:)) {
                recall(up: false)
                return true
            }
            return false
        }
    }
}

final class DockedConsoleTextView: NSTextView {
    weak var coordinator: DockedConsoleView.Coordinator?

    override func mouseDown(with event: NSEvent) {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if mods.contains(.command) {
            let pt = convert(event.locationInWindow, from: nil)
            let idx = characterIndexForInsertion(at: pt)
            let ns = string as NSString
            if let word = EditorNSTextView.forthToken(at: idx, in: ns),
               word.rangeOfCharacter(from: .whitespacesAndNewlines) == nil {
                let caret = min(max(0, idx), ns.length)
                setSelectedRange(NSRange(location: caret, length: 0))
                window?.makeFirstResponder(self)
                coordinator?.viewWord(word)
                return
            }
        }
        super.mouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        // Forward printable keys to companion for KEY waits; still insert locally via super.
        if let chars = event.charactersIgnoringModifiers, chars.count == 1,
           let ch = chars.utf16.first, ch >= 32, ch != 127 {
            coordinator?.pushTypedCharacter(Int32(ch))
        }
        super.keyDown(with: event)
    }

    override func paste(_ sender: Any?) {
        // Paste only into the editable tail (never into protected engine output).
        if let coord = coordinator {
            let prot = coord.protectedLength
            let end = (string as NSString).length
            let sel = selectedRange()
            if sel.location < prot {
                setSelectedRange(NSRange(location: end, length: 0))
            }
        }
        super.paste(sender)
    }
}
