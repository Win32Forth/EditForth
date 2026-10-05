//
//  ContentView.swift
//  64Edit
//
//  Created by Tom Zimmer on 9/29/26.
//

import SwiftUI
import AppKit

/// Single-window workspace: tab bar + editor + shared Forth console.
struct ContentView: View {
    @EnvironmentObject private var workspace: WorkspaceModel
    @EnvironmentObject private var forth: ForthConnectionManager
    @AppStorage("editorFontSize") private var fontSize = 13.0
    /// Persisted console height — written on drag end / clamp, not every drag tick.
    @AppStorage("consolePaneHeight") private var storedConsoleHeight = 160.0
    /// Live split height while dragging (avoids UserDefaults I/O flash per tick).
    @State private var consoleHeight = 160.0
    /// View → Show Forth Console (status, transcript, command line, debug toolbar).
    @AppStorage("showForthChrome") private var showForthChrome = true
    /// View → Show Line Numbers.
    @AppStorage("showLineNumbers") private var showLineNumbers = true
    @State private var gotoObserver: NSObjectProtocol?
    @State private var dragStartHeight: CGFloat?
    @State private var debugKeys = DebugKeyMonitor()
    /// After cold start settles, allow auto-reveal (do not pop chrome for Engine down alone).
    @State private var chromeAutoRevealReady = false

    private static let consoleMinHeight: CGFloat = 88
    private static let editorMinHeight: CGFloat = 120

