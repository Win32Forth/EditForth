//
//  SixtyFourEditApp.swift
//  64Edit
//
//  Created by Tom Zimmer on 9/29/26.
//

import SwiftUI

@main
struct SixtyFourEditApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var workspace = WorkspaceModel()
    @StateObject private var forth = ForthConnectionManager()
    @AppStorage("showForthChrome") private var showForthChrome = true
    @AppStorage("showLineNumbers") private var showLineNumbers = true

    init() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            FileMenuFixup.install()
        }
    }

    var body: some Scene {
        // Single workspace window (not DocumentGroup / multi-window).
        Window("64Edit", id: "workspace") {
            ContentView()
                .environmentObject(workspace)
                .environmentObject(forth)
                .frame(minWidth: 640, minHeight: 420)
                .onAppear {
                    appDelegate.attach(workspace: workspace)
                    forth.start()
                }
        }
        .defaultSize(width: 960, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New File") {
                    workspace.newFile()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Open…") {
                    workspace.openPanel()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    _ = workspace.saveSelected()
                }
                .keyboardShortcut("s", modifiers: .command)

                Button("Save As…") {
                    _ = workspace.saveSelectedAs()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Button("Close Tab") {
                    // Last tab → empty placeholder (New File / Open…), not auto-Untitled.
                    workspace.closeSelected()
                }
                .keyboardShortcut("w", modifiers: .command)
            }
            // TextEdit-style find/replace bar on the focused editor / console NSTextView.
            // (SwiftUI Edit→Find alone often misses embedded AppKit text views.)
            CommandGroup(after: .pasteboard) {
                Divider()
                Button("Find…") {
                    FindSupport.perform(.showFindInterface)
                }
                .keyboardShortcut("f", modifiers: .command)
                Button("Find and Replace…") {
                    FindSupport.perform(.showReplaceInterface)
                }
                .keyboardShortcut("f", modifiers: [.command, .option])
                Button("Find Next") {
                    FindSupport.perform(.nextMatch)
                }
                .keyboardShortcut("g", modifiers: .command)
                Button("Find Previous") {
                    FindSupport.perform(.previousMatch)
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
                Button("Use Selection for Find") {
                    FindSupport.perform(.setSearchString)
                }
                // No ⌘E — that stays free for future VIEW-under-caret; use the menu.
                Divider()
                Button("Replace") {
                    FindSupport.perform(.replace)
                }
                Button("Replace and Find Next") {
                    FindSupport.perform(.replaceAndFind)
                }
                Button("Replace All") {
                    FindSupport.perform(.replaceAll)
                }
            }
            // Merge into the system View menu (CommandMenu("View") creates a second one).
            CommandGroup(after: .toolbar) {
                Button(workspace.selectedTab?.isViewMode == true ? "Allow Editing" : "Browse Mode") {
                    workspace.toggleBrowseMode()
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])
                .disabled(workspace.selectedTab == nil)

                Divider()

                Toggle("Show Forth Console", isOn: $showForthChrome)
                Toggle("Show Line Numbers", isOn: $showLineNumbers)
            }
            CommandMenu("Format") {
                Button("Bigger") {
                    bumpFont(1)
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Smaller") {
                    bumpFont(-1)
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("Reset Size (13)") {
                    UserDefaults.standard.set(13.0, forKey: "editorFontSize")
                }
            }
            // ⌘\ freed from Wrap Lines — toggle BREAK on the word under the caret.
            CommandMenu("Debug") {
                Button("Toggle Breakpoint") {
                    NotificationCenter.default.post(
                        name: .sixtyFourEditToggleBreakpoint,
                        object: nil
                    )
                }
                .keyboardShortcut("\\", modifiers: [.command])
            }
        }
    }

    private func bumpFont(_ delta: Double) {
        let key = "editorFontSize"
        let current = UserDefaults.standard.object(forKey: key) as? Double ?? 13
        let next = min(32, max(9, current + delta))
        UserDefaults.standard.set(next, forKey: key)
    }
}
