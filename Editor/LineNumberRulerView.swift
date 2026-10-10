//
//  LineNumberRulerView.swift
//  64Edit
//
//  SZ-style gutter: 5-column right-justified line numbers on the source editor.
//

import AppKit

/// Vertical ruler that draws 1-based paragraph line numbers, right-justified in
/// a fixed 5-digit field (same width as FILE-ECHO / SZ-EDITOR).
final class LineNumberRulerView: NSRulerView {
    /// Digits in the number field (SZ / FILE-ECHO use 5).
    static let digitColumns = 5

    private var font: NSFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    private var textObserver: NSObjectProtocol?
    private var frameObserver: NSObjectProtocol?
    /// 1-based line → enabled. Drawn as a gutter dot (red enabled, gray off).
    private var gutterMarks: [Int: Bool] = [:]

    convenience init(textView: NSTextView) {
        self.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        clientView = textView
        font = textView.font
            ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        ruleThickness = Self.thickness(for: font)
        clipsToBounds = true
        installObservers(for: textView)
    }

    override init(scrollView: NSScrollView?, orientation: NSRulerView.Orientation) {
        super.init(scrollView: scrollView, orientation: orientation)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let textObserver { NotificationCenter.default.removeObserver(textObserver) }
        if let frameObserver { NotificationCenter.default.removeObserver(frameObserver) }
    }

    /// Match editor font and recompute gutter width (5 monospaced digits + pad).
    func syncFont(from textView: NSTextView) {
        let next = textView.font
            ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        if next != font {
            font = next
            let thick = Self.thickness(for: next)
            if abs(ruleThickness - thick) > 0.5 {
                ruleThickness = thick
            }
        }
        needsDisplay = true
    }

    func invalidate() {
        needsDisplay = true
    }

    /// Breakpoint dots. `line` is 1-based. `enabled` false draws gray.
    func setGutterMarks(_ marks: [Int: Bool]) {
        gutterMarks = marks
        needsDisplay = true
    }

    static func thickness(for font: NSFont) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let field = String(repeating: "0", count: digitColumns) as NSString
        let width = field.size(withAttributes: attrs).width
        // Left pad + number field + right pad before the text edge.
        return ceil(width) + 14
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = clientView as? NSTextView,
              let layout = textView.layoutManager,
              let container = textView.textContainer,
              let scroll = scrollView
        else { return }

        NSColor.controlBackgroundColor.setFill()
        bounds.fill()

        // Gutter | text rule (a bit bolder than a 1pt hairline).
        let sepX = bounds.maxX - 1
        NSColor.secondaryLabelColor.withAlphaComponent(0.45).setFill()
        NSRect(x: sepX - 0.5, y: bounds.minY, width: 1.5, height: bounds.height).fill()

        layout.ensureLayout(for: container)

        let originInRuler = convert(NSPoint.zero, from: textView)
        let inset = textView.textContainerOrigin

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.secondaryLabelColor
        ]

        let ns = textView.string as NSString
        if ns.length == 0 {
            drawLabel("    1", atTextY: inset.y, originInRuler: originInRuler, attrs: attrs)
            return
        }

        var visible = textView.convert(scroll.contentView.bounds, from: scroll.contentView)
        visible.origin.x -= inset.x
        visible.origin.y -= inset.y
        var glyphRange = layout.glyphRange(forBoundingRect: visible, in: container)
        if glyphRange.length == 0 { return }

        // Back up to the start of the first visible hard line so a wrapped
        // continuation does not suppress the real line number.
        let charRange = layout.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        let lineStart = ns.lineRange(for: NSRange(location: charRange.location, length: 0)).location
        let startGlyph = layout.glyphIndexForCharacter(at: lineStart)
        glyphRange = NSRange(
            location: startGlyph,
            length: max(0, NSMaxRange(glyphRange) - startGlyph)
        )

        var line = Self.lineNumber(forCharacter: lineStart, in: ns)
        var glyphIndex = glyphRange.location
        let endGlyph = NSMaxRange(glyphRange)

        while glyphIndex < endGlyph {
            var fragRange = NSRange()
            let fragRect = layout.lineFragmentRect(
                forGlyphAt: glyphIndex,
                effectiveRange: &fragRange
            )
            let charIndex = layout.characterIndexForGlyph(at: glyphIndex)
            let hardLine = ns.lineRange(for: NSRange(location: charIndex, length: 0))
            // Number only the first fragment of each hard line (wraps stay blank).
            if charIndex == hardLine.location {
                let label = String(format: "%\(Self.digitColumns)d", line)
                let y = fragRect.minY + inset.y
                if let enabled = gutterMarks[line] {
                    drawBreakDot(enabled: enabled, atTextY: y, originInRuler: originInRuler)
                }
                drawLabel(
                    label,
                    atTextY: y,
                    originInRuler: originInRuler,
                    attrs: attrs
                )
                line += 1
            }
            let next = NSMaxRange(fragRange)
            if next <= glyphIndex { break }
            glyphIndex = next
        }
    }

    private func drawBreakDot(enabled: Bool, atTextY y: CGFloat, originInRuler: NSPoint) {
        let d: CGFloat = 7
        let yPos = originInRuler.y + y + font.ascender * 0.35
        let rect = NSRect(x: 3, y: yPos, width: d, height: d)
        let color = enabled
            ? NSColor.systemRed.withAlphaComponent(0.9)
            : NSColor.systemGray.withAlphaComponent(0.85)
        color.setFill()
        NSBezierPath(ovalIn: rect).fill()
    }

    private func drawLabel(
        _ label: String,
        atTextY y: CGFloat,
        originInRuler: NSPoint,
        attrs: [NSAttributedString.Key: Any]
    ) {
        let size = (label as NSString).size(withAttributes: attrs)
        let x = bounds.maxX - 6 - size.width
        // Align with the line fragment top, nudged toward the text baseline.
        let yPos = originInRuler.y + y + (font.ascender - size.height) * 0.35
        (label as NSString).draw(at: NSPoint(x: x, y: yPos), withAttributes: attrs)
    }

    private func installObservers(for textView: NSTextView) {
        textObserver = NotificationCenter.default.addObserver(
            forName: NSText.didChangeNotification,
            object: textView,
            queue: .main
        ) { [weak self] _ in
            self?.needsDisplay = true
        }
        frameObserver = NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification,
            object: textView,
            queue: .main
        ) { [weak self] _ in
            self?.needsDisplay = true
        }
        textView.postsFrameChangedNotifications = true
    }

    static func lineNumber(forCharacter index: Int, in ns: NSString) -> Int {
        guard ns.length > 0 else { return 1 }
        let loc = min(max(0, index), ns.length)
        var current = 1
        var idx = 0
        while idx < loc {
            let line = ns.lineRange(for: NSRange(location: idx, length: 0))
            let next = NSMaxRange(line)
            if next <= idx { break }
            if next > loc { break }
            idx = next
            current += 1
        }
        return current
    }
}
