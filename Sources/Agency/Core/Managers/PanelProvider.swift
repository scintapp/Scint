import AppKit
import Observation
import SwiftUI


extension Notification.Name { static let agencyPanelEscape = Notification.Name("AgencyPanelEscape") }

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
    private var dismissOnOutsideClick = false

    var window: NSWindow { panel }
    var isVisible: Bool { panel.isVisible }

    init(size: CGSize, agency: AgencyModel, view: AnyView) {
        hosting = NSHostingController(rootView: view)
        panel = FloatingPanel(contentRect: NSRect(origin: .zero, size: size))
        panel.contentView = hosting.view
        super.init()
        panel.delegate = self
        panel.onEscape = { [weak self] in
            let event = PanelEscapeEvent()
            NotificationCenter.default.post(name: .agencyPanelEscape, object: event)
            if !event.handled { self?.hide() }
        }
    }

    func windowWillClose(_ notification: Notification) {
        removeEventMonitors()
    }

    func toggle() {
        panel.isVisible ? hide() : show()
    }

    func show() {
        panel.center()
        installEventMonitors()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        removeEventMonitors()
        if let parent = panel.parent { parent.removeChildWindow(panel) }
        panel.orderOut(nil)
    }

    func resize(to size: CGSize) {
        var frame = panel.frame
        frame.size = size
        panel.setFrame(frame, display: true, animate: false)
    }

    private func installEventMonitors() {
        removeEventMonitors()
        guard dismissOnOutsideClick else { return }

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

    static func load(_ agency: AgencyModel, size: CGSize, view: AnyView) -> PanelCoordinator {
        Self(controller: PanelProvider(size: size, agency: agency, view: view))
    }

    func show() { controller.show() }
    func hide() { controller.hide() }
    func toggle() { controller.toggle() }
}
