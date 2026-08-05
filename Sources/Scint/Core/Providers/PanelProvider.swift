import AppKit
import Observation
import OrderedCollections
import SwiftUI



extension Notification.Name { static let scintPanelEscape = Notification.Name("scintPanelEscape") }

private struct Float<Content: View>: View {
    let content: Content

    var body: some View {
        content
            .glassEffect(.regular, in: Design.Shape.panel)
            .background(Design.Background.panel)
            .overlay(Design.Shape.panel.stroke(.black.opacity(0.5), lineWidth: 0.5))
            .clipShape(Design.Shape.panel)
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
    private var dismissal: PanelDismissal
    private let onVisibilityChange: ((Bool) -> Void)?

    var window: NSWindow { panel }
    var isVisible: Bool { panel.isVisible }

    init(
        params: PanelParams,
        view: AnyView,
        onVisibilityChange: ((Bool) -> Void)? = nil
    ) {
        hosting = NSHostingController(rootView: view)
        panel = FloatingPanel(contentRect: NSRect(origin: .zero, size: params.sizing.size))
        dismissal = params.dismissal
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
        panel.center()
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
        panel.minSize = params.sizing.minimumSize ?? NSSize(width: 1, height: 1)
        panel.maxSize = params.sizing.maximumSize ?? NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        resize(to: params.sizing.size)
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
            guard self.panel.isVisible else { return event }
            let locationInScreen = NSEvent.mouseLocation
            if !self.panel.frame.contains(locationInScreen) { self.hide() }
            return event
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self else { return }
            guard self.panel.isVisible else { return }
            let locationInScreen = NSEvent.mouseLocation
            if !self.panel.frame.contains(locationInScreen) { self.hide() }
        }
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

    static func load(params: PanelParams, view: AnyView, onVisibilityChange: ((Bool) -> Void)? = nil) -> PanelCoordinator {
        Self(
            controller: PanelProvider(
                params: params,
                view: view,
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

@Observable @MainActor final class PanelController {
    private(set) var coordinators: OrderedDictionary<AnyHashable, PanelCoordinator> = [:]

    func coordinator(for id: AnyHashable) -> PanelCoordinator? { coordinators[id] }

    func presented(_ id: AnyHashable) -> Bool { coordinators[id]?.isVisible ?? false }

    func toggle(_ id: AnyHashable, parameters: PanelParams, view: some View, onVisibilityChange: ((Bool) -> Void)? = nil) {
        coordinator(for: id, parameters: parameters, view: view, onVisibilityChange: onVisibilityChange).toggle()
    }

    func show(_ id: AnyHashable, parameters: PanelParams, view: some View, onVisibilityChange: ((Bool) -> Void)? = nil) {
        coordinator(for: id, parameters: parameters, view: view, onVisibilityChange: onVisibilityChange).show()
    }

    func hide(_ id: AnyHashable) { coordinators[id]?.hide() }

    private func coordinator(for id: AnyHashable, parameters: PanelParams, view: some View, onVisibilityChange: ((Bool) -> Void)?) -> PanelCoordinator {
        if let existing = coordinators[id] {
            existing.update(parameters)
            return existing
        }

        let coordinator = PanelCoordinator.load(
            params: parameters,
            view: AnyView(Float(content: view)),
            onVisibilityChange: onVisibilityChange
        )
        coordinators[id] = coordinator
        return coordinator
    }
}
