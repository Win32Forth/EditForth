//
//  MarkdownPreviewView.swift
//  64Edit
//
//  Read-only formatted display for Markdown tabs. Source mode stays the
//  plain-text editor. This view does not apply formatting edits.
//

import AppKit
import Foundation
import SwiftUI

/// Walks `AttributedString` markdown runs and builds a styled text view.
/// The system parser attaches presentation intents and does not apply fonts.
enum MarkdownPreviewRenderer {
    static func render(markdown: String, bodyPointSize: CGFloat) -> NSAttributedString {
        let size = max(9, bodyPointSize)
        guard !markdown.isEmpty else { return NSAttributedString(string: "") }
        do {
            var options = AttributedString.MarkdownParsingOptions()
            options.interpretedSyntax = .full
            options.failurePolicy = .returnPartiallyParsedIfPossible
            let parsed = try AttributedString(markdown: markdown, options: options)
            let built = Builder(bodyPointSize: size).build(parsed)
            if built.length > 0 { return built }
        } catch {
            // Show the source text when the parser rejects the file.
        }
        return plain(markdown, bodyPointSize: size)
    }

    private static func plain(_ markdown: String, bodyPointSize: CGFloat) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byWordWrapping
        style.lineSpacing = 2
        return NSAttributedString(string: markdown, attributes: [
            .font: NSFont.systemFont(ofSize: bodyPointSize),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: style
        ])
    }

    /// Label color mixed with the current appearance. Stays correct in Dark Mode.
    fileprivate static func tint(_ alpha: CGFloat) -> NSColor {
        NSColor(name: nil, dynamicProvider: { appearance in
            let dark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let base = dark ? NSColor.white : NSColor.black
            return base.withAlphaComponent(alpha)
        })
    }
}

/// Left bar for a block quote. Per-edge borders are macOS 27; this target is 26.6.
private final class MarkdownQuoteBlock: NSTextBlock {
    override func drawBackground(
        withFrame frameRect: NSRect,
        in controlView: NSView?,
        characterRange charRange: NSRange,
        layoutManager: NSLayoutManager
    ) {
        let bar = NSRect(x: frameRect.minX, y: frameRect.minY, width: 3, height: frameRect.height)
        NSColor.separatorColor.setFill()
        bar.fill()
    }
}

/// Hairline between sections. The paragraph itself is a clear space.
private final class MarkdownRuleBlock: NSTextBlock {
    override func drawBackground(
        withFrame frameRect: NSRect,
        in controlView: NSView?,
        characterRange charRange: NSRange,
        layoutManager: NSLayoutManager
    ) {
        let y = floor(frameRect.midY) + 0.5
        NSColor.separatorColor.setStroke()
        let path = NSBezierPath()
        path.move(to: NSPoint(x: frameRect.minX, y: y))
        path.line(to: NSPoint(x: frameRect.maxX, y: y))
        path.lineWidth = 1
        path.stroke()
    }
}

private struct MarkdownPiece {
    var text: String
    var components: [PresentationIntent.IntentType]
    var inline: InlinePresentationIntent
    var link: URL?
}

private struct MarkdownBlockInfo {
    var headerLevel: Int?
    var isCode = false
    var isRule = false
    var isQuote = false
    var listOrdinal: Int?
    var listOrdered = false
    var listDepth = 0
    var listItemIdentity: Int?
    var columns: [PresentationIntent.TableColumn]?
    var tableIdentity: Int?
    var cellIdentity: Int?
    var tableColumn: Int?
    var tableHeader = false
    var rowIdentity: Int?
}

private struct MarkdownSegment {
    var pieces: [MarkdownPiece]
    var info: MarkdownBlockInfo
}

private final class Builder {
    let bodyPointSize: CGFloat
    private var startedListItems = Set<Int>()
    private var previousWasList = false
    private var atStart = true

    init(bodyPointSize: CGFloat) {
        self.bodyPointSize = bodyPointSize
    }

