//
//  EditorTextView.swift
//  64Edit
//
//  Created by Tom's MacBook Air on 9/29/26.
//

import SwiftUI
import AppKit

struct EditorTextView: NSViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat
    /// 1-based line to reveal once; ContentView clears after apply.
    @Binding var gotoLine: Int?
    /// DEBUG peek token to highlight near `gotoLine` (pastel green); cleared after apply.
    @Binding var highlightName: String?
    /// File-relative UTF-8 byte span from dbg-map; preferred over name when set.
    @Binding var highlightOff: Int?
    @Binding var highlightLen: Int?
    /// Matches `EditorTab.highlightEpoch`; stale deferred applies must not paint.
    var highlightEpoch: UInt = 0
    /// VIEW / browse: read-only; edit keys are ignored (use banner Edit / ⌘⇧E / Browse Mode).
    @Binding var isViewMode: Bool
    /// Per-tab caret / selection (saved while editing, restored on tab switch).
    @Binding var selection: NSRange
    /// Per-tab 1-based top visible line.
    @Binding var topVisibleLine: Int
    /// When 64Forth DEBUG is armed, F-keys (and view-mode letter keys) drive the stepper.
    var isDebugArmed: Bool = false
    /// View → Show Line Numbers (AppStorage); vertical ruler on/off.
    var showLineNumbers: Bool = true
    /// BREAK-table slots from the host (enabled = pale-red, disabled = gray wash).
    var breakpointEntries: [BreakpointEntry] = []
    var onDebugStepOver: (() -> Void)?
    var onDebugStepInto: (() -> Void)?
    var onDebugStepOut: (() -> Void)?
    var onDebugContinue: (() -> Void)?
    var onDebugStop: (() -> Void)?
    /// Idle F5 / ⌘F5 / ⌘⇧F5 — fill console from LAST (not NSTextView Complete).
    var onPrepareRunLine: ((ForthConnectionManager.RunLineKind) -> Void)?
    /// ⌘-click on a Forth token → Hyper VIEW via IPC (`VIEW <word>`).
    var onCommandClickWord: ((String) -> Void)?
    /// F9 / ⌘\ / Debug menu: toggle BREAK on the Forth token under the caret.
    var onToggleBreakpoint: ((String) -> Void)?

    /// Same wash as the Debug toolbar when connected (`Color.green.opacity(0.18)`).
    static var debugHighlightColor: NSColor {
        NSColor.systemGreen.withAlphaComponent(0.18)
    }

    /// Pale red wash for enabled BREAK-table words.
    static var breakpointHighlightColor: NSColor {
        NSColor.systemRed.withAlphaComponent(0.14)
    }

    /// Gray wash for disabled BREAK-table words (still marked, will not fire).
    static var breakpointDisabledHighlightColor: NSColor {
        NSColor.systemGray.withAlphaComponent(0.22)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.findBarPosition = .aboveContent

        let tv = EditorNSTextView()
        tv.delegate = context.coordinator
        tv.isRichText = false
        tv.allowsUndo = true
        tv.usesFindBar = true
        tv.isIncrementalSearchingEnabled = true
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isEditable = !isViewMode
        tv.isSelectable = true
        tv.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        tv.string = text
        tv.minSize = NSSize(width: 0, height: 0)
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                            height: CGFloat.greatestFiniteMagnitude)
        tv.isVerticallyResizable = true
        // Always hard-wrap off (⌘\ is Toggle Breakpoint).
        tv.isHorizontallyResizable = true
        tv.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        tv.textContainer?.widthTracksTextView = false
        tv.autoresizingMask = []

        scroll.documentView = tv
        let ruler = LineNumberRulerView(textView: tv)
        scroll.verticalRulerView = ruler
        scroll.hasVerticalRuler = showLineNumbers
        scroll.rulersVisible = showLineNumbers
        context.coordinator.lineNumberRuler = ruler
        context.coordinator.textView = tv
        context.coordinator.installCommandClick(on: tv)
        context.coordinator.installKeyMonitor()
        context.coordinator.installScrollObserver(on: scroll)
        context.coordinator.needsRestore = true
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let tv = scroll.documentView as? NSTextView else { return }
        if let editor = tv as? EditorNSTextView {
            context.coordinator.installCommandClick(on: editor)
        }

        if scroll.hasVerticalRuler != showLineNumbers || scroll.rulersVisible != showLineNumbers {
            scroll.hasVerticalRuler = showLineNumbers
            scroll.rulersVisible = showLineNumbers
            if showLineNumbers {
                context.coordinator.lineNumberRuler?.invalidate()
            }
        }

        let textChanged = tv.string != text
        if textChanged {
            // Replacing the string resets caret/scroll; restore afterward unless goto wins.
            context.coordinator.suppressSave = true
            tv.string = text
            context.coordinator.suppressSave = false
            context.coordinator.needsRestore = true
            context.coordinator.lineNumberRuler?.invalidate()
        }
        tv.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        tv.isEditable = !isViewMode
        context.coordinator.lineNumberRuler?.syncFont(from: tv)

        tv.isHorizontallyResizable = true
        tv.autoresizingMask = []
        tv.textContainer?.widthTracksTextView = false
        tv.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )

        // Session ended: drop the wash. Do **not** clear when highlightName is
        // merely consumed (finishGoto/finishHighlightOnly nil it after apply) —
        // that used to wipe the temporary attribute on the next update pass.
        if !isDebugArmed {
            context.coordinator.clearDebugHighlight()
        }

        // BREAK-table wash (independent of DEBUG green).
        context.coordinator.applyBreakpointWash(entries: breakpointEntries, force: textChanged)

        if let line = gotoLine, line > 0 {
            context.coordinator.needsRestore = false
            let attempt = line
            let name = highlightName
            let off = highlightOff
            let len = highlightLen
            let epoch = highlightEpoch
            DispatchQueue.main.async {
                self.finishGoto(
                    scroll: scroll,
                    coordinator: context.coordinator,
                    line: attempt,
                    highlightName: name,
                    highlightOff: off,
                    highlightLen: len,
                    epoch: epoch
                )
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.finishGoto(
                    scroll: scroll,
                    coordinator: context.coordinator,
                    line: attempt,
                    highlightName: name,
                    highlightOff: off,
                    highlightLen: len,
                    epoch: epoch
                )
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.finishGoto(
                    scroll: scroll,
                    coordinator: context.coordinator,
                    line: attempt,
                    highlightName: name,
                    highlightOff: off,
                    highlightLen: len,
                    epoch: epoch
                )
            }
        } else if isDebugArmed, hasPendingHighlight {
            // Location already scrolled; only the token / span changed (same-line step).
            let name = highlightName
            let off = highlightOff
            let len = highlightLen
            let epoch = highlightEpoch
            DispatchQueue.main.async {
                self.finishHighlightOnly(
                    scroll: scroll,
                    coordinator: context.coordinator,
                    name: name,
                    off: off,
                    len: len,
                    epoch: epoch
                )
            }
        } else if context.coordinator.needsRestore {
            let attemptSelection = selection
            let attemptTop = topVisibleLine
            DispatchQueue.main.async {
                context.coordinator.restoreViewState(
                    scroll: scroll,
                    selection: attemptSelection,
                    topLine: attemptTop
                )
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                context.coordinator.restoreViewState(
                    scroll: scroll,
                    selection: attemptSelection,
                    topLine: attemptTop
                )
            }
        }
    }

    private var hasPendingHighlight: Bool {
        if let len = highlightLen, len > 0, let off = highlightOff, off >= 0 { return true }
        if let name = highlightName, !name.isEmpty { return true }
        return false
    }

    private func finishGoto(
        scroll: NSScrollView,
        coordinator: Coordinator,
        line: Int,
        highlightName: String?,
        highlightOff: Int?,
        highlightLen: Int?,
        epoch: UInt
    ) {
        guard coordinator.parent.gotoLine == nil || coordinator.parent.gotoLine == line else { return }
        guard let tv = scroll.documentView as? NSTextView else { return }
        coordinator.suppressSave = true
        if PendingGoto.scroll(tv, toLine: line) {
            // Only the attempt that consumes gotoLine may paint. Later layout
            // retries only keep the line visible; a stale capture from an
            // earlier pause must not overwrite a newer span (same VIEW line).
            let consuming = coordinator.parent.gotoLine == line
            if consuming {
                coordinator.parent.gotoLine = nil
            }
            let epochCurrent = coordinator.parent.highlightEpoch == epoch
            let pendingName = highlightName.map { !$0.isEmpty } ?? false
            let pendingSpan = (highlightLen ?? 0) > 0 && (highlightOff ?? -1) >= 0
            if consuming, epochCurrent, (pendingName || pendingSpan) {
                coordinator.applyDebugHighlight(
                    in: tv,
                    name: highlightName,
                    nearLine: line,
                    off: highlightOff,
                    len: highlightLen
                )
                coordinator.parent.highlightName = nil
                coordinator.parent.highlightOff = nil
                coordinator.parent.highlightLen = nil
            }
            coordinator.captureViewState(from: tv)
            coordinator.needsRestore = false
        }
        coordinator.suppressSave = false
    }

    private func finishHighlightOnly(
        scroll: NSScrollView,
        coordinator: Coordinator,
        name: String?,
        off: Int?,
        len: Int?,
        epoch: UInt
    ) {
        guard coordinator.parent.highlightEpoch == epoch else { return }
        let stillName = name == nil || coordinator.parent.highlightName == name
        let stillOff = off == nil || coordinator.parent.highlightOff == off
        let stillLen = len == nil || coordinator.parent.highlightLen == len
        guard stillName, stillOff, stillLen else { return }
        guard let tv = scroll.documentView as? NSTextView else { return }
        coordinator.suppressSave = true
        let line = PendingGoto.lineNumber(atCaretIn: tv) ?? 1
        coordinator.applyDebugHighlight(in: tv, name: name, nearLine: line, off: off, len: len)
        coordinator.parent.highlightName = nil
        coordinator.parent.highlightOff = nil
        coordinator.parent.highlightLen = nil
        coordinator.captureViewState(from: tv)
        coordinator.suppressSave = false
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditorTextView
        weak var textView: NSTextView?
        private var keyMonitor: Any?
        private var scrollObserver: NSObjectProtocol?
        private var focusObserver: NSObjectProtocol?
        /// Skip writing bindings while we programmatically move caret/scroll.
        var suppressSave = false
        /// Apply saved selection / top line once the view is ready.
        var needsRestore = false
        /// Character range of the last pastel-green DEBUG token highlight.
        private var debugHighlightRange: NSRange?
        /// Character ranges painted for BREAK-table words (red or gray).
        private var breakpointHighlightRanges: [NSRange] = []
        /// Last applied BREAK entries (skip redundant rewashes).
        private var lastBreakpointEntries: [BreakpointEntry] = []
        /// SZ-style 5-column line-number gutter (source editor only).
        weak var lineNumberRuler: LineNumberRulerView?
        private var toggleBreakpointObserver: NSObjectProtocol?

        init(_ parent: EditorTextView) { self.parent = parent }

        func clearDebugHighlight() {
            guard let tv = textView, let layout = tv.layoutManager else {
                debugHighlightRange = nil
                return
            }
            let charCount = (tv.string as NSString).length
            if let prev = debugHighlightRange, NSMaxRange(prev) <= charCount {
                layout.removeTemporaryAttribute(.backgroundColor, forCharacterRange: prev)
            }
            debugHighlightRange = nil
        }

        func clearBreakpointWash() {
            guard let tv = textView, let layout = tv.layoutManager else {
                breakpointHighlightRanges = []
                lastBreakpointEntries = []
                return
            }
            let charCount = (tv.string as NSString).length
            for prev in breakpointHighlightRanges where NSMaxRange(prev) <= charCount {
                // Leave the live DEBUG green wash alone when ranges overlap.
                if let dbg = debugHighlightRange, NSIntersectionRange(dbg, prev).length > 0 {
                    continue
                }
                layout.removeTemporaryAttribute(.backgroundColor, forCharacterRange: prev)
            }
            breakpointHighlightRanges = []
            lastBreakpointEntries = []
        }

        /// Whole-word wash for every occurrence of each BREAK name.
        /// Enabled → pale-red; disabled → gray. Forward-only scan (see Pass 1).
        ///
        /// Must scan forward-only. `forthTokenRange(at:)` backs up from a blank
        /// into the previous token (caret/F9 semantics); using it here left
        /// `idx` on that blank forever → main-thread spin / beach ball.
        func applyBreakpointWash(entries: [BreakpointEntry], force: Bool = false) {
            guard let tv = textView else { return }
            let normalized = entries
                .map {
                    BreakpointEntry(
                        name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines),
                        enabled: $0.enabled
                    )
                }
                .filter { !$0.name.isEmpty }
            if !force, normalized == lastBreakpointEntries { return }
            clearBreakpointWash()
            lastBreakpointEntries = normalized
            guard !normalized.isEmpty, let layout = tv.layoutManager else { return }
            let ns = tv.string as NSString
            let charCount = ns.length
            var painted: [NSRange] = []
            var enabledByName: [String: Bool] = [:]
            for e in normalized {
                // Later duplicate name wins; host table should be unique.
                enabledByName[e.name] = e.enabled
            }
            func isSep(_ c: unichar) -> Bool {
                c == 32 || c == 9 || c == 10 || c == 13
            }
            var idx = 0
            while idx < charCount {
                if isSep(ns.character(at: idx)) {
                    idx += 1
                    continue
                }
                var hi = idx + 1
                while hi < charCount && !isSep(ns.character(at: hi)) { hi += 1 }
                let range = NSRange(location: idx, length: hi - idx)
                let token = ns.substring(with: range)
                if let enabled = enabledByName[token] {
                    // Do not overwrite the live DEBUG green wash.
                    let overlapsDebug = debugHighlightRange.map {
                        NSIntersectionRange($0, range).length > 0
                    } ?? false
                    if !overlapsDebug {
                        let color = enabled
                            ? EditorTextView.breakpointHighlightColor
                            : EditorTextView.breakpointDisabledHighlightColor
                        layout.addTemporaryAttribute(
                            .backgroundColor,
                            value: color,
                            forCharacterRange: range
                        )
                        painted.append(range)
                    }
                }
                idx = hi
            }
            breakpointHighlightRanges = painted
            for range in painted {
                layout.invalidateDisplay(forCharacterRange: range)
            }
        }

        /// Prefer dbg-map file-relative `off`/`len` when present; else whole-word
        /// search near `nearLine` (1-based). Pastel green wash, not system selection.
        /// If no token match (e.g. LIT without maps), collapse the scroll line selection
        /// so the whole line does not stay gray.
        func applyDebugHighlight(
            in tv: NSTextView,
            name: String?,
            nearLine: Int,
            off: Int? = nil,
            len: Int? = nil
        ) {
            clearDebugHighlight()
            let ns = tv.string as NSString
            let charCount = ns.length
            var range: NSRange?
            if let off, let len, len > 0, off >= 0 {
                // dbg-map offsets are UTF-8 byte offsets into the file bytes.
                if let utf8Range = Self.nsRange(fromUTF8Offset: off, length: len, in: tv.string),
                   NSMaxRange(utf8Range) <= charCount {
                    range = utf8Range
                }
            }
            if range == nil, let name, !name.isEmpty {
                range = PendingGoto.findWholeWord(name, in: tv.string, nearLine: nearLine)
            }
            guard let range else {
                let loc = PendingGoto.startIndex(ofLine: max(nearLine, 1), in: ns)
                let caret = min(loc, max(0, charCount))
                tv.setSelectedRange(NSRange(location: caret, length: 0))
                return
            }
            guard let layout = tv.layoutManager else { return }
            layout.addTemporaryAttribute(
                .backgroundColor,
                value: EditorTextView.debugHighlightColor,
                forCharacterRange: range
            )
            layout.invalidateDisplay(forCharacterRange: range)
            debugHighlightRange = range
            tv.scrollRangeToVisible(range)
            // Keep a collapsed caret at the token so browse-mode keys still work;
            // do not leave a system selection (that would hide the green wash).
            tv.setSelectedRange(NSRange(location: range.location, length: 0))
        }

        /// Map a UTF-8 byte offset/length into an NSString UTF-16 NSRange.
        private static func nsRange(fromUTF8Offset off: Int, length len: Int, in text: String) -> NSRange? {
            guard off >= 0, len > 0 else { return nil }
            let utf8 = text.utf8
            guard off + len <= utf8.count else { return nil }
            let startIdx = utf8.index(utf8.startIndex, offsetBy: off)
            let endIdx = utf8.index(startIdx, offsetBy: len)
            guard let from = String.Index(startIdx, within: text),
                  let to = String.Index(endIdx, within: text) else { return nil }
            return NSRange(from..<to, in: text)
        }

        deinit {
            if let keyMonitor {
                NSEvent.removeMonitor(keyMonitor)
            }
            if let scrollObserver {
                NotificationCenter.default.removeObserver(scrollObserver)
            }
            if let focusObserver {
                NotificationCenter.default.removeObserver(focusObserver)
            }
            if let toggleBreakpointObserver {
                NotificationCenter.default.removeObserver(toggleBreakpointObserver)
            }
        }

        func installCommandClick(on tv: EditorNSTextView) {
            tv.onCommandClickWord = { [weak self] word in
                self?.parent.onCommandClickWord?(word)
            }
        }

        func installKeyMonitor() {
            guard keyMonitor == nil else { return }
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                return self.handleKeyDown(event)
            }
            if focusObserver == nil {
                focusObserver = NotificationCenter.default.addObserver(
                    forName: .sixtyFourEditFocusEditor,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    self?.takeKeyFocus()
                }
            }
            if toggleBreakpointObserver == nil {
                toggleBreakpointObserver = NotificationCenter.default.addObserver(
                    forName: .sixtyFourEditToggleBreakpoint,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    self?.toggleBreakpointUnderCaret()
                }
            }
        }

        /// F9 / ⌘\ / Debug menu: toggle BREAK on the whitespace-delimited token at the caret.
        func toggleBreakpointUnderCaret() {
            guard let tv = textView else { return }
            let ns = tv.string as NSString
            var idx = tv.selectedRange().location
            if idx > ns.length { idx = ns.length }
            guard let word = EditorNSTextView.forthToken(at: idx, in: ns),
                  !word.isEmpty,
                  word.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
            else { return }
            parent.onToggleBreakpoint?(word)
        }

        /// Become first responder when DEBUG arms or a pause updates the location.
        func takeKeyFocus() {
            guard let tv = textView, let window = tv.window else { return }
            // Only the selected tab's representable should win; skip detached views.
            guard tv.window?.isKeyWindow == true || window == NSApp.keyWindow else { return }
            window.makeFirstResponder(tv)
        }

        func installScrollObserver(on scroll: NSScrollView) {
            guard scrollObserver == nil else { return }
            scroll.contentView.postsBoundsChangedNotifications = true
            scrollObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: scroll.contentView,
                queue: .main
            ) { [weak self] _ in
                guard let self, let tv = self.textView else { return }
                self.lineNumberRuler?.invalidate()
                guard !self.suppressSave else { return }
                self.captureViewState(from: tv)
            }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !suppressSave,
                  let tv = notification.object as? NSTextView
            else { return }
            captureViewState(from: tv)
        }

        func captureViewState(from tv: NSTextView) {
            let sel = tv.selectedRange()
            let clamped = Self.clampedSelection(sel, in: tv.string)
            if parent.selection != clamped {
                parent.selection = clamped
            }
            let top = Self.topVisibleLine(of: tv)
            if parent.topVisibleLine != top {
                parent.topVisibleLine = top
            }
        }

        func restoreViewState(scroll: NSScrollView, selection: NSRange, topLine: Int) {
            guard needsRestore else { return }
            guard parent.gotoLine == nil else { return }
            guard let tv = scroll.documentView as? NSTextView else { return }
            suppressSave = true
            let sel = Self.clampedSelection(selection, in: tv.string)
            tv.setSelectedRange(sel)
            _ = Self.scroll(tv, soTopLineIs: topLine)
            // Layout may still be settling; only clear after a successful pin, or accept
            // line 1 / empty as done so we do not loop forever.
            if tv.string.isEmpty || topLine <= 1 || Self.topVisibleLine(of: tv) > 0 {
                needsRestore = false
                parent.selection = sel
                parent.topVisibleLine = max(1, Self.topVisibleLine(of: tv))
            }
            suppressSave = false
        }

        static func clampedSelection(_ range: NSRange, in string: String) -> NSRange {
            let len = (string as NSString).length
            let loc = min(max(0, range.location), len)
            let maxLen = len - loc
            let length = min(max(0, range.length), maxLen)
            return NSRange(location: loc, length: length)
        }

        /// 1-based line at the top of the visible clip.
        static func topVisibleLine(of tv: NSTextView) -> Int {
            guard let scroll = tv.enclosingScrollView,
                  let layout = tv.layoutManager,
                  let container = tv.textContainer
            else { return 1 }
            layout.ensureLayout(for: container)
            guard layout.numberOfGlyphs > 0 else { return 1 }
            let origin = scroll.contentView.bounds.origin
            var point = tv.convert(origin, from: scroll.contentView)
            point.x -= tv.textContainerOrigin.x
            point.y -= tv.textContainerOrigin.y
            point.y = max(0, point.y)
            let glyphIndex = layout.glyphIndex(for: point, in: container, fractionOfDistanceThroughGlyph: nil)
            let safeGlyph = min(max(0, glyphIndex), layout.numberOfGlyphs - 1)
            let charIndex = layout.characterIndexForGlyph(at: safeGlyph)
            return lineNumber(forCharacter: charIndex, in: tv.string)
        }

        /// Pin `line` (1-based) to the top of the scroll view. Returns false if empty.
        @discardableResult
        static func scroll(_ tv: NSTextView, soTopLineIs line: Int) -> Bool {
            let ns = tv.string as NSString
            guard ns.length > 0 else { return false }
            let target = max(1, line)
            var current = 1
            var idx = 0
            while current < target && idx < ns.length {
                let para = ns.paragraphRange(for: NSRange(location: idx, length: 0))
                let next = NSMaxRange(para)
                if next <= idx { break }
                idx = next
                current += 1
            }
            let loc = min(idx, max(0, ns.length - 1))
            let range = ns.paragraphRange(for: NSRange(location: loc, length: 0))
            guard let layout = tv.layoutManager,
                  let container = tv.textContainer,
                  let scroll = tv.enclosingScrollView
            else {
                tv.scrollRangeToVisible(range)
                return true
            }
            layout.ensureLayout(for: container)
            let glyph = layout.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            let rect = layout.boundingRect(forGlyphRange: glyph, in: container)
            let pointInTV = NSPoint(
                x: 0,
                y: rect.origin.y + tv.textContainerOrigin.y
            )
            let pointInClip = scroll.contentView.convert(pointInTV, from: tv)
            let clip = scroll.contentView
            let maxY = max(0, (scroll.documentView?.bounds.height ?? 0) - clip.bounds.height)
            let y = min(max(0, pointInClip.y), maxY)
            clip.scroll(to: NSPoint(x: clip.bounds.origin.x, y: y))
            scroll.reflectScrolledClipView(clip)
            return true
        }

        static func lineNumber(forCharacter index: Int, in string: String) -> Int {
            let ns = string as NSString
            guard ns.length > 0 else { return 1 }
            let loc = min(max(0, index), ns.length)
            var current = 1
            var idx = 0
            while idx < loc {
                let para = ns.paragraphRange(for: NSRange(location: idx, length: 0))
                let next = NSMaxRange(para)
                if next <= idx { break }
                if next > loc { break }
                idx = next
                current += 1
            }
            return current
        }

        private func editorIsFocused(_ tv: NSTextView) -> Bool {
            guard let window = tv.window, window.isKeyWindow else { return false }
            let fr = window.firstResponder
            return fr === tv
                || fr === tv.enclosingScrollView
                || (fr as? NSView)?.isDescendant(of: tv) == true
        }

        private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
            guard let tv = textView, editorIsFocused(tv) else {
                return event
            }

            // F9 / ⌘\ — toggle BREAK under caret (works while idle or debugging).
            if tryHandleBreakpointKey(event) {
                return nil
            }

            // Idle F5 family — steal from NSTextView Complete (default F5 binding).
            if !parent.isDebugArmed, tryHandleRunKey(event) {
                return nil
            }

            // DEBUG armed: F-keys / ⌘⇧Y always; Forth letter keys only in view mode
            // so edit-mode typing and the console field stay unaffected.
            if parent.isDebugArmed, tryHandleDebugKey(event) {
                return nil
            }

            guard parent.isViewMode else {
                return event
            }

            // Allow navigation / copy / find; swallow edits (no Switch to Edit dialog).
            if event.modifierFlags.contains(.command) {
                let chars = event.charactersIgnoringModifiers?.lowercased() ?? ""
                if ["c", "a", "f", "g"].contains(chars) { return event }
                if chars == "x" || chars == "v" || chars == "z" {
                    return nil
                }
                return event
            }
            if event.modifierFlags.contains(.function) || event.modifierFlags.contains(.numericPad) {
                return event
            }
            switch event.keyCode {
            case 123, 124, 125, 126, // arrows
                 115, 119, 116, 121, // home/end/page
                 53:  // escape
                return event
            case 48, 51, 117: // tab / delete / forward delete
                return nil
            default:
                break
            }
            // Any character / return / space is an edit attempt in view mode.
            if let chars = event.characters, !chars.isEmpty {
                return nil
            }
            return event
        }

        /// F9 or ⌘\ toggles BREAK on the token under the caret.
        private func tryHandleBreakpointKey(_ event: NSEvent) -> Bool {
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if !mods.contains(.command), event.keyCode == 101 { // F9
                toggleBreakpointUnderCaret()
                return true
            }
            if mods.contains(.command), !mods.contains(.shift),
               (event.charactersIgnoringModifiers ?? "") == "\\" {
                toggleBreakpointUnderCaret()
                return true
            }
            return false
        }

        /// F5 / ⌘F5 / ⌘⇧F5 while idle → console fill from LAST.
        private func tryHandleRunKey(_ event: NSEvent) -> Bool {
            guard let kind = ForthConnectionManager.runLineKind(from: event) else { return false }
            parent.onPrepareRunLine?(kind)
            return true
        }

        /// Consume Forth DEBUG keys while the session is armed. Returns true if handled.
        ///
        /// F5 continue, F6 over, F7 into, F8 out, ⌘⇧Y continue — always.
        /// Space/o/Return over, i into, g continue, q/Esc stop, h swallow — view mode only.
        private func tryHandleDebugKey(_ event: NSEvent) -> Bool {
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // ⌘⇧Y = continue (same as 64Forth console).
            if mods.contains(.command), mods.contains(.shift),
               (event.charactersIgnoringModifiers?.lowercased() ?? "") == "y" {
                parent.onDebugContinue?()
                return true
            }

            // Function keys by hardware keyCode (AppKit: F5=96 … F8=100).
            switch event.keyCode {
            case 96:  // F5
                parent.onDebugContinue?()
                return true
            case 97:  // F6
                parent.onDebugStepOver?()
                return true
            case 98:  // F7
                parent.onDebugStepInto?()
                return true
            case 100: // F8
                parent.onDebugStepOut?()
                return true
            default:
                break
            }

            // Letter / Esc / Return only in view mode — never steal edit-mode typing.
            guard parent.isViewMode else { return false }
            if mods.contains(.command) || mods.contains(.option) || mods.contains(.control) {
                return false
            }

            if event.keyCode == 53 { // Esc → stop
                parent.onDebugStop?()
                return true
            }
            if event.keyCode == 36 { // Return → step over
                parent.onDebugStepOver?()
                return true
            }

            let ch = event.charactersIgnoringModifiers?.lowercased() ?? ""
            switch ch {
            case " ", "o":
                parent.onDebugStepOver?()
                return true
            case "i":
                parent.onDebugStepInto?()
                return true
            case "g":
                parent.onDebugContinue?()
                return true
            case "q":
                parent.onDebugStop?()
                return true
            case "h":
                // Console prints help; swallow so browse mode stays quiet.
                return true
            default:
                return false
            }
        }

        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            // Browse / VIEW: refuse edits silently (banner Edit / ⌘⇧E / Browse Mode unlock).
            !parent.isViewMode
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
            lineNumberRuler?.invalidate()
            if !suppressSave {
                captureViewState(from: tv)
            }
        }
    }
}

