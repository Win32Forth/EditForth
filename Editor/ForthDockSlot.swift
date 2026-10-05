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
    /// Bumps from the connection manager to force a resend after Ping/connect.
    var forceSeq: UInt = 0
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
        context.coordinator.applyForceSeq(forceSeq)
        context.coordinator.reportIfNeeded()
    }

    final class Coordinator {
        var onScreenFrameChange: (CGRect) -> Void
        private weak var view: DockSlotView?
        private var windowObs: [NSObjectProtocol] = []
        private var lastReported: CGRect = .null
        private var lastForceSeq: UInt = 0
        private var observedWindow: NSWindow?

        init(onScreenFrameChange: @escaping (CGRect) -> Void) {
            self.onScreenFrameChange = onScreenFrameChange
        }

        deinit {
            for o in windowObs {
                NotificationCenter.default.removeObserver(o)
            }
        }

        func applyForceSeq(_ seq: UInt) {
            guard seq != lastForceSeq else { return }
            lastForceSeq = seq
            lastReported = .null
        }

        func attach(to view: DockSlotView) {
            self.view = view
            view.postsFrameChangedNotifications = true
            for o in windowObs {
                NotificationCenter.default.removeObserver(o)
            }
            windowObs.removeAll()
            observedWindow = nil
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
        }

        private func observe(window: NSWindow) {
            if observedWindow === window { return }
            observedWindow = window
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
            observe(window: window)
            // Layout may still be zero during the first SwiftUI pass — skip until real.
            guard view.bounds.width >= 40, view.bounds.height >= 40 else { return }
            let rect = window.convertToScreen(view.convert(view.bounds, to: nil))
            guard rect.width >= 40, rect.height >= 40 else { return }
            if !lastReported.isNull, framesMatch(rect, lastReported) { return }
            lastReported = rect
            onScreenFrameChange(rect)
        }

        private func framesMatch(_ a: CGRect, _ b: CGRect) -> Bool {
            abs(a.origin.x - b.origin.x) < 0.5
                && abs(a.origin.y - b.origin.y) < 0.5
                && abs(a.width - b.width) < 0.5
                && abs(a.height - b.height) < 0.5
        }
    }
}

final class DockSlotView: NSView {
    weak var coordinator: ForthDockSlot.Coordinator?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        // Slightly distinct fill so the empty slot is visible before Forth docks.
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
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