    func build(_ parsed: AttributedString) -> NSAttributedString {
        let pieces = runs(parsed)
        let segments = group(pieces)
        let result = NSMutableAttributedString()
        var index = 0
        while index < segments.count {
            let info = segments[index].info
            if info.tableIdentity != nil {
                let tableID = info.tableIdentity
                var group: [MarkdownSegment] = []
                while index < segments.count, segments[index].info.tableIdentity == tableID {
                    group.append(segments[index])
                    index += 1
                }
                emitTable(group, into: result)
                previousWasList = false
                atStart = false
            } else {
                emitFlow(segments[index], into: result)
                index += 1
            }
        }
        return result
    }

    private func runs(_ parsed: AttributedString) -> [MarkdownPiece] {
        var pieces: [MarkdownPiece] = []
        for run in parsed.runs {
            let text = String(parsed[run.range].characters)
            pieces.append(MarkdownPiece(
                text: text,
                components: run.presentationIntent?.components ?? [],
                inline: run.inlinePresentationIntent ?? [],
                link: run.link
            ))
        }
        return pieces
    }

    /// Consecutive runs that share an innermost block stay one paragraph.
    private func group(_ pieces: [MarkdownPiece]) -> [MarkdownSegment] {
        var segments: [MarkdownSegment] = []
        var current: [MarkdownPiece] = []
        var key: Int?
        func flush() {
            guard let first = current.first else { return }
            segments.append(MarkdownSegment(pieces: current, info: describe(first.components)))
            current = []
        }
        for piece in pieces {
            let next = piece.components.first?.identity ?? Int.min
            if next != key {
                flush()
                key = next
            }
            current.append(piece)
        }
        flush()
        return segments
    }

    private func describe(_ components: [PresentationIntent.IntentType]) -> MarkdownBlockInfo {
        var info = MarkdownBlockInfo()
        for component in components {
            switch component.kind {
            case .paragraph:
                break
            case .header(let level):
                info.headerLevel = level
            case .codeBlock:
                info.isCode = true
            case .thematicBreak:
                info.isRule = true
            case .blockQuote:
                info.isQuote = true
            case .listItem(let ordinal):
                // Innermost item is first. An outer item must not replace it.
                if info.listItemIdentity == nil {
                    info.listOrdinal = ordinal
                    info.listItemIdentity = component.identity
                }
            case .orderedList:
                // Innermost list is first. Outer lists must not replace it.
                if info.listDepth == 0 { info.listOrdered = true }
                info.listDepth += 1
            case .unorderedList:
                if info.listDepth == 0 { info.listOrdered = false }
                info.listDepth += 1
            case .table(let columns):
                info.columns = columns
                info.tableIdentity = component.identity
            case .tableCell(let columnIndex):
                info.tableColumn = columnIndex
                info.cellIdentity = component.identity
            case .tableHeaderRow:
                info.tableHeader = true
                info.rowIdentity = component.identity
            case .tableRow:
                info.rowIdentity = component.identity
            @unknown default:
                break
            }
        }
        return info
    }

    private func emitFlow(_ segment: MarkdownSegment, into result: NSMutableAttributedString) {
        let info = segment.info
        if info.isRule {
            result.append(ruleParagraph())
            previousWasList = false
            atStart = false
            return
        }
        let text = styledText(segment.pieces, info: info)
        if text.length == 0 && !info.isCode { return }

        let markerFont = makeFont(size: bodyPointSize, mono: false, bold: false, italic: false)
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byWordWrapping
        style.hyphenationFactor = 0
        applySpacing(style, info: info)
        applyListLayout(style, info: info, markerFont: markerFont, text: text)
        var blocks: [NSTextBlock] = []
        if info.isQuote {
            let quote = MarkdownQuoteBlock()
            quote.setContentWidth(100, type: .percentage)
            quote.setWidth(8, type: .absolute, for: .padding)
            quote.setWidth(4, type: .absolute, for: .margin)
            blocks.append(quote)
        }
        if info.isCode {
            let code = NSTextBlock()
            code.backgroundColor = MarkdownPreviewRenderer.tint(0.06)
            code.setContentWidth(100, type: .percentage)
            code.setWidth(8, type: .absolute, for: .padding)
            code.setWidth(1, type: .absolute, for: .border)
            code.setBorderColor(NSColor.separatorColor)
            code.setWidth(6, type: .absolute, for: .margin)
            blocks.append(code)
            style.paragraphSpacing = 0
            style.paragraphSpacingBefore = 2
            style.lineSpacing = 1
        }
        if !blocks.isEmpty { style.textBlocks = blocks }
        let font = makeFont(
            size: info.isCode ? bodyPointSize : pointSize(info),
            mono: info.isCode,
            bold: info.headerLevel != nil,
            italic: false
        )
        finish(text, style: style, font: font)
        result.append(text)
        previousWasList = info.listDepth > 0 && !info.isCode
        atStart = false
    }

