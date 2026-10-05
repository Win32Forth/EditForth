//
//  ForthDockSlot.swift
//  64Edit (EditForth)
//
//  Empty slot under Ping; reports Cocoa screen bounds for window-docking 64Forth.
//

import AppKit
import SwiftUI

/// Placeholder region whose screen rect is the Forth console dock target.
struct ForthDockSlot: NSViewRepresentable {
    var onScreenFrameChange: (CGRect) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScreenFrameChange: onScreenFrameChange)
    }

    func makeNSView(context: Context) -> DockSlotView {
        let view = DockSlotView()
        view.coordinator = context.coordinator
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ nsView: DockSlotView, context: Context) {
        context.coordinator.onScreenFrameChange = onScreenFrameChange
        context.coordinator.attach(to: nsView)
        context.coordinator.reportIfNeeded()
    }

    final class Coordinator {
        var onScreenFrameChange: (CGRect) -> Void
        private weak var view: DockSlotView?
        private var windowObs: [NSObjectProtocol] = []
        private var lastReported: CGRect = .null

        init(onScreenFrameChange: @escaping (CGRect) -> Void) {
            self.onScreenFrameChange = onScreenFrameChange
        }

        deinit {
            for o in windowObs {
                NotificationCenter.default.removeObserver(o)
            }
        }

        func attach(to view: DockSlotView) {
            self.view = view
            view.postsFrameChangedNotifications = true
            for o in windowObs {
                NotificationCenter.default.removeObserver(o)
            }
            windowObs.removeAll()
            windowObs.append(
                NotificationCenter.default.addObserver(
                    forName: NSView.frameDidChangeNotification,
                    object: view,
                    queue: .main
                ) { [weak self] _ in
                    self?.reportIfNeeded()
                }
            )
            if let window = view.window {
                observe(window: window)
            }
            // If window is nil, DockSlotView.viewDidMoveToWindow will re-attach.
        }

        private func observe(window: NSWindow) {
            let names: [Notification.Name] = [
                NSWindow.didMoveNotification,
                NSWindow.didResizeNotification,
            ]
            for name in names {
                windowObs.append(
                    NotificationCenter.default.addObserver(
                        forName: name,
                        object: window,
                        queue: .main
                    ) { [weak self] _ in
                        self?.reportIfNeeded()
                    }
                )
            }
        }

        func reportIfNeeded() {
            guard let view, let window = view.window else { return }
            let rect = window.convertToScreen(view.convert(view.bounds, to: nil))
            guard rect.width >= 40, rect.height >= 40 else { return }
            if rect.integral == lastReported.integral { return }
            lastReported = rect
            onScreenFrameChange(rect)
        }
    }
}

final class DockSlotView: NSView {
    weak var coordinator: ForthDockSlot.Coordinator?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        coordinator?.attach(to: self)
        coordinator?.reportIfNeeded()
    }

    override func layout() {
        super.layout()
        coordinator?.reportIfNeeded()
    }
}
