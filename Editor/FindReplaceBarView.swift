//
//  FindReplaceBarView.swift
//  EditForth
//
//  Custom find / replace bar with Match Case and Whole Word checkboxes
//  (same options as Search in Folders). Installed as NSScrollView.findBarView.
//

import AppKit

final class FindReplaceBarView: NSView, NSTextFieldDelegate {
    weak var targetTextView: NSTextView?

    private let findField = NSTextField(string: "")
    private let replaceField = NSTextField(string: "")
    private let findLabel = NSTextField(labelWithString: "Find:")
    private let replaceLabel = NSTextField(labelWithString: "Replace:")
    private let matchCaseBox = NSButton(checkboxWithTitle: "Match Case", target: nil, action: nil)
    private let wholeWordBox = NSButton(checkboxWithTitle: "Whole Word", target: nil, action: nil)
    private let prevButton = NSButton(title: "Previous", target: nil, action: nil)
    private let nextButton = NSButton(title: "Next", target: nil, action: nil)
    private let replaceButton = NSButton(title: "Replace", target: nil, action: nil)
    private let replaceFindButton = NSButton(title: "Replace & Find", target: nil, action: nil)
    private let replaceAllButton = NSButton(title: "All", target: nil, action: nil)
    private let doneButton = NSButton(title: "Done", target: nil, action: nil)
    /// Readout between Find and Match Case: "3 of 12", "0 of 0", or "2 replaced".
    private let countField = NSTextField(string: "")

