import AppKit
import SwiftUI
import ScintComponents


final class FloatingPanel: NSPanel {
    var onEscape: () -> Void = {}

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = false
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { onEscape() }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onEscape() }
        else { super.keyDown(with: event) }
    }
}

@MainActor final class PanelProvider {
    private let panel = FloatingPanel()
    private let hosting = NSHostingView(rootView: AnyView(EmptyView()))
    private var params = PanelParams(size: .zero)
    private var monitors: [Any] = []
    private var observer: NSObjectProtocol?
    private var positioned = false
    var onVisibility: (Bool) -> Void = { _ in }

    init() {
        hosting.wantsLayer = true
        hosting.layer?.cornerCurve = .continuous
        hosting.layer?.masksToBounds = true
        panel.contentView = hosting
        panel.onEscape = { if self.params.dismissal.contains(.escape) { self.hide() } }
    }

    var visible: Bool { panel.isVisible }

    func show(_ params: PanelParams, _ view: some View, in parent: NSWindow? = nil) {
        let shown = panel.isVisible
        self.params = params
        hosting.rootView = AnyView(view)

        switch params.placement {
            case .centered:
                hosting.layer?.cornerRadius = Style.Shape.frameRadius
                panel.level = .floating
                panel.collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .fullScreenAuxiliary]
                panel.hidesOnDeactivate = false
                panel.isMovable = true
                panel.isMovableByWindowBackground = true
                panel.setFrame(NSRect(origin: panel.frame.origin, size: params.size), display: true)
                if !positioned { panel.center(); positioned = true }
                if !shown { NSApp.activate(ignoringOtherApps: true) }
            case .anchored(let anchor):
                hosting.layer?.cornerRadius = 13
                panel.collectionBehavior = [.transient, .ignoresCycle]
                panel.hidesOnDeactivate = true
                panel.isMovable = false
                panel.isMovableByWindowBackground = false
                if let parent, panel.parent !== parent {
                    panel.parent?.removeChildWindow(panel)
                    parent.addChildWindow(panel, ordered: .above)
                }
                panel.setFrame(frame(params.size, beneath: anchor), display: true)
        }

        if params.focused { panel.makeKeyAndOrderFront(nil) }
        else { panel.orderFront(nil) }
        panel.invalidateShadow()
        monitor()
        onVisibility(true)
    }

    func hide() {
        guard panel.isVisible else { return }
        unmonitor()
        panel.parent?.removeChildWindow(panel)
        panel.orderOut(nil)
        onVisibility(false)
    }

    private func monitor() {
        unmonitor()
        if params.dismissal.contains(.outsideClick) {
            let outside = { if !self.panel.frame.contains(NSEvent.mouseLocation) { self.hide() } }
            monitors = [
                NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { outside(); return $0 },
                NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in outside() }
            ].compactMap { $0 }
        }
        if params.dismissal.contains(.resignKey) {
            observer = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: panel, queue: .main) { _ in
                Task { @MainActor in self.hide() }
            }
        }
    }

    private func unmonitor() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
    }

    private func frame(_ size: CGSize, beneath anchor: CGRect) -> NSRect {
        let bounds = (panel.parent?.screen ?? NSScreen.main)?.visibleFrame ?? anchor
        let gap = Style.Spacing.label
        let padding = Style.Spacing.page
        let leading = bounds.minX + padding
        let trailing = max(leading, bounds.maxX - size.width - padding)
        let x = min(max(anchor.minX, leading), trailing)
        let below = anchor.minY - gap - size.height
        let above = anchor.maxY + gap
        let y = below >= bounds.minY + padding ? below : min(above, max(bounds.minY, bounds.maxY - size.height - padding))
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }
}
