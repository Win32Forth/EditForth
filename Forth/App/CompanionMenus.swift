//
//  CompanionMenus.swift
//  64Forth (EditForth)
//
//  NSMenu for headless --companion: same File / Tools / Help actions as
//  SixtyFourForthApp.commands. Visible when the companion app is frontmost
//  (Dock icon; activation policy .regular).
//

#if os(macOS)
import AppKit
import UniformTypeIdentifiers

enum CompanionMenus {

    private static var observers: [NSObjectProtocol] = []

    /// Install mainMenu and wire notification-style actions for companion mode.
    static func install() {
        tearDownObservers()
        NSApp.mainMenu = buildMainMenu()
        installActionObservers()
    }

    private static func tearDownObservers() {
        for o in observers {
            NotificationCenter.default.removeObserver(o)
        }
        observers.removeAll()
    }

    private static func installActionObservers() {
        let nc = NotificationCenter.default
        observers.append(nc.addObserver(forName: .clearConsole, object: nil, queue: .main) { _ in
            ForthEditorServer.shared.broadcast(.consoleOutput(text: "\u{0c}"))
            ForthEditorServer.shared.broadcastOkPrompt()
        })
        observers.append(nc.addObserver(forName: .showBootMessages, object: nil, queue: .main) { _ in
            let text = KernelBridge.shared.bootTranscript
            var block = "=== Cold bootstrap messages ===\n"
            if text.isEmpty {
                block += "No cold-bootstrap messages.\n"
            } else {
                block += text
                if !text.hasSuffix("\n") { block += "\n" }
            }
            ForthEditorServer.shared.broadcast(.consoleOutput(text: block))
            ForthEditorServer.shared.broadcastOkPrompt()
        })
        observers.append(nc.addObserver(forName: .toolsFload, object: nil, queue: .main) { _ in
            presentFloadPanel()
        })
        observers.append(nc.addObserver(forName: .toolsChdir, object: nil, queue: .main) { _ in
            presentChdirPanel()
        })
        observers.append(nc.addObserver(forName: .toolsEdit, object: nil, queue: .main) { _ in
            presentEditPanel()
        })
    }

