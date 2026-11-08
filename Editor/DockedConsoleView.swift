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
        // Custom FindReplaceBarView (Match Case + Whole Word); not NSTextFinder.
        tv.usesFindBar = false
        tv.isIncrementalSearchingEnabled = false

        scroll.documentView = tv
        scroll.findBarPosition = .aboveContent
        _ = scroll.ensureFindReplaceBar(for: tv)
        context.coordinator.attach(textView: tv, scrollView: scroll)
        context.coordinator.bootstrapIfNeeded()
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.forth = forth
        context.coordinator.applyResetIfNeeded()
        context.coordinator.drainEmit()
        context.coordinator.setConnected(forth.isConnected, debugArmed: forth.isDebugSessionArmed)
        context.coordinator.applyConsoleFillIfNeeded()
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var forth: ForthConnectionManager
        private weak var textView: DockedConsoleTextView?
        private weak var scrollView: NSScrollView?
        private var protectedUTF16 = 0
        private var history: [String] = []
        private var historyIndex = -1
        private var lastEmitSeq: UInt = 0
        private var lastFillSeq: UInt = 0
        private var lastResetSeq: UInt = 0
        private var didBootstrap = false
        private var isProgrammatic = false
        private var resetObserver: NSObjectProtocol?
        private var caretScrollForce = false
        private var caretScrollScheduled = false

        init(forth: ForthConnectionManager) {
            self.forth = forth
            super.init()
            // Delivered on the poster thread. Restart posts on the main queue,
            // so the text view is wiped before the new image's output arrives.
            resetObserver = NotificationCenter.default.addObserver(
                forName: .editForthConsoleReset,
                object: forth,
                queue: nil
            ) { [weak self] _ in
                self?.applyReset()
            }
        }

        deinit {
            if let resetObserver {
                NotificationCenter.default.removeObserver(resetObserver)
            }
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

        /// SwiftUI path for a reset that was posted before this text view existed.
        func applyResetIfNeeded() {
            guard forth.consoleResetSeq != lastResetSeq else { return }
            applyReset()
        }

        /// Copy `consoleTranscript` over the whole text view and drop emit
        /// already included in that string so it is not appended again.
        private func applyReset() {
            guard let tv = textView else { return }
            lastResetSeq = forth.consoleResetSeq
            isProgrammatic = true
            tv.string = forth.consoleTranscript
            protectedUTF16 = (tv.string as NSString).length
            tv.setSelectedRange(NSRange(location: protectedUTF16, length: 0))
            scrollCaretLineIntoView(tv, force: true)
            scheduleCaretScroll(force: true)
            isProgrammatic = false
            forth.discardPendingConsoleEmit(syncing: &lastEmitSeq)
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
                // A zero-length range has no height. When the pane is a little
                // narrower than the debug line, the block cursor wraps onto the
                // next fragment and that point stays on the clip's bottom edge.
                scrollCaretLineIntoView(tv, force: true)
                scheduleCaretScroll(force: true)
            }
            isProgrammatic = false
        }

        /// Line fragment that holds the insertion point, in text-view coordinates.
        /// Includes the empty fragment after a newline, and one more line when the
        /// caret sits past a fragment that is already full.
        private func caretLineRect(in tv: NSTextView) -> NSRect {
            let fallbackH = tv.font?.boundingRectForFont.height ?? 14
            guard let layout = tv.layoutManager, let container = tv.textContainer else {
                return NSRect(x: 0, y: 0, width: 1, height: fallbackH)
            }
            layout.ensureLayout(for: container)
            let ns = tv.string as NSString
            let len = ns.length
            let origin = tv.textContainerOrigin
            let rect: NSRect
            if len == 0 || (len > 0 && ns.character(at: len - 1) == 10),
               layout.extraLineFragmentTextContainer === container,
               layout.extraLineFragmentRect.height > 0 {
                rect = layout.extraLineFragmentRect
            } else if len > 0 {
                let glyph = layout.glyphIndexForCharacter(at: len - 1)
                var line = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
                let used = layout.lineFragmentUsedRect(forGlyphAt: glyph, effectiveRange: nil)
                let limit = container.containerSize.width
                if limit.isFinite, used.maxX >= limit - 1 {
                    line.origin.y += line.height
                }
                rect = line
            } else {
                rect = NSRect(x: 0, y: 0, width: 1, height: fallbackH)
            }
            return rect.offsetBy(dx: origin.x, dy: origin.y)
        }

        /// Keep the caret's line inside the clip. `force` follows new output.
        /// A width change uses `force == false` and only corrects a caret that
        /// slipped just below the fold, so a scroll-back through history stays put.
        private func scrollCaretLineIntoView(_ tv: NSTextView, force: Bool) {
            guard let scroll = tv.enclosingScrollView else { return }
            let len = (tv.string as NSString).length
            guard tv.selectedRange().location >= len, tv.selectedRange().length == 0 else { return }
            var show = caretLineRect(in: tv)
            guard show.height > 0 else { return }
            show.size.height += 2

            let bottom = show.maxY + tv.textContainerInset.height
            if tv.frame.height + 0.5 < bottom {
                var frame = tv.frame
                frame.size.height = bottom
                tv.frame = frame
            }

            let clip = scroll.contentView.bounds
            let gap = show.maxY - clip.maxY
            if !force {
                guard gap > 0.5, gap < show.height * 3 else { return }
            }
            guard gap > 0.5 else { return }
            let targetY = max(0, show.maxY - clip.height)
            guard abs(clip.origin.y - targetY) > 0.5 else { return }
            scroll.contentView.scroll(to: NSPoint(x: clip.origin.x, y: targetY))
            scroll.reflectScrolledClipView(scroll.contentView)
        }

        /// Layout after a wrap often lands once the current updateNSView returns.
        private func scheduleCaretScroll(force: Bool) {
            caretScrollForce = caretScrollForce || force
            guard !caretScrollScheduled else { return }
            caretScrollScheduled = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let force = self.caretScrollForce
                self.caretScrollScheduled = false
                self.caretScrollForce = false
                guard let tv = self.textView else { return }
                self.scrollCaretLineIntoView(tv, force: force)
            }
        }

        func caretWidthChanged() {
            scheduleCaretScroll(force: false)
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
            forth.sendConsoleLine(line)
        }

        func recall(up: Bool) {
            guard textView != nil, !history.isEmpty else { return }
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
            scrollCaretLineIntoView(tv, force: true)
            scheduleCaretScroll(force: true)
            isProgrammatic = false
        }

        /// RUN / F5 family: put a ready-to-edit line on the input tail and focus the console.
        func applyConsoleFillIfNeeded() {
            let seq = forth.consoleFillSeq
            guard seq != lastFillSeq else { return }
            lastFillSeq = seq
            let text = forth.consoleFillText
            guard !text.isEmpty else { return }
            replaceUserPortion(text)
            guard let tv = textView else { return }
            tv.window?.makeKeyAndOrderFront(nil)
            tv.window?.makeFirstResponder(tv)
            let end = (tv.string as NSString).length
            tv.setSelectedRange(NSRange(location: end, length: 0))
            scrollCaretLineIntoView(tv, force: true)
            scheduleCaretScroll(force: true)
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
                // While GRAPHICS KEY waits, Return must reach the companion as a
                // key — a second executeCommand only gets "(busy …)".
                pushTypedCharacter(13)
                submitLine()
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                // Esc → APP-KEY / console KEY abort path
                pushTypedCharacter(27)
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

    override func setFrameSize(_ newSize: NSSize) {
        let widthChanged = abs(newSize.width - bounds.width) > 0.5
        super.setFrameSize(newSize)
        if widthChanged {
            coordinator?.caretWidthChanged()
        }
    }

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
        // F5 family while idle — highlighted word is not in this view, so the
        // fill uses the included file's last definition, else LAST.
        if let forth = coordinator?.forth, !forth.isDebugSessionArmed,
           let kind = ForthConnectionManager.runLineKind(from: event) {
            forth.prepareRunLine(kind)
            return
        }
        if event.keyCode == 96, coordinator?.forth.isDebugSessionArmed != true { // F5 — block Complete
            return
        }
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