    private var showsReplace = false
    /// Replace row is only laid out when the target text view is editable.
    private var replaceRowVisible = false
    private let rowH: CGFloat = 28
    private let pad: CGFloat = 8
    private let gap: CGFloat = 8
    /// Fixed width so "999 of 999" / "999 replaced" fits without jitter.
    private let countFieldW: CGFloat = 88

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: preferredHeight)
    }

    var preferredHeight: CGFloat {
        replaceRowVisible ? (rowH * 2 + pad) : (rowH + pad)
    }

    var matchCase: Bool {
        get { matchCaseBox.state == .on }
        set { matchCaseBox.state = newValue ? .on : .off }
    }

    var wholeWord: Bool {
        get { wholeWordBox.state == .on }
        set { wholeWordBox.state = newValue ? .on : .off }
    }

    var findString: String {
        get { findField.stringValue }
        set { findField.stringValue = newValue }
    }

    var replaceString: String {
        get { replaceField.stringValue }
        set { replaceField.stringValue = newValue }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        configureField(findField)
        configureField(replaceField)
        findField.placeholderString = "Find"
        replaceField.placeholderString = "Replace"
        findField.delegate = self
        replaceField.delegate = self

        for lab in [findLabel, replaceLabel] {
            lab.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
            lab.textColor = .secondaryLabelColor
        }

        countField.isEditable = false
        countField.isSelectable = false
        countField.isBordered = true
        countField.bezelStyle = .roundedBezel
        countField.isBezeled = true
        countField.drawsBackground = true
        countField.backgroundColor = .controlBackgroundColor
        countField.font = NSFont.monospacedDigitSystemFont(
            ofSize: NSFont.smallSystemFontSize,
            weight: .regular
        )
        countField.textColor = .secondaryLabelColor
        countField.alignment = .center
        countField.stringValue = ""
        countField.placeholderString = "—"
        countField.toolTip = "Current match and total count"

        matchCaseBox.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        wholeWordBox.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        matchCaseBox.state = SearchHistory.caseSensitiveDefault ? .on : .off
        wholeWordBox.state = SearchHistory.wholeWordDefault ? .on : .off
        matchCaseBox.target = self
        matchCaseBox.action = #selector(optionsChanged(_:))
        wholeWordBox.target = self
        wholeWordBox.action = #selector(optionsChanged(_:))

        styleButton(prevButton)
        styleButton(nextButton)
        styleButton(replaceButton)
        styleButton(replaceFindButton)
        styleButton(replaceAllButton)
        styleButton(doneButton)

        prevButton.target = self
        prevButton.action = #selector(findPrevious(_:))
        nextButton.target = self
        nextButton.action = #selector(findNext(_:))
        replaceButton.target = self
        replaceButton.action = #selector(replaceSelection(_:))
        replaceFindButton.target = self
        replaceFindButton.action = #selector(replaceAndFind(_:))
        replaceAllButton.target = self
        replaceAllButton.action = #selector(replaceAll(_:))
        doneButton.target = self
        doneButton.action = #selector(done(_:))

        for v in [
            findLabel, findField, countField, matchCaseBox, wholeWordBox,
            prevButton, nextButton, doneButton,
            replaceLabel, replaceField, replaceButton, replaceFindButton, replaceAllButton
        ] {
            addSubview(v)
        }

        replaceLabel.isHidden = true
        replaceField.isHidden = true
        replaceButton.isHidden = true
        replaceFindButton.isHidden = true
        replaceAllButton.isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func configureField(_ field: NSTextField) {
        field.isEditable = true
        field.isBordered = true
        field.bezelStyle = .roundedBezel
        field.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        field.focusRingType = .default
    }

    private func styleButton(_ button: NSButton) {
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
    }

    override func layout() {
        super.layout()
        let w = bounds.width
        let h = bounds.height
        guard w > 40 else { return }

        findLabel.sizeToFit()
        replaceLabel.sizeToFit()
        matchCaseBox.sizeToFit()
        wholeWordBox.sizeToFit()
        prevButton.sizeToFit()
        nextButton.sizeToFit()
        doneButton.sizeToFit()
        replaceButton.sizeToFit()
        replaceFindButton.sizeToFit()
        replaceAllButton.sizeToFit()

        let topY = replaceRowVisible ? (h - pad / 2 - rowH) : ((h - rowH) / 2)
        layoutFindRow(y: topY, width: w)

        if replaceRowVisible {
            let bottomY = pad / 2
            layoutReplaceRow(y: bottomY, width: w)
        }
    }

    private func layoutFindRow(y: CGFloat, width w: CGFloat) {
        var x = pad
        let labW = findLabel.frame.width
        findLabel.frame = NSRect(
            x: x,
            y: y + (rowH - findLabel.fittingSize.height) / 2,
            width: labW,
            height: findLabel.fittingSize.height
        )
        x += labW + 4

        // Pack trailing controls right-to-left so the find field gets the rest.
        // Order: Done, Next, Previous, Whole Word, Match Case, then count field.
        var right = w - pad
        let controls: [NSView] = [doneButton, nextButton, prevButton, wholeWordBox, matchCaseBox]
        var frames: [(NSView, NSRect)] = []
        for (i, view) in controls.enumerated() {
            let vw = view.fittingSize.width
            let vh = min(view.fittingSize.height, rowH)
            right -= vw
            frames.append((view, NSRect(x: right, y: y + (rowH - vh) / 2, width: vw, height: vh)))
            if i < controls.count - 1 {
                right -= gap
            }
        }
        // Count field sits between Find and Match Case.
        right -= gap + countFieldW
        countField.frame = NSRect(
            x: right,
            y: y + (rowH - 22) / 2,
            width: countFieldW,
            height: 22
        )
        let fieldW = max(80, right - gap - x)
        findField.frame = NSRect(x: x, y: y + (rowH - 22) / 2, width: fieldW, height: 22)
        for (view, frame) in frames {
            view.frame = frame
        }
    }

    private func layoutReplaceRow(y: CGFloat, width w: CGFloat) {
        var x = pad
        let labW = max(findLabel.frame.width, replaceLabel.fittingSize.width)
        replaceLabel.frame = NSRect(
            x: x,
            y: y + (rowH - replaceLabel.fittingSize.height) / 2,
            width: labW,
            height: replaceLabel.fittingSize.height
        )
        x += labW + 4

        var right = w - pad
        let controls: [NSView] = [replaceAllButton, replaceFindButton, replaceButton]
        var frames: [(NSView, NSRect)] = []
        for (i, view) in controls.enumerated() {
            let vw = view.fittingSize.width
            let vh = min(view.fittingSize.height, rowH)
            right -= vw
            frames.append((view, NSRect(x: right, y: y + (rowH - vh) / 2, width: vw, height: vh)))
            if i < controls.count - 1 {
                right -= gap
            }
        }
        let fieldW = max(80, right - gap - x)
        replaceField.frame = NSRect(x: x, y: y + (rowH - 22) / 2, width: fieldW, height: 22)
        for (view, frame) in frames {
            view.frame = frame
        }
    }

    // MARK: - Show / hide

    func show(replace: Bool, in scroll: NSScrollView, focus: Bool = true) {
        showsReplace = replace
        replaceRowVisible = replace && (targetTextView?.isEditable == true)
        replaceLabel.isHidden = !replaceRowVisible
        replaceField.isHidden = !replaceRowVisible
        replaceButton.isHidden = !replaceRowVisible
        replaceFindButton.isHidden = !replaceRowVisible
        replaceAllButton.isHidden = !replaceRowVisible

        // Seed find string from the find pasteboard when empty.
        if findField.stringValue.isEmpty,
           let clip = NSPasteboard(name: .find).string(forType: .string),
           !clip.isEmpty {
            findField.stringValue = clip
        }

        // NSScrollView sizes the find bar from our frame height. Toggle
        // visibility when the height changes so the content insets update.
        let newHeight = preferredHeight
        let heightChanged = abs(frame.height - newHeight) > 0.5
        frame.size = NSSize(width: max(scroll.bounds.width, 200), height: newHeight)
        needsLayout = true
        invalidateIntrinsicContentSize()
        scroll.findBarView = self
        if heightChanged && scroll.isFindBarVisible {
            scroll.isFindBarVisible = false
        }
        scroll.isFindBarVisible = true
        layoutSubtreeIfNeeded()

        if focus {
            window?.makeFirstResponder(findField)
            findField.selectText(nil)
        }
        updateMatchCount(selecting: nil)
    }

    func hide(from scroll: NSScrollView?) {
        persistOptions()
        scroll?.isFindBarVisible = false
        if let tv = targetTextView {
            tv.window?.makeFirstResponder(tv)
        }
    }

    var isShowingReplace: Bool { showsReplace }

    // MARK: - Actions

    @objc private func optionsChanged(_ sender: Any?) {
        persistOptions()
        updateMatchCount(selecting: nil)
    }

    private func persistOptions() {
        SearchHistory.caseSensitiveDefault = matchCase
        SearchHistory.wholeWordDefault = wholeWord
    }

    private func syncFindPasteboard() {
        let text = findField.stringValue
        guard !text.isEmpty else { return }
        let pb = NSPasteboard(name: .find)
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    @objc func findNext(_ sender: Any?) {
        performFind(forward: true)
    }

    @objc func findPrevious(_ sender: Any?) {
        performFind(forward: false)
    }

    @objc func replaceSelection(_ sender: Any?) {
        guard let tv = targetTextView, tv.isEditable else { return }
        let needle = findField.stringValue
        guard !needle.isEmpty else { return }
        syncFindPasteboard()
        let sel = tv.selectedRange()
        let ns = tv.string as NSString
        guard sel.length > 0,
              ns.substring(with: sel).compare(
                needle,
                options: TextMatch.compareOptions(matchCase: matchCase)
              ) == .orderedSame,
              !wholeWord || TextMatch.isWholeWordMatch(in: ns, range: sel)
        else {
            // Selection is not the current match — find next first.
            performFind(forward: true)
            return
        }
        if tv.shouldChangeText(in: sel, replacementString: replaceField.stringValue) {
            tv.replaceCharacters(in: sel, with: replaceField.stringValue)
            tv.didChangeText()
        }
        updateMatchCount(selecting: nil)
    }

    @objc func replaceAndFind(_ sender: Any?) {
        replaceSelection(sender)
        performFind(forward: true)
    }

    @objc func replaceAll(_ sender: Any?) {
        guard let tv = targetTextView, tv.isEditable else { return }
        let needle = findField.stringValue
        guard !needle.isEmpty else { return }
        syncFindPasteboard()
        persistOptions()
        let count = TextMatch.replaceAll(
            in: tv,
            needle: needle,
            replacement: replaceField.stringValue,
            matchCase: matchCase,
            wholeWord: wholeWord
        )
        if count == 0 {
            countField.stringValue = "0 of 0"
            NSSound.beep()
        } else {
            countField.stringValue = count == 1 ? "1 replaced" : "\(count) replaced"
        }
    }

    @objc func done(_ sender: Any?) {
        hide(from: ownerScrollView)
    }

    /// Scroll view that owns this bar as `findBarView` (may not be a superview).
    private var ownerScrollView: NSScrollView? {
        var v: NSView? = self
        while let cur = v {
            if let scroll = cur as? NSScrollView { return scroll }
            v = cur.superview
        }
        return targetTextView?.enclosingScrollView
    }

    private func performFind(forward: Bool) {
        guard let tv = targetTextView else { return }
        let needle = findField.stringValue
        guard !needle.isEmpty else {
            countField.stringValue = ""
            return
        }
        syncFindPasteboard()
        persistOptions()

        let ns = tv.string as NSString
        let sel = tv.selectedRange()
        let found: NSRange?
        if forward {
            let from = sel.length > 0 ? NSMaxRange(sel) : sel.location
            found = TextMatch.findNext(
                in: ns, needle: needle, matchCase: matchCase, wholeWord: wholeWord,
                from: from, wrap: true
            )
        } else {
            let from = sel.location
            found = TextMatch.findPrevious(
                in: ns, needle: needle, matchCase: matchCase, wholeWord: wholeWord,
                from: from, wrap: true
            )
        }

        if let found {
            tv.setSelectedRange(found)
            tv.scrollRangeToVisible(found)
            updateMatchCount(selecting: found)
            // Prefer keeping focus in the find field for rapid Next presses.
            if window?.firstResponder !== findField && window?.firstResponder !== replaceField {
                window?.makeFirstResponder(tv)
            }
        } else {
            countField.stringValue = "0 of 0"
            NSSound.beep()
        }
    }

    /// Refresh the count field. Pass `selecting` after Next/Previous so the
    /// index matches the range just selected; otherwise use the text view selection.
    private func updateMatchCount(selecting selected: NSRange?) {
        let needle = findField.stringValue
        guard !needle.isEmpty, let tv = targetTextView else {
            countField.stringValue = ""
            return
        }
        let ns = tv.string as NSString
        let matches = TextMatch.allMatchRanges(
            in: ns,
            needle: needle,
            matchCase: matchCase,
            wholeWord: wholeWord
        )
        let total = matches.count
        if total == 0 {
            countField.stringValue = "0 of 0"
            return
        }
        let range = selected ?? tv.selectedRange()
        if let index = TextMatch.matchIndex(of: range, in: matches) {
            countField.stringValue = "\(index) of \(total)"
        } else {
            // Needle has hits, but the caret/selection is not on one yet.
            countField.stringValue = "– of \(total)"
        }
    }

    /// Use Selection for Find — copy the current selection into the find field.
    func setSearchStringFromSelection() {
        guard let tv = targetTextView else { return }
        let sel = tv.selectedRange()
        guard sel.length > 0 else { return }
        let text = (tv.string as NSString).substring(with: sel)
        findField.stringValue = text
        syncFindPasteboard()
        updateMatchCount(selecting: sel)
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField, field === findField else { return }
        updateMatchCount(selecting: nil)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            if control === replaceField {
                replaceAndFind(nil)
            } else {
                performFind(forward: true)
            }
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            done(nil)
            return true
        }
        return false
    }
}

// MARK: - Scroll-view lookup

extension NSScrollView {
    var findReplaceBar: FindReplaceBarView? {
        findBarView as? FindReplaceBarView
    }

    func ensureFindReplaceBar(for textView: NSTextView) -> FindReplaceBarView {
        if let existing = findReplaceBar {
            existing.targetTextView = textView
            return existing
        }
        let bar = FindReplaceBarView(frame: NSRect(x: 0, y: 0, width: bounds.width, height: 36))
        bar.targetTextView = textView
        findBarView = bar
        findBarPosition = .aboveContent
        return bar
    }
}