    private static func buildMainMenu() -> NSMenu {
        let main = NSMenu()

        // App menu (64Forth)
        let appName = "64Forth"
        let appMenu = NSMenu()
        let appItem = NSMenuItem(title: appName, action: nil, keyEquivalent: "")
        appItem.submenu = appMenu
        appMenu.addItem(withTitle: "About \(appName)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Hide \(appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        main.addItem(appItem)

        // File (same actions as SixtyFourForthApp CommandGroup replacing .newItem)
        let fileMenu = NSMenu(title: "File")
        let fileItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
        fileItem.submenu = fileMenu
        add(fileMenu, title: "FLOAD…", key: "l", mods: [.command, .shift]) {
            NotificationCenter.default.post(name: .toolsFload, object: nil)
        }
        add(fileMenu, title: "CHDIR…", key: "d", mods: [.command, .shift]) {
            NotificationCenter.default.post(name: .toolsChdir, object: nil)
        }
        add(fileMenu, title: "EDIT…", key: "", mods: []) {
            NotificationCenter.default.post(name: .toolsEdit, object: nil)
        }
        fileMenu.addItem(NSMenuItem.separator())
        add(fileMenu, title: "Update User Data in 64Forth Folder", key: "", mods: []) {
            FileHost.shared.installUserTree(replaceExisting: false)
        }
        add(fileMenu, title: "Restore Shipped Files to 64Forth Folder", key: "", mods: []) {
            FileHost.shared.confirmRestoreShippedFiles()
        }
        add(fileMenu, title: "Show Library Folder", key: "", mods: []) {
            FileHost.shared.revealInFinder(FileHost.shared.libraryURL)
        }
        add(fileMenu, title: "Show AutoLoad Folder", key: "", mods: []) {
            FileHost.shared.revealInFinder(FileHost.shared.autoLoadURL)
        }
        add(fileMenu, title: "Show Docs Folder", key: "", mods: []) {
            FileHost.shared.revealInFinder(FileHost.shared.docsURL)
        }
        add(fileMenu, title: "Show Config Folder", key: "", mods: []) {
            FileHost.shared.revealInFinder(FileHost.shared.configURL)
        }
        main.addItem(fileItem)

        // Edit (standard)
        let editMenu = NSMenu(title: "Edit")
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editItem.submenu = editMenu
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        main.addItem(editItem)

        // Tools
        let toolsMenu = NSMenu(title: "Tools")
        let toolsItem = NSMenuItem(title: "Tools", action: nil, keyEquivalent: "")
        toolsItem.submenu = toolsMenu
        add(toolsMenu, title: "CLS", key: "k", mods: [.command]) {
            NotificationCenter.default.post(name: .clearConsole, object: nil)
        }
        add(toolsMenu, title: "VIEW Word Under Cursor", key: "e", mods: [.command]) {
            KernelBridge.shared.requestViewWordUnderCursor()
        }
        add(toolsMenu, title: "Toggle Breakpoint", key: "\\", mods: [.command]) {
            KernelBridge.shared.requestToggleBreakpointUnderCursor()
        }
        main.addItem(toolsItem)

        // Window
        let windowMenu = NSMenu(title: "Window")
        let windowItem = NSMenuItem(title: "Window", action: nil, keyEquivalent: "")
        windowItem.submenu = windowMenu
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        NSApp.windowsMenu = windowMenu
        main.addItem(windowItem)

        // Help
        let helpMenu = NSMenu(title: "Help")
        let helpItem = NSMenuItem(title: "Help", action: nil, keyEquivalent: "")
        helpItem.submenu = helpMenu
        add(helpMenu, title: "Show Boot Messages", key: "", mods: []) {
            NotificationCenter.default.post(name: .showBootMessages, object: nil)
        }
        NSApp.helpMenu = helpMenu
        main.addItem(helpItem)

        return main
    }

    private static func add(
        _ menu: NSMenu,
        title: String,
        key: String,
        mods: NSEvent.ModifierFlags,
        handler: @escaping () -> Void
    ) {
        let item = NSMenuItem(
            title: title,
            action: #selector(CompanionMenuTarget.run(_:)),
            keyEquivalent: key
        )
        item.keyEquivalentModifierMask = mods
        item.target = CompanionMenuTarget.shared
        item.representedObject = CompanionMenuAction(handler)
        menu.addItem(item)
    }

    private static func presentFloadPanel() {
        let host = FileHost.shared
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            UTType(filenameExtension: "fth") ?? .plainText,
            UTType(filenameExtension: "fs") ?? .plainText,
            UTType(filenameExtension: "4th") ?? .plainText,
            .plainText
        ]
        panel.directoryURL = host.userTreeURL
            ?? URL(fileURLWithPath: host.logicalCurrentDirectory, isDirectory: true)
        panel.prompt = "Load"
        panel.message = "FLOAD / INCLUDE a Forth source file"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let cmd = "INCLUDE \(url.path)"
        ForthEditorServer.shared.broadcast(.consoleOutput(text: "\(cmd)\n"))
        DispatchQueue.main.async {
            let st = KernelBridge.shared.evaluate(cmd)
            KernelBridge.shared.forceFlushEmitSync()
            if st == 0 {
                ForthEditorServer.shared.broadcastOkPrompt()
            } else {
                ForthEditorServer.shared.broadcast(.consoleOutput(text: "status=\(st)\n"))
                ForthEditorServer.shared.broadcastOkPrompt()
            }
        }
    }

    private static func presentChdirPanel() {
        let host = FileHost.shared
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: host.logicalCurrentDirectory, isDirectory: true)
        panel.prompt = "Choose"
        panel.message = "Set Forth working directory (CHDIR)"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        host.logicalCurrentDirectory = url.path
        _ = FileManager.default.changeCurrentDirectoryPath(url.path)
        ForthEditorServer.shared.broadcast(.consoleOutput(text: "Working folder: \(url.path)\n"))
        ForthEditorServer.shared.broadcastOkPrompt()
    }

    private static func presentEditPanel() {
        NSApp.activate(ignoringOtherApps: true)
        FileHost.shared.presentEditPicker()
        ForthEditorServer.shared.broadcastOkPrompt()
    }
}

/// Holds a closure for NSMenuItem.representedObject.
private final class CompanionMenuAction: NSObject {
    let handler: () -> Void
    init(_ handler: @escaping () -> Void) { self.handler = handler }
}

private final class CompanionMenuTarget: NSObject {
    static let shared = CompanionMenuTarget()

    @objc func run(_ sender: NSMenuItem) {
        (sender.representedObject as? CompanionMenuAction)?.handler()
    }
}
#endif