/// NSTextView that turns ⌘-click into a Forth-token VIEW callback.
final class EditorNSTextView: NSTextView {
    var onCommandClickWord: ((String) -> Void)?

    override func mouseDown(with event: NSEvent) {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if mods.contains(.command) {
            let pt = convert(event.locationInWindow, from: nil)
            let idx = characterIndexForInsertion(at: pt)
            let ns = string as NSString
            if let word = Self.forthToken(at: idx, in: ns),
               word.rangeOfCharacter(from: .whitespacesAndNewlines) == nil {
                let caret = min(max(0, idx), ns.length)
                setSelectedRange(NSRange(location: caret, length: 0))
                window?.makeFirstResponder(self)
                onCommandClickWord?(word)
                return
            }
        }
        super.mouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        // Belt-and-suspenders: default F5 binding is Complete — never let it through
        // if the local monitor somehow misses an idle RUN chord.
        if event.keyCode == 96 {
            return
        }
        if handleHomeEndKeys(event) { return }
        super.keyDown(with: event)
    }

    /// Whitespace-delimited Forth token range at UTF-16 index (same rules as 64Forth console).
    static func forthTokenRange(at idx: Int, in ns: NSString) -> NSRange? {
        guard ns.length > 0 else { return nil }
        var i = min(max(0, idx), ns.length)
        func isSep(_ c: unichar) -> Bool {
            c == 32 || c == 9 || c == 10 || c == 13
        }
        if i > 0 && i < ns.length && isSep(ns.character(at: i)) {
            i -= 1
        }
        if i >= ns.length { i = ns.length - 1 }
        if isSep(ns.character(at: i)) { return nil }
        var lo = i
        var hi = i + 1
        while lo > 0 && !isSep(ns.character(at: lo - 1)) { lo -= 1 }
        while hi < ns.length && !isSep(ns.character(at: hi)) { hi += 1 }
        let range = NSRange(location: lo, length: hi - lo)
        return range.length > 0 ? range : nil
    }

