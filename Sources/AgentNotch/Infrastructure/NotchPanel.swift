import AppKit
import SwiftUI

/// Borderless, non-activating panel that floats above the menu bar at the notch.
final class NotchPanel: NSPanel {
    init(frame: NSRect) {
        super.init(contentRect: frame,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .mainMenu + 3
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        isMovable = false
        acceptsMouseMovedEvents = true
        ignoresMouseEvents = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Keep the panel flush with the top of the screen (AppKit would push it below the menu bar).
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

/// Owns the panel, positions it, and toggles mouse passthrough based on the visible shape.
@MainActor
final class NotchPanelController {
    private let store: SessionStore
    private let viewModel: NotchViewModel
    private var panel: NotchPanel?
    private var pollTimer: Timer?
    private var collapseTask: Task<Void, Never>?
    private var screenObserver: NSObjectProtocol?

    init(store: SessionStore, viewModel: NotchViewModel) {
        self.store = store
        self.viewModel = viewModel
    }

    func show() {
        reposition()
        panel?.orderFrontRegardless()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reposition() }
        }
        let timer = Timer(timeInterval: 1.0 / 15.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.pollMouse() }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    func reposition() {
        let geometry = NotchGeometry.current()
        viewModel.geometry = geometry
        let size = NotchLayout.panelSize
        let frame = NSRect(x: geometry.screenFrame.midX - size.width / 2,
                           y: geometry.screenFrame.maxY - size.height,
                           width: size.width, height: size.height)
        if let panel {
            panel.setFrame(frame, display: true)
        } else {
            let panel = NotchPanel(frame: frame)
            let hosting = NSHostingView(rootView: NotchRootView(store: store, viewModel: viewModel))
            hosting.sizingOptions = []
            hosting.frame = NSRect(origin: .zero, size: size)
            hosting.autoresizingMask = [.width, .height]
            panel.contentView = hosting
            self.panel = panel
        }
    }

    /// Mouse tracking by polling: works while the panel ignores mouse events, needs no permissions.
    private func pollMouse() {
        guard let panel else { return }
        let g = viewModel.geometry
        let shape = viewModel.shapeSize
        // Visible shape, top-centered, with a little slack (and extra above the screen edge).
        let rect = NSRect(x: g.screenFrame.midX + viewModel.shapeOffsetX - shape.width / 2 - 6,
                          y: g.screenFrame.maxY - shape.height - 6,
                          width: shape.width + 12, height: shape.height + 26)
        let inside = rect.contains(NSEvent.mouseLocation)
        if panel.ignoresMouseEvents == inside { panel.ignoresMouseEvents = !inside }

        if inside {
            collapseTask?.cancel()
            collapseTask = nil
            if !viewModel.hovering { viewModel.hovering = true }
        } else if viewModel.hovering, collapseTask == nil {
            collapseTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(280))
                guard !Task.isCancelled, let self else { return }
                self.viewModel.hovering = false
                self.viewModel.hoveredSession = nil
                self.collapseTask = nil
            }
        }
    }
}