    private func emitTable(_ segments: [MarkdownSegment], into result: NSMutableAttributedString) {
        let columns = segments.first?.info.columns ?? []
        var cells: [MarkdownSegment] = []
        for segment in segments {
            if let last = cells.indices.last,
               let id = segment.info.cellIdentity,
               id == cells[last].info.cellIdentity {
                var bridge = segment.pieces.first ?? MarkdownPiece(
                    text: "",
                    components: [],
                    inline: [],
                    link: nil
                )
                bridge.text = "\n"
                bridge.inline = []
                bridge.link = nil
                cells[last].pieces.append(bridge)
                cells[last].pieces.append(contentsOf: segment.pieces)
            } else {
                cells.append(segment)
            }
        }
        guard !cells.isEmpty else { return }

        let table = NSTextTable()
        let highest = cells.compactMap(\.info.tableColumn).max() ?? 0
        table.numberOfColumns = max(columns.count, highest + 1, 1)
        table.layoutAlgorithm = .automatic
        table.collapsesBorders = true
        table.hidesEmptyCells = false
        table.setContentWidth(100, type: .percentage)
        table.setWidth(1, type: .absolute, for: .border)
        table.setBorderColor(NSColor.separatorColor)
        table.setWidth(8, type: .absolute, for: .margin)

        var rowMap: [Int: Int] = [:]
        var nextRow = 0
        for cell in cells {
            let info = cell.info
            let rowKey = info.rowIdentity ?? info.cellIdentity ?? nextRow
            let row: Int
            if let known = rowMap[rowKey] {
                row = known
            } else {
                row = nextRow
                rowMap[rowKey] = row
                nextRow += 1
            }
            let column = info.tableColumn ?? 0
            let block = NSTextTableBlock(
                table: table,
                startingRow: row,
                rowSpan: 1,
                startingColumn: column,
                columnSpan: 1
            )
            block.setWidth(5, type: .absolute, for: .padding)
            block.setWidth(1, type: .absolute, for: .border)
            block.setBorderColor(NSColor.separatorColor)
            block.verticalAlignment = .top
            if info.tableHeader {
                block.backgroundColor = MarkdownPreviewRenderer.tint(0.07)
            }
            let style = NSMutableParagraphStyle()
            style.lineBreakMode = .byWordWrapping
            style.hyphenationFactor = 0
            style.paragraphSpacing = 1
            style.paragraphSpacingBefore = 0
            style.textBlocks = [block]
            if column >= 0, column < columns.count {
                switch columns[column].alignment {
                case .center: style.alignment = .center
                case .right: style.alignment = .right
                default: style.alignment = .left
                }
            }
            let text = styledText(cell.pieces, info: info)
            let font = makeFont(size: bodyPointSize, mono: false, bold: info.tableHeader, italic: false)
            finish(text, style: style, font: font)
            result.append(text)
        }
        atStart = false
    }

