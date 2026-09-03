import AppKit
import SwiftUI


struct MenuPanelContent: View {
    let controller: MenuController
    let onSelect: (MenuItem) -> Void
    let onCancel: () -> Void
    let onCommit: () -> Void

    @FocusState private var focus: MenuFocus?

    var body: some View {
        Menu(
            query: Binding(get: { controller.query }, set: { controller.query = $0 }),
            formPrimary: Binding(get: { controller.formPrimary }, set: { controller.formPrimary = $0 }),
            kind: controller.kind,
            items: controller.items,
            selectedID: controller.selectedID,
            size: controller.size,
            position: .zero,
            focus: $focus,
            onMoveSelection: controller.moveSelection,
            onSelect: onSelect,
            onCancel: onCancel,
            onCommit: onCommit
        )
    }
}

struct MenuPanelHost: NSViewRepresentable {
    let controller: MenuController
    let isOpen: Bool
    let anchor: CGRect
    let size: CGSize
    let onSelect: (MenuItem) -> Void
    let onCancel: () -> Void
    let onCommit: () -> Void

    func makeCoordinator() -> MenuPanelPresenter { MenuPanelPresenter() }

    func makeNSView(context: Self.Context) -> NSView {
        let view = NSView(frame: .zero)
        view.isHidden = true
        return view
    }

    func updateNSView(_ view: NSView, context: Self.Context) {
        let presenter = context.coordinator
        presenter.onResignKey = onCancel
        presenter.onEscape = onCancel

        guard isOpen else {
            presenter.dismiss()
            return
        }

        let content = MenuPanelContent(
            controller: controller,
            onSelect: onSelect,
            onCancel: onCancel,
            onCommit: onCommit
        )

        guard let window = view.window else {
            DispatchQueue.main.async { [weak view] in
                guard let window = view?.window, isOpen else { return }
                presenter.present(content, size: size, anchor: anchor, in: window)
            }
            return
        }

        presenter.present(content, size: size, anchor: anchor, in: window)
    }

    static func dismantleNSView(_ view: NSView, coordinator: MenuPanelPresenter) {
        coordinator.dismiss()
    }
}

final class MenuPanelWindow: NSPanel {
    var onEscape: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { onEscape?() }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onEscape?() } else { super.keyDown(with: event) }
    }
}

@MainActor final class MenuPanelPresenter {
    private var panel: MenuPanelWindow?
    private weak var host: NSWindow?
    private var resignObserver: NSObjectProtocol?
    private var isPresented = false

    var onResignKey: (() -> Void)?
    var onEscape: (() -> Void)?

    @MainActor deinit {
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
    }

    func present(_ content: MenuPanelContent, size: CGSize, anchor: CGRect, in host: NSWindow) {
        let panel = panel ?? makePanel()
        self.panel = panel

        if let hosting = panel.contentView as? NSHostingView<MenuPanelContent> {
            hosting.rootView = content
        } else {
            panel.contentView = NSHostingView(rootView: content)
        }

        // The panel is transparent, but its hosting view's backing layer is not, and it is square.
        // SwiftUI clipping the content does not clip that layer, which is the hairline of unrounded
        // backing visible behind the panel's corners.
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = Style.Shape.largeRadius
        panel.contentView?.layer?.cornerCurve = .continuous
        panel.contentView?.layer?.masksToBounds = true

        panel.setFrame(frame(for: size, anchor: anchor, on: host.screen), display: true)

        if self.host !== host {
            self.host.map { $0.removeChildWindow(panel) }
            host.addChildWindow(panel, ordered: .above)
            self.host = host
        }

        guard !isPresented else { return }
        isPresented = true
        panel.makeKeyAndOrderFront(nil)
        observeResignKey(of: panel)
    }

    func dismiss() {
        isPresented = false
        guard let panel else { return }
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        resignObserver = nil
        host?.removeChildWindow(panel)
        panel.orderOut(nil)
        host = nil
    }

    private func observeResignKey(of panel: MenuPanelWindow) {
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.onResignKey?() }
        }
    }

    private func makePanel() -> MenuPanelWindow {
        let panel = MenuPanelWindow(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.onEscape = { [weak self] in self?.onEscape?() }
        panel.isMovableByWindowBackground = false
        panel.isMovable = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.transient, .ignoresCycle]
        return panel
    }

    private func frame(for size: CGSize, anchor: CGRect, on screen: NSScreen?) -> NSRect {
        let bounds = screen?.visibleFrame ?? anchor
        let gap = Style.Spacing.md
        let padding = Style.Spacing.xl
        let leading = bounds.minX + padding
        let trailing = max(leading, bounds.maxX - size.width - padding)
        let x = min(max(anchor.minX, leading), trailing)
        let below = anchor.minY - gap - size.height
        let above = anchor.maxY + gap
        let y = below >= bounds.minY + padding
        ? below
        : min(above, max(bounds.minY, bounds.maxY - size.height - padding))
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }
}
