//
//  FindSupport.swift
//  64Edit
//
//  TextEdit-style find / replace bar for EditorNSTextView / ConsoleNSTextView.
//  SwiftUI's default Edit→Find often never reaches an embedded NSTextView,
//  so menu items call performTextFinderAction on the focused (or preferred) view.
//

import AppKit

enum FindSupport {
    /// Editor that initiated a ⌘-click VIEW (so view-miss find hits that pane, not the left stack).
    private static weak var pendingSearchEditor: EditorNSTextView?

    /// Call from `EditorNSTextView` before `onCommandClickWord` so a later VIEW miss
    /// searches this pane (split-aware).
    static func noteCommandClickEditor(_ tv: EditorNSTextView) {
        pendingSearchEditor = tv
    }

    /// Run a text-finder action on the focused source/console text view.
    static func perform(_ action: NSTextFinder.Action) {
        guard let tv = focusedTextView() ?? preferredTextView() else { return }
        if tv.window?.firstResponder !== tv {
            tv.window?.makeFirstResponder(tv)
        }
        let item = NSMenuItem()
        item.tag = action.rawValue
        tv.performTextFinderAction(item)
    }

    /// VIEW miss fallback: put `needle` on the find pasteboard, select the first
    /// hit in the source editor that was ⌘-clicked (or focused), and open the find bar.
    static func searchSource(for needle: String) {
        let text = needle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let noted = pendingSearchEditor
        pendingSearchEditor = nil

        let tv: EditorNSTextView? =
            (noted?.window != nil ? noted : nil)
            ?? (focusedTextView() as? EditorNSTextView)
            ?? visibleEditorTextView()

        guard let tv, let window = tv.window ?? NSApp.keyWindow else { return }
        window.makeFirstResponder(tv)

        let pb = NSPasteboard(name: .find)
        pb.clearContents()
        pb.setString(text, forType: .string)

        let ns = tv.string as NSString
        let found = ns.range(of: text, options: [], range: NSRange(location: 0, length: ns.length))
        if found.location != NSNotFound {
            tv.setSelectedRange(found)
            tv.scrollRangeToVisible(found)
        }

        let show = NSMenuItem()
        show.tag = NSTextFinder.Action.showFindInterface.rawValue
        tv.performTextFinderAction(show)
    }

    /// First on-screen, hittable editor (skips opacity-0 keep-alive panes in a ZStack).
    private static func visibleEditorTextView() -> EditorNSTextView? {
        guard let root = NSApp.keyWindow?.contentView else { return nil }
        return firstVisibleEditor(in: root)
    }

    private static func firstVisibleEditor(in root: NSView) -> EditorNSTextView? {
        if let tv = root as? EditorNSTextView, isUsableEditor(tv) {
            return tv
        }
        for child in root.subviews {
            if let found = firstVisibleEditor(in: child) {
                return found
            }
        }
        return nil
    }

    private static func isUsableEditor(_ tv: EditorNSTextView) -> Bool {
        guard !tv.isHiddenOrHasHiddenAncestor, tv.window != nil else { return false }
        // SwiftUI opacity(0) keep-alive panes: skip non-hittable / fully transparent.
        if tv.visibleRect.isEmpty { return false }
        var view: NSView? = tv
        while let v = view {
            if v.alphaValue < 0.05 { return false }
            view = v.superview
        }
        return true
    }

    /// NSTextView that currently has key focus (editor or console).
    static func focusedTextView() -> NSTextView? {
        guard let window = NSApp.keyWindow,
              let fr = window.firstResponder as? NSView
        else { return nil }
        var view: NSView? = fr
        while let v = view {
            if let tv = v as? EditorNSTextView { return tv }
            if let tv = v as? ConsoleNSTextView { return tv }
            view = v.superview
        }
        return nil
    }

    /// Prefer a text view whose find bar is open; else the source editor; else console.
    static func preferredTextView() -> NSTextView? {
        guard let window = NSApp.keyWindow,
              let root = window.contentView
        else { return nil }
        if let fr = window.firstResponder as? NSView,
           let owner = textViewOwningFindBar(containing: fr) {
            return owner
        }
        let editor = firstVisibleEditor(in: root)
            ?? firstSubview(ofType: EditorNSTextView.self, in: root)
        let console = firstSubview(ofType: ConsoleNSTextView.self, in: root)
        if let editor, findBarVisible(for: editor) { return editor }
        if let console, findBarVisible(for: console) { return console }
        return editor ?? console
    }

    private static func findBarVisible(for tv: NSTextView) -> Bool {
        tv.enclosingScrollView?.isFindBarVisible == true
    }

    /// Walk from the find-bar field up to its enclosing scroll view's document.
    private static func textViewOwningFindBar(containing view: NSView) -> NSTextView? {
        var current: NSView? = view
        while let cur = current {
            if let scroll = cur as? NSScrollView,
               scroll.isFindBarVisible,
               let tv = scroll.documentView as? NSTextView {
                return tv
            }
            current = cur.superview
        }
        return nil
    }

    private static func firstSubview<T: NSView>(ofType type: T.Type, in root: NSView) -> T? {
        if let match = root as? T { return match }
        for child in root.subviews {
            if let found = firstSubview(ofType: type, in: child) {
                return found
            }
        }
        return nil
    }
}
