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
    /// View → Wrap at Column: `off` | `window` | `column`.
    @AppStorage("editorWrapMode") private var wrapMode = "off"
    /// Character columns when mode is `column` (preset or Other…).
    @AppStorage("editorWrapColumn") private var wrapColumn = 100
    @State private var gotoObserver: NSObjectProtocol?
    @State private var dragStartHeight: CGFloat?
    @State private var debugKeys = DebugKeyMonitor()
    /// After cold start settles, allow auto-reveal (do not pop chrome for Engine down alone).
    @State private var chromeAutoRevealReady = false
    /// Fraction of editor width for the left pane while split (0.2…0.8).
    @AppStorage("editorSplitFraction") private var splitFraction = 0.5
    @State private var liveSplitFraction: CGFloat?
    @State private var splitDragStartFraction: CGFloat?

    private static let consoleMinHeight: CGFloat = 88
    private static let editorMinHeight: CGFloat = 120
    private static let splitMinPaneWidth: CGFloat = 160

    var body: some View {
        GeometryReader { geo in
            let maxConsole = max(
                Self.consoleMinHeight,
                geo.size.height - Self.editorMinHeight - ConsoleSplitter.height
            )
            let clampedConsole = min(max(consoleHeight, Self.consoleMinHeight), maxConsole)

            VStack(spacing: 0) {
                tabBar

                // Keep every editor pane mounted so tab switches do not rebuild
                // NSTextView (text was already in memory; tear-down caused the lag).
                if workspace.tabs.isEmpty && workspace.searchTabs.isEmpty && workspace.diffTabs.isEmpty {
                    emptyEditorPlaceholder
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let search = workspace.selectedSearchTab {
                    // Search results use the full editor area (split stays latent).
                    SearchResultsView(session: search, workspace: workspace)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let diff = workspace.selectedDiffTab {
                    // Diff hunks use the full editor area (split stays latent).
                    BufferDiskDiffView(session: diff, workspace: workspace)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if workspace.isEditorSplit, workspace.splitSecondaryTab != nil {
                    splitEditorArea
                } else {
                    fileEditorStack(visibleTabID: workspace.selectedTabID, paneID: "main")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Keep the docked console mounted while chrome is "hidden" so Show
                // Forth Console can restore the same NSView / transcript.
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

                // Debug chrome belongs with the Forth console (below the splitter),
                // replacing the idle status strip — not above the editor/console split.
                if forth.isDebugSessionArmed, showForthChrome {
                    DebugToolbar(forth: forth)
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
                // Console became visible — connect or launch companion (next turn so
                // ping’s @Published writes are not inside this view update).
                DispatchQueue.main.async { forth.ping() }
            }
        }
        .background(WindowChrome(url: workspace.selectedTab?.fileURL))
        .onAppear {
            consoleHeight = storedConsoleHeight
            installGotoObserver()
            // Visible console (docked or undocked) → auto-start companion.
            // Hidden (Show Forth Console off) → connect only if already listening;
            // do not launch; user can Start Forth after showing the console.
            // Defer off the appear/update pass — ping/start publish ObservableObject
            // state and would warn if run inline.
            let chrome = showForthChrome
            DispatchQueue.main.async {
                if chrome {
                    forth.ping()
                } else {
                    forth.start()
                }
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
        .onChange(of: forth.consoleFillSeq) { _, _ in
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
            // Bare EDIT from the companion — Open panel lives in EditForth (cwd after CHDIR).
            NSApp.activate(ignoringOtherApps: true)
            workspace.openPanel(startDirectory: forth.panelStartURL)
        }
        .onChange(of: forth.floadOpenRequestSeq) { _, _ in
            // Bare FLOAD/INCLUDE — Load panel in EditForth at companion cwd, then INCLUDED.
            NSApp.activate(ignoringOtherApps: true)
            ForthMenuSupport.presentFload(forth: forth)
        }
        .onChange(of: forth.chdirOpenRequestSeq) { _, _ in
            // Bare CHDIR — folder panel in EditForth, then CHDIR "path".
            NSApp.activate(ignoringOtherApps: true)
            ForthMenuSupport.presentChdir(forth: forth)
        }
        .onChange(of: workspace.selectedTabID) { _, _ in
            workspace.ensureSplitPanesDistinct()
        }
    }

    /// Persistently show Forth chrome when companion activity arrives while hidden.
    /// Require an active sock — ⌘-click with Forth down falls back to in-file find
    /// and must not pop the console (lastError / "Hyper: not connected" note).
    private func revealForthChromeIfNeeded() {
        guard chromeAutoRevealReady, !showForthChrome, forth.isConnected else { return }
        showForthChrome = true
    }

    // MARK: - Editor stacks / split

    /// Side-by-side file editors; tab bar still drives the left pane.
    private var splitEditorArea: some View {
        GeometryReader { geo in
            let fraction = liveSplitFraction ?? CGFloat(splitFraction)
            let clamped = min(max(fraction, 0.2), 0.8)
            let splitterW = EditorHSplitter.width
            let total = max(geo.size.width - splitterW, Self.splitMinPaneWidth * 2)
            let leftW = min(
                max(total * clamped, Self.splitMinPaneWidth),
                total - Self.splitMinPaneWidth
            )

            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    splitPaneHeader(title: workspace.selectedTab?.title ?? "Editor", isSecondary: false)
                    fileEditorStack(visibleTabID: workspace.selectedTabID, paneID: "left")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(width: leftW)

                EditorHSplitter(
                    onDrag: { translationX in
                        let base = splitDragStartFraction ?? CGFloat(splitFraction)
                        if splitDragStartFraction == nil {
                            splitDragStartFraction = CGFloat(splitFraction)
                        }
                        let delta = translationX / max(total, 1)
                        liveSplitFraction = min(max(base + delta, 0.2), 0.8)
                    },
                    onEnd: {
                        if let live = liveSplitFraction {
                            splitFraction = Double(live)
                        }
                        liveSplitFraction = nil
                        splitDragStartFraction = nil
                    }
                )

                VStack(spacing: 0) {
                    splitSecondaryHeader
                    // Mount only the right tab (left stack already keep-alives every tab).
                    if let tab = workspace.splitSecondaryTab {
                        TabEditorPane(
                            tab: tab,
                            fontSize: fontSize,
                            showLineNumbers: showLineNumbers,
                            wrapMode: wrapMode,
                            wrapColumn: wrapColumn,
                            isDebugArmed: forth.isDebugSessionArmed,
                            breakpointEntries: forth.breakpointEntries,
                            onDebugStepOver: { forth.stepOver() },
                            onDebugStepInto: { forth.stepInto() },
                            onDebugStepOut: { forth.stepOut() },
                            onDebugContinue: { forth.resumeDebug() },
                            onDebugStop: { forth.stopDebug() },
                            onPrepareRunLine: { kind in forth.prepareRunLine(kind) },
                            onCommandClickWord: { word in forth.viewWord(word) },
                            onToggleBreakpoint: { word in forth.toggleBreakpoint(word) },
                            onRunToOffset: { offset in forth.runTo(offset: offset) }
                        )
                        .id("right-\(tab.id)")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var splitSecondaryHeader: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(workspace.tabs) { tab in
                    Button(tab.title) {
                        workspace.setSplitSecondaryTab(id: tab.id)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(workspace.splitSecondaryTab?.title ?? "Right")
                        .fontWeight(.medium)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer(minLength: 0)

            Button {
                workspace.closeEditorSplit()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .help("Close Split")
        }
        .font(.system(size: 11))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1)
        }
    }

    private func splitPaneHeader(title: String, isSecondary: Bool) -> some View {
        HStack(spacing: 8) {
            Text(isSecondary ? "Right" : "Left")
                .foregroundStyle(.secondary)
            Text(title)
                .fontWeight(.medium)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .font(.system(size: 11))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1)
        }
    }

    /// File tabs stay mounted for keep-alive; `visibleTabID` picks which one is interactive.
    /// While split, the right pane’s tab is omitted here so it is not duplicated (hidden
    /// left copies were stealing VIEW-miss find / selection from the right pane).
    private func fileEditorStack(visibleTabID: UUID?, paneID: String) -> some View {
        let secondaryID = workspace.splitSecondaryTabID
        let tabs = workspace.tabs.filter { tab in
            secondaryID == nil || tab.id != secondaryID || tab.id == visibleTabID
        }
        return ZStack {
            ForEach(tabs) { tab in
                let selected = tab.id == visibleTabID
                TabEditorPane(
                    tab: tab,
                    fontSize: fontSize,
                    showLineNumbers: showLineNumbers,
                    wrapMode: wrapMode,
                    wrapColumn: wrapColumn,
                    isDebugArmed: forth.isDebugSessionArmed,
                    breakpointEntries: forth.breakpointEntries,
                    onDebugStepOver: { forth.stepOver() },
                    onDebugStepInto: { forth.stepInto() },
                    onDebugStepOut: { forth.stepOut() },
                    onDebugContinue: { forth.resumeDebug() },
                    onDebugStop: { forth.stopDebug() },
                    onPrepareRunLine: { kind in forth.prepareRunLine(kind) },
                    onCommandClickWord: { word in forth.viewWord(word) },
                    onToggleBreakpoint: { word in forth.toggleBreakpoint(word) },
                    onRunToOffset: { offset in forth.runTo(offset: offset) }
                )
                .opacity(selected ? 1 : 0)
                .allowsHitTesting(selected)
                .accessibilityHidden(!selected)
                // Distinct identity per pane so left/right can both host a tab.
                .id("\(paneID)-\(tab.id)")
            }
        }
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(workspace.tabStripItems, id: \.id) { item in
                    TabChip(
                        title: item.title,
                        isSelected: item.id == workspace.selectedTabID,
                        onSelect: { workspace.selectedTabID = item.id },
                        onClose: { workspace.closeTab(id: item.id) }
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
            HStack(spacing: 8) {
                Text(forth.isConnected ? "Engine connected" : "Engine down")
                if forth.isDebugSessionArmed {
                    Text("· debugging")
                        .foregroundStyle(.orange)
                }
                Button("INCLUDE") {
                    ForthMenuSupport.includeCurrentTab(workspace: workspace, forth: forth)
                }
                .disabled(!forth.isConnected || forth.isDebugSessionArmed || workspace.selectedTab == nil)
                .help("INCLUDE current tab (F4) — save if needed, ANEW <file>_MODULE, then INCLUDED")
                .controlSize(.small)
                Button("RUN") {
                    forth.prepareRunLine(ForthConnectionManager.runLineKindFromCurrentModifiers())
                }
                .disabled(!forth.isConnected || forth.isDebugSessionArmed)
                .help("RUN (F5) — LAST name on the console; Return to run. ⌘F5 / ⌘-click = DEBUG; ⌘⇧F5 / ⌘⇧-click = BPGO")
                .controlSize(.small)
                Button("EMIT") {
                    ForthMenuSupport.emitCurrentTab(workspace: workspace, forth: forth)
                }
                .disabled(!forth.isConnected || forth.isDebugSessionArmed || workspace.selectedTab == nil)
                .help("Emit Window App — INCLUDE then EMIT-AUTO (LAST). Default: WINDOW + Press a key to exit. See EMIT-NO-PAUSE / EMIT-NO-WINDOW / EMIT-NO-WRAPPER")
                .controlSize(.small)
                Button("Pause") {
                    forth.breakAsap()
                    EditorFocus.request()
                }
                .disabled(!forth.isConnected)
                .help("Break Now — pause at the next Forth instruction above DEBUGGER-END (⌃⌘Y)")
                .controlSize(.small)
                .keyboardShortcut("y", modifiers: [.control, .command])
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
                // Bottom edge of the Ping/status strip — darker/thicker than a hairline.
                Rectangle()
                    .fill(Color(nsColor: .labelColor).opacity(0.70))
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
    var wrapMode: String
    var wrapColumn: Int
    var isDebugArmed: Bool
    var breakpointEntries: [BreakpointEntry]
    var onDebugStepOver: () -> Void
    var onDebugStepInto: () -> Void
    var onDebugStepOut: () -> Void
    var onDebugContinue: () -> Void
    var onDebugStop: () -> Void
    var onPrepareRunLine: (ForthConnectionManager.RunLineKind) -> Void
    var onCommandClickWord: (String) -> Void
    var onToggleBreakpoint: (String) -> Void
    var onRunToOffset: (Int) -> Void

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
                wrapMode: wrapMode,
                wrapColumn: wrapColumn,
                breakpointEntries: breakpointEntries,
                onDebugStepOver: onDebugStepOver,
                onDebugStepInto: onDebugStepInto,
                onDebugStepOut: onDebugStepOut,
                onDebugContinue: onDebugContinue,
                onDebugStop: onDebugStop,
                onPrepareRunLine: onPrepareRunLine,
                onCommandClickWord: onCommandClickWord,
                onToggleBreakpoint: onToggleBreakpoint,
                onRunToOffset: onRunToOffset
            )
        }
    }
}

/// Popover button: click toggles BREAK under the editor caret (same as F9 / ⌘\)
/// and opens the list to enable/disable/delete / Arm.
private struct BreakpointsPanelButton: View {
    @ObservedObject var forth: ForthConnectionManager
    @State private var isPresented = false

    var body: some View {
        Button {
            // Same path as F9 / ⌘\ / Debug → Toggle Breakpoint.
            NotificationCenter.default.post(
                name: .sixtyFourEditToggleBreakpoint,
                object: nil
            )
            isPresented = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "breakpoint")
                Text(buttonTitle)
            }
        }
        .help("Toggle BREAK on the word under the editor caret (F9 / ⌘\\), then show the list")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            BreakpointsPanel(forth: forth)
                .frame(minWidth: 300, idealWidth: 340, minHeight: 240, idealHeight: 300, maxHeight: 480)
                .padding(12)
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
                Button("Toggle caret") {
                    NotificationCenter.default.post(
                        name: .sixtyFourEditToggleBreakpoint,
                        object: nil
                    )
                }
                .disabled(!forth.isConnected)
                .help("Toggle BREAK on the word under the editor caret (F9 / ⌘\\)")
                .controlSize(.small)
                Button("Arm") {
                    forth.armBreakGo()
                    EditorFocus.request()
                }
                .disabled(!forth.isDebugSessionArmed || !forth.isConnected)
                .help(
                    forth.isDebugSessionArmed
                        ? "Continue until an enabled BREAK hits"
                        : "While idle, use ⌘⇧F5 / BPGO LAST, or type BPGO <word>"
                )
                .controlSize(.small)
            }

            if forth.breakpointEntries.isEmpty {
                Text("None yet — click Breakpoints / F9 / ⌘\\ on a word in the editor.")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 11))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(forth.breakpointEntries, id: \.name) { entry in
                            BreakpointRow(forth: forth, entry: entry)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 88, maxHeight: 280)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("F9 / ⌘\\ / this button toggles BREAK under the editor caret.")
                Text(
                    forth.isDebugSessionArmed
                        ? "Arm continues until an enabled BREAK hits."
                        : "Idle: ⌘⇧F5 or BPGO <word> runs until a break."
                )
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 12, design: .monospaced))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
            Button("Pause") {
                forth.breakAsap()
                EditorFocus.request()
            }
            .help("Break Now — interrupt Continue/BPGO/Run-to at the next allowed token (⌃⌘Y)")
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

/// Vertical drag handle between left and right editor panes.
private struct EditorHSplitter: View {
    static let width: CGFloat = 8

    var onDrag: (CGFloat) -> Void
    var onEnd: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.55))
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(width: 2)
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .onHover { inside in
                    if inside {
                        NSCursor.resizeLeftRight.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 1, coordinateSpace: .global)
                        .onChanged { value in
                            onDrag(value.translation.width)
                        }
                        .onEnded { _ in
                            onEnd()
                        }
                )
        }
        .frame(width: Self.width)
        .frame(maxHeight: .infinity)
        .accessibilityLabel("Resize editor split")
        .accessibilityAddTraits(.isButton)
    }
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
                .fill(Color(nsColor: .separatorColor).opacity(0.60))
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
        let id = AppDelegate.workspaceWindowID
        // If another workspace window is already tagged, this scene is a Finder-open
        // duplicate — close it so only one EditForth window remains.
        let others = NSApp.windows.filter {
            $0.identifier == id && $0 !== window && ($0.isVisible || $0.isKeyWindow)
        }
        if !others.isEmpty {
            DispatchQueue.main.async {
                window.close()
            }
            return
        }
        window.identifier = id
        window.representedURL = url
        if let url {
            window.title = url.lastPathComponent
        } else if window.title.isEmpty {
            window.title = "EditForth"
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WorkspaceModel())
        .environmentObject(ForthConnectionManager())
}