    private func styledText(_ pieces: [MarkdownPiece], info: MarkdownBlockInfo) -> NSMutableAttributedString {
        let text = NSMutableAttributedString()
        for piece in pieces {
            let shown = visible(piece.text, inline: piece.inline, inCode: info.isCode)
            if shown.isEmpty { continue }
            text.append(NSAttributedString(
                string: shown,
                attributes: runAttributes(info: info, inline: piece.inline, link: piece.link)
            ))
        }
        return text
    }

    /// A CommonMark hard break stays one paragraph. U+2028 is a line
    /// separator, so paragraph spacing is not inserted. A soft break is a space.
    private func visible(_ text: String, inline: InlinePresentationIntent, inCode: Bool) -> String {
        if inCode { return text }
        if inline.contains(.lineBreak) {
            return text.replacingOccurrences(of: "\n", with: "\u{2028}")
        }
        if inline.contains(.softBreak) { return " " }
        return text
    }

    private func runAttributes(
        info: MarkdownBlockInfo,
        inline: InlinePresentationIntent,
        link: URL?
    ) -> [NSAttributedString.Key: Any] {
        let mono = inline.contains(.code) || info.isCode
        let bold = inline.contains(.stronglyEmphasized) || info.headerLevel != nil || info.tableHeader
        let size = info.isCode ? bodyPointSize : pointSize(info)
        var attrs: [NSAttributedString.Key: Any] = [
            .font: makeFont(size: size, mono: mono, bold: bold, italic: inline.contains(.emphasized)),
            .foregroundColor: NSColor.labelColor
        ]
        if inline.contains(.code) && !info.isCode {
            attrs[.backgroundColor] = MarkdownPreviewRenderer.tint(0.08)
        }
        if inline.contains(.strikethrough) {
            attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            attrs[.strikethroughColor] = NSColor.secondaryLabelColor
        }
        if let link {
            attrs[.link] = link
            attrs[.foregroundColor] = NSColor.linkColor
            attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        return attrs
    }

    private func applySpacing(_ style: NSMutableParagraphStyle, info: MarkdownBlockInfo) {
        style.lineSpacing = 1
        if let level = info.headerLevel {
            if atStart {
                style.paragraphSpacingBefore = 0
            } else {
                style.paragraphSpacingBefore = level <= 2 ? 16 : 12
            }
            style.paragraphSpacing = 4
            return
        }
        if info.listDepth > 0 {
            style.paragraphSpacingBefore = 1
            style.paragraphSpacing = 2
            return
        }
        style.paragraphSpacingBefore = previousWasList ? 8 : 0
        style.paragraphSpacing = 8
    }

    private func applyListLayout(
        _ style: NSMutableParagraphStyle,
        info: MarkdownBlockInfo,
        markerFont: NSFont,
        text: NSMutableAttributedString
    ) {
        guard info.listDepth > 0, let ordinal = info.listOrdinal, !info.isCode else { return }
        let left = CGFloat(info.listDepth - 1) * 20 + 2
        let label = info.listOrdered ? "\(ordinal)." : "•"
        let hang = ceil((label as NSString).size(withAttributes: [.font: markerFont]).width) + 8
        let first: Bool
        if let id = info.listItemIdentity {
            first = startedListItems.insert(id).inserted
        } else {
            first = true
        }
        style.headIndent = left + hang
        style.firstLineHeadIndent = first ? left : left + hang
        style.tabStops = [
            NSTextTab(textAlignment: .left, location: left + hang, options: [:])
        ]
        style.defaultTabInterval = hang
        if first {
            text.insert(NSAttributedString(string: label + "\t", attributes: [
                .font: markerFont,
                .foregroundColor: NSColor.labelColor
            ]), at: 0)
        }
    }

    private func ruleParagraph() -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.minimumLineHeight = 12
        style.maximumLineHeight = 12
        style.paragraphSpacingBefore = atStart ? 4 : 10
        style.paragraphSpacing = 10
        let rule = MarkdownRuleBlock()
        rule.setContentWidth(100, type: .percentage)
        style.textBlocks = [rule]
        return NSAttributedString(string: " \n", attributes: [
            .font: NSFont.systemFont(ofSize: bodyPointSize),
            .foregroundColor: NSColor.clear,
            .paragraphStyle: style
        ])
    }

