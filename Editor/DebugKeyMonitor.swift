//
//  DebugKeyMonitor.swift
//  64Edit
//
//  Window-level DEBUG key routing so F5–F8 work even when the Forth command
//  field previously stole first responder. Letter keys map only while the
//  selected tab is in browse (view) mode, so edit-mode typing stays normal.
//

import AppKit

extension Notification.Name {
    /// Ask the active editor NSTextView to take first responder.
    static let sixtyFourEditFocusEditor = Notification.Name("com.Win32Forth.64Edit.focusEditor")
    /// Debug → Toggle Breakpoint / ⌘\: toggle BREAK on the Forth token under the caret.
    static let sixtyFourEditToggleBreakpoint = Notification.Name("com.Win32Forth.64Edit.toggleBreakpoint")
}

enum EditorFocus {
    /// Post a request; `EditorTextView` makes its NSTextView first responder.
    static func request() {
        NotificationCenter.default.post(name: .sixtyFourEditFocusEditor, object: nil)
    }

    /// True when the key window's first responder is the source editor
    /// (`EditorNSTextView`), not the console transcript.
    static func editorIsKeyFirstResponder() -> Bool {
        guard let window = NSApp.keyWindow,
              let fr = window.firstResponder as? NSView
        else { return false }
        var view: NSView? = fr
        while let v = view {
            if v is EditorNSTextView { return true }
            view = v.superview
        }
        return false
    }
}

/// Owns one local key-down monitor; call `install` / `remove` from ContentView.
final class DebugKeyMonitor {
    private weak var forth: ForthConnectionManager?
    private weak var workspace: WorkspaceModel?
    private var monitor: Any?

    func attach(forth: ForthConnectionManager, workspace: WorkspaceModel) {
        self.forth = forth
        self.workspace = workspace
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event) ?? event
        }
    }

    func remove() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    deinit { remove() }

    private func handle(_ event: NSEvent) -> NSEvent? {
        // Leave modal alerts alone if any are up.
        if NSApp.modalWindow != nil { return event }

        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // F9 / ⌘\ — toggle BREAK under the editor caret (works idle or armed).
        // When the editor is first responder, EditorTextView handles these keys.
        if !EditorFocus.editorIsKeyFirstResponder() {
            if !mods.contains(.command), event.keyCode == 101 { // F9
                NotificationCenter.default.post(name: .sixtyFourEditToggleBreakpoint, object: nil)
                return nil
            }
            if mods.contains(.command), !mods.contains(.shift),
               (event.charactersIgnoringModifiers ?? "") == "\\" {
                NotificationCenter.default.post(name: .sixtyFourEditToggleBreakpoint, object: nil)
                return nil
            }
        }

        guard let forth, forth.isDebugSessionArmed else { return event }

        // EditorTextView also installs a local key monitor. All local monitors
        // see the same event, so handling here while the editor is focused
        // double-sends resume/step; the second sock reply is "debugger not armed"
        // and sticks in the console status as a red error. Defer to the editor.
        if EditorFocus.editorIsKeyFirstResponder() {
            return event
        }

        // ⌘⇧Y = continue (Forth console).
        if mods.contains(.command), mods.contains(.shift),
           (event.charactersIgnoringModifiers?.lowercased() ?? "") == "y" {
            forth.resumeDebug()
            return nil
        }

        // F5–F8 always while armed (focus on toolbar / disabled console).
        switch event.keyCode {
        case 96: // F5
            forth.resumeDebug()
            return nil
        case 97: // F6
            forth.stepOver()
            return nil
        case 98: // F7
            forth.stepInto()
            return nil
        case 100: // F8
            forth.stepOut()
            return nil
        default:
            break
        }

        // Letter / Esc / Return: only when the selected tab is browse mode.
        let viewMode = workspace?.selectedTab?.isViewMode ?? false
        if !viewMode {
            // Edit mode with focus elsewhere: F-keys above still work.
            return event
        }
        if mods.contains(.command) || mods.contains(.option) || mods.contains(.control) {
            return event
        }

        if event.keyCode == 53 { // Esc
            forth.stopDebug()
            return nil
        }
        if event.keyCode == 36 { // Return
            forth.stepOver()
            return nil
        }

        let ch = event.charactersIgnoringModifiers?.lowercased() ?? ""
        switch ch {
        case " ", "o":
            forth.stepOver()
            return nil
        case "i":
            forth.stepInto()
            return nil
        case "g":
            forth.resumeDebug()
            return nil
        case "q":
            forth.stopDebug()
            return nil
        case "h":
            return nil
        default:
            return event
        }
    }
}
