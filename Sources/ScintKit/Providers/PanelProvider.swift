import AppKit
import Observation
import OrderedCollections
import SwiftUI


extension Notification.Name { static let scintPanelEscape = Notification.Name("scintPanelEscape") }

struct PanelDismissal: OptionSet, Hashable {
    let rawValue: Int
    static let escape = Self(rawValue: 1 << 0)
    static let outsideClick = Self(rawValue: 1 << 1)
}

private struct Float<Content: View>: View {
    let content: Content

    var body: some View {
        content
            .glassEffect(.regular, in: Style.Shape.panel)
            .background(Style.Background.overlay.opacity(Style.Opacity.faint))
            .overlay(Style.Shape.panel.stroke(.black.opacity(Style.Opacity.muted), lineWidth: 1))
            .clipShape(Style.Shape.panel)
    }
}

final class FloatingPanel: NSPanel {
    var onEscape: (() -> Void)?

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isFloatingPanel = true
        collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .fullScreenAuxiliary]
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        becomesKeyOnlyIfNeeded = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { onEscape?() }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onEscape?() }
        else { super.keyDown(with: event) }
    }
}

@MainActor final class PanelEscapeEvent { var handled = false }

@MainActor final class PanelProvider: NSObject, NSWindowDelegate {
    private let panel: FloatingPanel
    private let hosting: NSHostingController<AnyView>
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var dismissal: PanelDismissal = .escape
    private var positioned = false
    private let pinned: () -> Bool
    private let onVisibilityChange: ((Bool) -> Void)?

    var window: NSWindow { panel }
    var isVisible: Bool { panel.isVisible }

    init( params: PanelParams, view: AnyView, pinned: @escaping () -> Bool = { false }, onVisibilityChange: ((Bool) -> Void)? = nil) {
        hosting = NSHostingController(rootView: view)
        panel = FloatingPanel(contentRect: NSRect(origin: .zero, size: params.sizing.size))
        self.pinned = pinned
        self.onVisibilityChange = onVisibilityChange
        panel.contentView = hosting.view
        super.init()
        panel.delegate = self
        configure(params)
        panel.onEscape = { [weak self] in
            guard let self else { return }
            let event = PanelEscapeEvent()
            NotificationCenter.default.post(name: .scintPanelEscape , object: event)
            if !event.handled && self.dismissal.contains(.escape) { self.hide() }
        }
    }

    func windowWillClose(_ notification: Notification) {
        removeEventMonitors()
        onVisibilityChange?(false)
    }

    func toggle() {
        panel.isVisible ? hide() : show()
    }

    func show() {
        if !positioned {
            panel.center()
            positioned = true
        }
        installEventMonitors()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        onVisibilityChange?(true)
    }

    func hide() {
        removeEventMonitors()
        if let parent = panel.parent { parent.removeChildWindow(panel) }
        panel.orderOut(nil)
        onVisibilityChange?(false)
    }

    func configure(_ params: PanelParams) {
        dismissal = params.dismissal
        panel.isMovable = params.movable
        panel.isMovableByWindowBackground = params.movable

        if params.resizable { panel.styleMask.insert(.resizable) }
        else { panel.styleMask.remove(.resizable) }

        panel.minSize = params.sizing.min ?? NSSize(width: 1, height: 1)
        panel.maxSize = params.sizing.max ?? NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )

        if !params.resizable || !positioned { resize(to: params.sizing.size) }
        if panel.isVisible { installEventMonitors() }
    }

    func resize(to size: CGSize) {
        var frame = panel.frame
        frame.size = size
        panel.setFrame(frame, display: true, animate: false)
    }

    private func installEventMonitors() {
        removeEventMonitors()
        guard dismissal.contains(.outsideClick) else { return }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else { return event }
            self.dismissOutside()
            return event
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.dismissOutside()
        }
    }

    private func dismissOutside() {
        guard panel.isVisible, !pinned() else { return }
        guard !panel.frame.contains(NSEvent.mouseLocation) else { return }
        hide()
    }

    private func removeEventMonitors() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }

        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
    }
}

@MainActor final class PanelCoordinator {
    let controller: PanelProvider

    init(controller: PanelProvider) { self.controller = controller }

    static func load(
        params: PanelParams,
        view: AnyView,
        pinned: @escaping () -> Bool = { false },
        onVisibilityChange: ((Bool) -> Void)? = nil
    ) -> PanelCoordinator {
        Self(
            controller: PanelProvider(
                params: params,
                view: view,
                pinned: pinned,
                onVisibilityChange: onVisibilityChange
            )
        )
    }

    var isVisible: Bool { controller.isVisible }

    func update(_ params: PanelParams) { controller.configure(params) }
    func show() { controller.show() }
    func hide() { controller.hide() }
    func toggle() { controller.toggle() }
}

@Observable @MainActor final class PanelManager {
    private(set) var coordinators: OrderedDictionary<AnyHashable, PanelCoordinator> = [:]

    let actions: ActionsPanel = .init()
    let search: SearchPanel = .init()

    func panel(for key: PanelKey) -> any Panel {
        switch key {
            case .actions: actions
            case .search: search
        }
    }

    func coordinator(for key: PanelKey) -> PanelCoordinator? { coordinators[key] }

    func presented(_ key: PanelKey) -> Bool { coordinators[key]?.isVisible ?? false }

    func toggle(_ key: PanelKey, _ params: PanelParams, _ view: some View, onVisibilityChange: ((Bool) -> Void)? = nil) {
        coordinator(for: key, parameters: params, view: view, onVisibilityChange: onVisibilityChange).toggle()
    }

    func show(_ key: PanelKey, _ params: PanelParams, _ view: some View, onVisibilityChange: ((Bool) -> Void)? = nil) {
        coordinator(for: key, parameters: params, view: view, onVisibilityChange: onVisibilityChange).show()
    }

    func hide(_ key: PanelKey) { coordinators[key]?.hide() }

    private func coordinator(for key: PanelKey, parameters: PanelParams, view: some View, onVisibilityChange: ((Bool) -> Void)?) -> PanelCoordinator {
        if let existing = coordinators[key] {
            existing.update(parameters)
            return existing
        }

        let host = panel(for: key)
        let coordinator = PanelCoordinator.load(
            params: parameters,
            view: AnyView(Float(content: view)),
            pinned: { [weak host] in host?.state.pinned ?? false },
            onVisibilityChange: onVisibilityChange
        )
        coordinators[key] = coordinator
        return coordinator
    }
}