    private func finish(_ text: NSMutableAttributedString, style: NSParagraphStyle, font: NSFont) {
        if !text.string.hasSuffix("\n") {
            text.append(NSAttributedString(string: "\n", attributes: [
                .font: font,
                .foregroundColor: NSColor.labelColor
            ]))
        }
        guard text.length > 0 else { return }
        text.addAttribute(
            .paragraphStyle,
            value: style,
            range: NSRange(location: 0, length: text.length)
        )
    }

    private func pointSize(_ info: MarkdownBlockInfo) -> CGFloat {
        guard let level = info.headerLevel else { return bodyPointSize }
        switch level {
        case 1: return bodyPointSize + 11
        case 2: return bodyPointSize + 7
        case 3: return bodyPointSize + 4
        case 4: return bodyPointSize + 2
        case 5: return bodyPointSize + 1
        default: return bodyPointSize
        }
    }

    private func makeFont(size: CGFloat, mono: Bool, bold: Bool, italic: Bool) -> NSFont {
        let font: NSFont
        if mono {
            font = NSFont.monospacedSystemFont(ofSize: size, weight: bold ? .semibold : .regular)
        } else {
            font = NSFont.systemFont(ofSize: size, weight: bold ? .bold : .regular)
        }
        guard italic else { return font }
        return NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
    }
}

/// Keeps the preview text view as wide as the pane so lines wrap.
private final class MarkdownPreviewScrollView: NSScrollView {
    private var fitting = false

    override func layout() {
        super.layout()
        guard !fitting, let textView = documentView as? NSTextView else { return }
        let width = contentSize.width
        guard width > 1, abs(textView.frame.width - width) > 0.5 else { return }
        fitting = true
        defer { fitting = false }
        var frame = textView.frame
        frame.size.width = width
        textView.frame = frame
    }
}

/// Selectable, non-editable formatted Markdown.
struct MarkdownPreviewView: NSViewRepresentable {
    var markdown: String
    var bodyPointSize: CGFloat
    var onLink: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onLink: onLink)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = MarkdownPreviewScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = true
        scroll.backgroundColor = .textBackgroundColor

        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.importsGraphics = false
        textView.allowsUndo = false
        textView.usesFindBar = false
        textView.usesInspectorBar = false
        textView.usesRuler = false
        textView.usesFontPanel = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.enabledTextCheckingTypes = 0
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.textColor = .labelColor
        textView.textContainerInset = NSSize(width: 16, height: 12)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 4
        textView.textContainer?.containerSize = NSSize(
            width: 400,
            height: CGFloat.greatestFiniteMagnitude
        )
        scroll.documentView = textView
        context.coordinator.textView = textView
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.onLink = onLink
        guard let textView = scroll.documentView as? NSTextView else { return }
        let size = max(9, bodyPointSize)
        if context.coordinator.renderedMarkdown == markdown,
           abs(context.coordinator.renderedSize - size) < 0.1 {
            return
        }
        let rendered = MarkdownPreviewRenderer.render(markdown: markdown, bodyPointSize: size)
        let origin = scroll.contentView.bounds.origin
        textView.textStorage?.setAttributedString(rendered)
        context.coordinator.renderedMarkdown = markdown
        context.coordinator.renderedSize = size
        scroll.contentView.scroll(to: origin)
        scroll.reflectScrolledClipView(scroll.contentView)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var onLink: (URL) -> Void
        var renderedMarkdown: String?
        var renderedSize: CGFloat = 0
        weak var textView: NSTextView?

        init(onLink: @escaping (URL) -> Void) {
            self.onLink = onLink
        }

        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            let url: URL?
            if let found = link as? URL {
                url = found
            } else if let text = link as? String {
                url = URL(string: text)
            } else {
                url = nil
            }
            if let url {
                onLink(url)
            }
            return true
        }
    }
}
