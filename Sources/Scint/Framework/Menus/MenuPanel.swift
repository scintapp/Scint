import AppKit
import SwiftUI


/// Presents a `MenuController` in a child window.
///
/// The menu used to be a SwiftUI overlay living inside whichever view opened it. That meant it was
/// clipped by any scrolling ancestor, painted over by any later sibling, and had to convert between
/// four coordinate spaces to decide where to sit — three separate bugs with one cause. A child
/// window has none of those problems: it positions in screen coordinates, nothing can clip it, and
/// nothing in the host's view tree can cover it.
///
/// The `Menu` view inside is unchanged. It is handed `position: .zero` because the window does the
/// positioning now, which makes its own `.offset` inert.
@MainActor final class MenuPanelPresenter {
    private var panel: MenuPanelWindow?
    private weak var host: NSWindow?
    private var resignObserver: NSObjectProtocol?
    /// Tracked here rather than read off the panel: `addChildWindow` orders the panel in, so
    /// `panel.isVisible` is already true by the time this would be asked.
    private var isPresented = false

    /// Called when the panel stops being key — a click back in the document, or the app
    /// deactivating. Standard dismissal for a transient palette.
    var onResignKey: (() -> Void)?

    /// Called on Escape. Handled by the panel itself rather than relying on whatever happens to
    /// hold first responder inside it.
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

        panel.setFrame(frame(for: size, anchor: anchor, on: host.screen), display: true)

        if self.host !== host {
            self.host.map { $0.removeChildWindow(panel) }
            host.addChildWindow(panel, ordered: .above)
            self.host = host
        }

        guard !isPresented else { return }
        isPresented = true

        // `addChildWindow` above has already ordered the panel in, so guarding this on
        // `panel.isVisible` — as this did — meant the panel never became key. The filter field
        // then had no key window to take focus in, the editor had already given its own up, and
        // Escape had nothing to land on. One missing call, all three symptoms.
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
        // Without this a panel only takes key when something in it demands text input, which is
        // the sort of "sometimes there is a caret" behaviour that makes a menu feel broken.
        panel.becomesKeyOnlyIfNeeded = false
        panel.onEscape = { [weak self] in self?.onEscape?() }
        panel.isMovableByWindowBackground = false
        panel.isMovable = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        // The menu view draws its own glass and shadow; a window shadow would double it.
        panel.hasShadow = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.transient, .ignoresCycle]
        return panel
    }

    /// Screen coordinates grow upward, so "below the caret" is the smaller y. Falls back to
    /// flipping above when there is no room underneath.
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

/// Borderless panels refuse key by default, which would leave the filter unable to type.
///
/// The menu always takes focus. A query needs a real input with an explicit end — that is what
/// lets it hold spaces, and what makes the caret's whereabouts predictable instead of depending on
/// which menu happened to open.
final class MenuPanelWindow: NSPanel {
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // Escape closes the menu wherever focus sits inside it — the same handling `FloatingPanel`
    // uses for the app's own panels.
    override func cancelOperation(_ sender: Any?) { onEscape?() }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onEscape?() } else { super.keyDown(with: event) }
    }
}

/// Owns the `@FocusState` the menu needs, since that only exists inside a SwiftUI view. A wrapper,
/// not a replacement — `Menu` itself is untouched.
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

/// Drops into any view tree to bind a `MenuController` to a panel on the host window.
///
/// The values it reads — `isOpen`, `anchor`, `size` — are passed in rather than observed here, so
/// that reading them in the parent's body is what schedules the update. The panel's *contents*
/// need no such trigger: `MenuPanelContent` observes the controller directly.
struct MenuPanelHost: NSViewRepresentable {
    let controller: MenuController
    let isOpen: Bool
    /// The caret, in screen coordinates.
    let anchor: CGRect
    /// Drives the panel's frame. Reading it in the host's body is what schedules a resize when
    /// the menu switches between its list and its form.
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

        // On the pass that opens the menu the view may not be in a window yet.
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