    var body: some View {
        GeometryReader { geo in
            let maxConsole = max(
                Self.consoleMinHeight,
                geo.size.height - Self.editorMinHeight - ConsoleSplitter.height
            )
            let clampedConsole = min(max(consoleHeight, Self.consoleMinHeight), maxConsole)

            VStack(spacing: 0) {
                tabBar

                if let tab = workspace.selectedTab {
                    TabEditorPane(
                        tab: tab,
                        fontSize: fontSize,
                        showLineNumbers: showLineNumbers,
                        isDebugArmed: forth.isDebugSessionArmed,
                        breakpointEntries: forth.breakpointEntries,
                        onDebugStepOver: { forth.stepOver() },
                        onDebugStepInto: { forth.stepInto() },
                        onDebugStepOut: { forth.stepOut() },
                        onDebugContinue: { forth.resumeDebug() },
                        onDebugStop: { forth.stopDebug() },
                        onCommandClickWord: { word in forth.viewWord(word) },
                        onToggleBreakpoint: { word in forth.toggleBreakpoint(word) }
                    )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .id(tab.id)
                } else {
                    emptyEditorPlaceholder
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Keep the docked console mounted while chrome is "hidden" so Show
                // Forth Console can restore the same NSView / transcript.
                if forth.isDebugSessionArmed, showForthChrome {
                    DebugToolbar(forth: forth)
                }

                let consoleEmbedded = forth.preferDocked && !forth.consoleHidden

                if showForthChrome, consoleEmbedded {
                    ConsoleSplitter(
                        onDrag: { translationY in
                            let base = dragStartHeight ?? clampedConsole
                            if dragStartHeight == nil { dragStartHeight = clampedConsole }
                            let next = min(
                                max(base - translationY, Self.consoleMinHeight),
                                maxConsole
                            )
                            consoleHeight = next
                        },
                        onEnd: {
                            dragStartHeight = nil
                            storedConsoleHeight = consoleHeight
                        }
                    )
                }

                if showForthChrome, consoleEmbedded {
                    consolePane
                        .frame(height: clampedConsole)
                } else if showForthChrome {
                    // Undocked or hidden: status strip only — no empty dock well.
                    consolePane
                        .fixedSize(horizontal: false, vertical: true)
                } else if consoleEmbedded {
                    consolePane
                        .frame(height: 0)
                        .clipped()
                        .opacity(0)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .onChange(of: geo.size.height) { _, _ in
                guard showForthChrome else { return }
                if consoleHeight > maxConsole {
                    consoleHeight = maxConsole
                    storedConsoleHeight = maxConsole
                }
            }
            .onChange(of: showForthChrome) { _, show in
                guard show else { return }
                // Restore a usable height if storage/clamp left the pane collapsed.
                if consoleHeight < Self.consoleMinHeight {
                    consoleHeight = max(storedConsoleHeight, Self.consoleMinHeight)
                }
                // Console became visible — connect or launch companion.
                forth.ping()
            }
        }
        .background(WindowChrome(url: workspace.selectedTab?.fileURL))
        .onAppear {
            consoleHeight = storedConsoleHeight
            installGotoObserver()
            // Visible console (docked or undocked) → auto-start companion.
            // Hidden (Show Forth Console off) → connect only if already listening;
            // do not launch; user can Start Forth after showing the console.
            if showForthChrome {
                forth.ping()
            } else {
                forth.start()
            }
            debugKeys.attach(forth: forth, workspace: workspace)
            // File opens / pending-goto / initial untitled are owned by AppDelegate.attach
            // (runs from SixtyFourEditApp) so we do not create a stray Untitled tab first.
            // Delay auto-reveal so cold "Engine down" / connect-failed does not force chrome.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                chromeAutoRevealReady = true
            }
        }
        .onDisappear {
            if let gotoObserver {
                DistributedNotificationCenter.default().removeObserver(gotoObserver)
                self.gotoObserver = nil
            }
            debugKeys.remove()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
        ) { _ in
            workspace.handlePendingGoto()
        }
        .onChange(of: forth.debugLocation) { _, loc in
            guard let loc else { return }
            workspace.applyDebugLocation(
                path: loc.path,
                line: loc.line,
                name: loc.name,
                off: loc.off,
                len: loc.len
            )
            if forth.isDebugSessionArmed {
                DispatchQueue.main.async { EditorFocus.request() }
            }
        }
        .onChange(of: forth.isDebugSessionArmed) { _, armed in
            if armed {
                revealForthChromeIfNeeded()
                // Drop console-field focus; DEBUG pauses reject executeCommand anyway.
                DispatchQueue.main.async { EditorFocus.request() }
            } else {
                workspace.clearDebugHighlights()
            }
        }
        // Do not reveal on isConnected alone — that would undo Hide on every launch
        // when 64Forth is already running. Reveal on DEBUG, console traffic, or errors.
        .onChange(of: forth.consoleLines.count) { _, _ in
            revealForthChromeIfNeeded()
        }
        .onChange(of: forth.lastError) { _, err in
            if err != nil {
                revealForthChromeIfNeeded()
            }
        }
        .onChange(of: forth.viewMissSeq) { _, _ in
            let word = forth.viewMissWord
            guard !word.isEmpty else { return }
            DispatchQueue.main.async {
                FindSupport.searchSource(for: word)
            }
        }
        .onChange(of: forth.editOpenRequestSeq) { _, _ in
            // Bare EDIT from the companion — Open panel lives in EditForth.
            NSApp.activate(ignoringOtherApps: true)
            workspace.openPanel()
        }
    }

    /// Persistently show Forth chrome when companion activity arrives while hidden.
    /// Require an active sock — ⌘-click with Forth down falls back to in-file find
    /// and must not pop the console (lastError / "Hyper: not connected" note).
    private func revealForthChromeIfNeeded() {
        guard chromeAutoRevealReady, !showForthChrome, forth.isConnected else { return }
        showForthChrome = true
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(workspace.tabs) { tab in
                    TabChip(
                        title: tab.title,
                        isSelected: tab.id == workspace.selectedTabID,
                        onSelect: { workspace.selectedTabID = tab.id },
                        onClose: { workspace.closeTab(id: tab.id) }
                    )
                }
            }
        }
        .frame(height: 28)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1)
        }
    }

    private var emptyEditorPlaceholder: some View {
        VStack(spacing: 12) {
            Text("No file open")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Create a new file, open a Forth source, or use EDIT / VIEW from 64Forth.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                Button("New File") { workspace.newFile() }
                    .keyboardShortcut("n", modifiers: .command)
                Button("Open…") { workspace.openPanel() }
                    .keyboardShortcut("o", modifiers: .command)
            }
        }
        .padding(24)
    }

    // MARK: - Console

    /// Status strip + (when docked) companion console. Undocked/hidden: strip only.
    private var consolePane: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(forth.isConnected ? "Engine connected" : "Engine down")
                if forth.isDebugSessionArmed {
                    Text("· debugging")
                        .foregroundStyle(.orange)
                }
                Spacer()
                BreakpointsPanelButton(forth: forth)
                if forth.isConnected {
                    if forth.preferDocked {
                        Button("Undock") { forth.undockForth() }
                    } else if forth.consoleHidden {
                        Button("Unhide Forth") { forth.unhideForthConsole() }
                    } else {
                        Button("Dock") { forth.dockForth() }
                    }
                } else {
                    Button("Start Forth") { forth.ping() }
                }
            }
            .font(.system(size: 12, design: .monospaced))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            if let err = forth.lastError {
                Text(err)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
            }

            if forth.preferDocked, !forth.consoleHidden {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor).opacity(0.55))
                    .frame(height: 1)
                    .frame(maxWidth: .infinity)

                // Only one DockedConsoleView may drain emit — floating window owns it when undocked.
                DockedConsoleView(forth: forth)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: (forth.preferDocked && !forth.consoleHidden) ? .infinity : nil,
            alignment: .topLeading
        )
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func installGotoObserver() {
        guard gotoObserver == nil else { return }
        gotoObserver = DistributedNotificationCenter.default().addObserver(
            forName: PendingGoto.notificationName,
            object: nil,
            queue: .main
        ) { _ in
            workspace.handlePendingGoto()
        }
    }
}