    /// Whitespace-delimited Forth token at UTF-16 index (same rules as 64Forth console).
    static func forthToken(at idx: Int, in ns: NSString) -> String? {
        guard let range = forthTokenRange(at: idx, in: ns) else { return nil }
        return ns.substring(with: range)
    }
}

extension NSTextView {
    /// Home/End → current line; ⌘-Home / ⌘-End → start/end of file.
    /// Shift extends the selection. Returns true when the event was handled.
    @discardableResult
    func handleHomeEndKeys(_ event: NSEvent) -> Bool {
        let key = event.keyCode
        guard key == 115 || key == 119 else { return false }
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        // Leave Option/Control chords to the system.
        if mods.contains(.option) || mods.contains(.control) { return false }
        let shift = mods.contains(.shift)
        let command = mods.contains(.command)

        switch (key, command, shift) {
        case (115, false, false):
            moveToBeginningOfLine(nil)
        case (115, false, true):
            moveToBeginningOfLineAndModifySelection(nil)
        case (115, true, false):
            moveToBeginningOfDocument(nil)
        case (115, true, true):
            moveToBeginningOfDocumentAndModifySelection(nil)
        case (119, false, false):
            moveToEndOfLine(nil)
        case (119, false, true):
            moveToEndOfLineAndModifySelection(nil)
        case (119, true, false):
            moveToEndOfDocument(nil)
        case (119, true, true):
            moveToEndOfDocumentAndModifySelection(nil)
        default:
            return false
        }
        return true
    }
}
