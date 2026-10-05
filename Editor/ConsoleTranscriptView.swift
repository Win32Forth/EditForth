//
//  ConsoleTranscriptView.swift
//  64Edit
//
//  Read-only console transcript (NSTextView) with ⌘-click → VIEW, matching
//  the 64Forth console Hyper path via ForthConnectionManager.viewWord.
//

import SwiftUI
import AppKit

struct ConsoleTranscriptView: NSViewRepresentable {
    var lines: [String]
    var fontSize: CGFloat = 12
    /// From `ForthConnectionManager.consoleRefreshSeq` — bumps on successful VIEW.
    var refreshSeq: UInt = 0
    var onCommandClickWord: ((String) -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = ConsoleScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        // Opaque fill — clear background flashes hard while the splitter resizes.
        scroll.drawsBackground = true
        scroll.backgroundColor = .controlBackgroundColor
        scroll.findBarPosition = .aboveContent

        let tv = ConsoleNSTextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.isRichText = false
        tv.allowsUndo = false
        tv.usesFindBar = true
        tv.isIncrementalSearchingEnabled = true
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        tv.backgroundColor = .controlBackgroundColor
        tv.drawsBackground = true
        tv.minSize = NSSize(width: 0, height: 0)
        tv.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = true
        tv.autoresizingMask = [.width]
        tv.textContainer?.containerSize = NSSize(
            width: scroll.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        tv.textContainer?.widthTracksTextView = true
        tv.string = Self.joined(lines)

        scroll.documentView = tv
        context.coordinator.textView = tv
        context.coordinator.lastRefreshSeq = refreshSeq
        context.coordinator.installCommandClick(on: tv)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let tv = scroll.documentView as? ConsoleNSTextView else { return }
        context.coordinator.installCommandClick(on: tv)

        let wantFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        if tv.font != wantFont {
            tv.font = wantFont
        }

        let next = Self.joined(lines)
        let refreshBump = refreshSeq != context.coordinator.lastRefreshSeq
        context.coordinator.lastRefreshSeq = refreshSeq

        if tv.string != next {
            let wasNearBottom = Self.isNearBottom(scroll)
            let savedOrigin = scroll.contentView.bounds.origin
            tv.string = next
            if wasNearBottom || lines.isEmpty {
                DispatchQueue.main.async {
                    Self.scrollToEnd(tv)
                    Self.refreshDisplay(scroll)
                }
            } else {
                // Keep the user's place in a WORDS list (or any scrolled-up view).
                let clip = scroll.contentView
                let docHeight = scroll.documentView?.bounds.height ?? 0
                let maxY = max(0, docHeight - clip.bounds.height)
                let y = min(max(0, savedOrigin.y), maxY)
                clip.scroll(to: NSPoint(x: savedOrigin.x, y: y))
                Self.refreshDisplay(scroll)
            }
        } else {
            // Sibling editor/tab updates often leave the clip view unpainted while
            // the joined string is unchanged (blank until the user scrolls).
            Self.refreshDisplay(scroll)
        }

        // VIEW bumps refreshSeq before pending-goto finishes editor layout —
        // refresh again after that settle so the transcript stays visible.
        if refreshBump {
            DispatchQueue.main.async {
                Self.refreshDisplay(scroll)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                Self.refreshDisplay(scroll)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                Self.refreshDisplay(scroll)
            }
        }
    }

    private static func joined(_ lines: [String]) -> String {
        lines.joined(separator: "\n")
    }

    private static func isNearBottom(_ scroll: NSScrollView) -> Bool {
        let clip = scroll.contentView.bounds
        let docHeight = scroll.documentView?.bounds.height ?? 0
        let visibleBottom = clip.origin.y + clip.height
        return docHeight - visibleBottom < 40
    }

    private static func scrollToEnd(_ tv: NSTextView) {
        let len = (tv.string as NSString).length
        guard len > 0 else { return }
        tv.scrollRangeToVisible(NSRange(location: len, length: 0))
    }

    /// Re-sync clip view and force a redraw (AppKit often skips paint after a
    /// sibling editor/tab layout until a scroll event arrives).
    private static func refreshDisplay(_ scroll: NSScrollView) {
        scroll.layoutSubtreeIfNeeded()
        if let tv = scroll.documentView as? NSTextView,
           let layout = tv.layoutManager,
           let container = tv.textContainer {
            layout.ensureLayout(for: container)
        }
        scroll.reflectScrolledClipView(scroll.contentView)
        scroll.contentView.needsDisplay = true
        scroll.documentView?.needsDisplay = true
        scroll.needsDisplay = true
        scroll.displayIfNeeded()
        scroll.documentView?.displayIfNeeded()
    }

    final class Coordinator {
        var parent: ConsoleTranscriptView
        weak var textView: ConsoleNSTextView?
        var lastRefreshSeq: UInt = 0

        init(_ parent: ConsoleTranscriptView) { self.parent = parent }

        func installCommandClick(on tv: ConsoleNSTextView) {
            tv.onCommandClickWord = { [weak self] word in
                self?.parent.onCommandClickWord?(word)
            }
        }
    }
}

/// Scroll view that re-syncs its clip after SwiftUI-driven frame changes so the
/// transcript does not go blank when VIEW updates the editor above.
final class ConsoleScrollView: NSScrollView {
    override func setFrameSize(_ newSize: NSSize) {
        let old = frame.size
        super.setFrameSize(newSize)
        guard old != newSize else { return }
        reflectScrolledClipView(contentView)
        contentView.needsDisplay = true
        documentView?.needsDisplay = true
        needsDisplay = true
    }

    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        reflectScrolledClipView(contentView)
        needsDisplay = true
        documentView?.needsDisplay = true
    }
}

/// Console transcript NSTextView — ⌘-click VIEW; distinct from `EditorNSTextView`
/// so DEBUG key routing still defers only when the source editor is focused.
final class ConsoleNSTextView: NSTextView {
    var onCommandClickWord: ((String) -> Void)?

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
                onCommandClickWord?(word)
                return
            }
        }
        super.mouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if handleHomeEndKeys(event) { return }
        super.keyDown(with: event)
    }
}