// MARK: - Tab UI

private struct TabChip: View {
    var title: String
    var isSelected: Bool
    var onSelect: () -> Void
    var onClose: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onSelect) {
                Text(title)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close tab")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(isSelected ? Color(nsColor: .controlBackgroundColor) : Color.clear)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(isSelected ? Color.accentColor : Color.clear)
                .frame(height: 2)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}

/// Editor + view-mode banner for one tab (ObservedObject so text edits refresh dirty title).
private struct TabEditorPane: View {
    @ObservedObject var tab: EditorTab
    var fontSize: Double
    var showLineNumbers: Bool
    var isDebugArmed: Bool
    var breakpointEntries: [BreakpointEntry]
    var onDebugStepOver: () -> Void
    var onDebugStepInto: () -> Void
    var onDebugStepOut: () -> Void
    var onDebugContinue: () -> Void
    var onDebugStop: () -> Void
    var onCommandClickWord: (String) -> Void
    var onToggleBreakpoint: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if tab.isViewMode {
                HStack(spacing: 8) {
                    Text("View mode")
                        .fontWeight(.semibold)
                    Text(
                        isDebugArmed
                            ? "Read-only — F5–F8 / i o Space g q drive the stepper"
                            : "Read-only — typing asks to switch to Edit"
                    )
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Edit") {
                        tab.isViewMode = false
                    }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                }
                .font(.system(size: 11))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .background(Color.yellow.opacity(0.22))
            }

            EditorTextView(
                text: Binding(
                    get: { tab.text },
                    set: { newValue in
                        if tab.text != newValue {
                            tab.text = newValue
                            tab.isDirty = true
                        }
                    }
                ),
                fontSize: fontSize,
                gotoLine: $tab.gotoLine,
                highlightName: $tab.highlightName,
                highlightOff: $tab.highlightOff,
                highlightLen: $tab.highlightLen,
                highlightEpoch: tab.highlightEpoch,
                isViewMode: $tab.isViewMode,
                selection: Binding(
                    get: { tab.selection },
                    set: { tab.selection = $0 }
                ),
                topVisibleLine: Binding(
                    get: { tab.topVisibleLine },
                    set: { tab.topVisibleLine = $0 }
                ),
                isDebugArmed: isDebugArmed,
                showLineNumbers: showLineNumbers,
                breakpointEntries: breakpointEntries,
                onDebugStepOver: onDebugStepOver,
                onDebugStepInto: onDebugStepInto,
                onDebugStepOut: onDebugStepOut,
                onDebugContinue: onDebugContinue,
                onDebugStop: onDebugStop,
                onCommandClickWord: onCommandClickWord,
                onToggleBreakpoint: onToggleBreakpoint
            )
        }
    }
}

/// Popover button: BREAK list with enable/disable/delete + paused Arm.
private struct BreakpointsPanelButton: View {
    @ObservedObject var forth: ForthConnectionManager
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "breakpoint")
                Text(buttonTitle)
            }
        }
        .help("Breakpoints — enable, disable, delete; Arm while paused")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            BreakpointsPanel(forth: forth)
                .frame(minWidth: 280, idealWidth: 320, maxHeight: 360)
                .padding(10)
        }
    }

    private var buttonTitle: String {
        let n = forth.breakpointEntries.count
        return n == 0 ? "Breakpoints" : "Breakpoints (\(n))"
    }
}

/// Shared BREAK table UI for the console header and Debug toolbar.
private struct BreakpointsPanel: View {
    @ObservedObject var forth: ForthConnectionManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Breakpoints")
                    .font(.headline)
                Spacer()
                Button("Arm") {
                    forth.armBreakGo()
                    EditorFocus.request()
                }
                .disabled(!forth.isDebugSessionArmed || !forth.isConnected)
                .help(
                    forth.isDebugSessionArmed
                        ? "Continue until an enabled BREAK hits"
                        : "While idle, type BPGO <word> in the console"
                )
                .controlSize(.small)
            }

            if forth.breakpointEntries.isEmpty {
                Text("None — F9 / ⌘\\ toggles BREAK under the caret")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 11))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(forth.breakpointEntries, id: \.name) { entry in
                            BreakpointRow(forth: forth, entry: entry)
                        }
                    }
                }
            }

            if !forth.isDebugSessionArmed {
                Text("Arm needs a DEBUG pause. Idle: BPGO <word> runs until a break.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(.system(size: 12, design: .monospaced))
    }
}

private struct BreakpointRow: View {
    @ObservedObject var forth: ForthConnectionManager
    var entry: BreakpointEntry

    var body: some View {
        HStack(spacing: 8) {
            Toggle(
                "",
                isOn: Binding(
                    get: { entry.enabled },
                    set: { forth.setBreakpointEnabled(entry.name, enabled: $0) }
                )
            )
            .toggleStyle(.checkbox)
            .help(entry.enabled ? "Disable (keep slot)" : "Enable")
            Text(entry.name)
                .foregroundStyle(entry.enabled ? Color.primary : Color.secondary)
                .lineLimit(1)
            Spacer(minLength: 4)
            Button {
                forth.removeBreakpoint(entry.name)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.red)
            .help("Delete breakpoint")
            .controlSize(.small)
        }
        .padding(.vertical, 2)
    }
}

/// Shown while 64Forth ITC DEBUG / TDBG is armed; hidden otherwise.
///
/// F5–F8 / ⌘⇧Y are wired here so they still work when focus is in the console
/// field. Bare letters stay off the toolbar so they never steal edit-mode typing;
/// view-mode letter mapping lives in `EditorTextView` only while armed.
private struct DebugToolbar: View {
    @ObservedObject var forth: ForthConnectionManager

    private var barColor: Color {
        forth.isConnected
            ? Color.green.opacity(0.18)
            : Color.orange.opacity(0.18)
    }

    private var accent: Color {
        forth.isConnected ? .green : .orange
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "ladybug.fill")
                .foregroundStyle(accent)
            Text("Debug")
                .fontWeight(.semibold)
            BreakpointsPanelButton(forth: forth)
            Button("Arm") {
                forth.armBreakGo()
                EditorFocus.request()
            }
            .help("Continue until an enabled BREAK hits")
            Spacer(minLength: 8)
            Button("Step Over") { forth.stepOver() }
                .keyboardShortcut(Self.f6)
                .help("Step Over (F6)")
            Button("Step Into") { forth.stepInto() }
                .keyboardShortcut(Self.f7)
                .help("Step Into (F7)")
            Button("Step Out") { forth.stepOut() }
                .keyboardShortcut(Self.f8)
                .help("Step Out (F8)")
            Button("Continue") { forth.resumeDebug() }
                .keyboardShortcut(Self.f5)
                .help("Continue (F5 or ⌘⇧Y)")
            // Second Continue binding (Forth console uses ⌘⇧Y / g).
            Button("") { forth.resumeDebug() }
                .keyboardShortcut("y", modifiers: [.command, .shift])
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)
            Button("Stop") { forth.stopDebug() }
                .keyboardShortcut(.escape)
                .foregroundStyle(.red)
                .help("Stop (Esc)")
        }
        .font(.system(size: 11))
        .buttonStyle(.bordered)
        .controlSize(.small)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .background(barColor)
        .contentShape(Rectangle())
        .onTapGesture { EditorFocus.request() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Debug toolbar")
        .help("Breakpoints · Arm · F6 over · F7 into · F8 out · F5/⌘⇧Y continue · Esc stop")
    }

    private static let f5 = KeyEquivalent(Character(UnicodeScalar(NSF5FunctionKey)!))
    private static let f6 = KeyEquivalent(Character(UnicodeScalar(NSF6FunctionKey)!))
    private static let f7 = KeyEquivalent(Character(UnicodeScalar(NSF7FunctionKey)!))
    private static let f8 = KeyEquivalent(Character(UnicodeScalar(NSF8FunctionKey)!))
}

/// Drag handle between editor and console; drag up to grow the console.
private struct ConsoleSplitter: View {
    /// Hit target ~3× the old 6pt bar so it is easier to grab.
    static let height: CGFloat = 18

    var onDrag: (CGFloat) -> Void
    var onEnd: () -> Void

    var body: some View {
        ZStack {
            // Soft fill across the whole grab strip.
            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.28))
            // Bold center rule (~3× the old 1pt hairline).
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 3)
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .onHover { inside in
                    if inside {
                        NSCursor.resizeUpDown.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                .gesture(
                    // Global space: the splitter moves in the VStack as console
                    // height changes; local translation then oscillates (~splitter
                    // height) and the pane flashes between two sizes.
                    DragGesture(minimumDistance: 1, coordinateSpace: .global)
                        .onChanged { value in
                            onDrag(value.translation.height)
                        }
                        .onEnded { _ in
                            onEnd()
                        }
                )
        }
        .frame(height: Self.height)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Resize console")
        .accessibilityAddTraits(.isButton)
    }
}

/// Keep the window title / representedURL in sync with the selected tab.
private struct WindowChrome: NSViewRepresentable {
    var url: URL?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { apply(from: view) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { apply(from: nsView) }
    }

    private func apply(from view: NSView) {
        guard let window = view.window else { return }
        window.representedURL = url
        if let url {
            window.title = url.lastPathComponent
        } else if window.title.isEmpty {
            window.title = "64Edit"
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WorkspaceModel())
        .environmentObject(ForthConnectionManager())
}
