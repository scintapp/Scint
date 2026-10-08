
import AppKit
import SwiftUI
import ScintRuntime
import ScintComponents


struct MenuPanelContent: View {
    let controller: MenuProvider
    let onSelect: (MenuItem) -> Void
    let onCancel: () -> Void
    let onCommit: () -> Void

    @FocusState private var focus: MenuFocus?

    var body: some View {
        switch controller.kind {
            case .fixed, .dynamic:
                MenuList(items: controller.items, selectedID: controller.selectedID, onSelect: onSelect)
                    .frame(width: controller.size.width, height: controller.size.height)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            case .create, .update:
                MenuLayout(
                    query: Binding(get: { controller.query }, set: { controller.query = $0 }),
                    formPrimary: Binding(get: { controller.formPrimary }, set: { controller.formPrimary = $0 }),
                    kind: controller.kind, items: controller.items, selectedID: controller.selectedID,
                    size: controller.size, position: .zero, focus: $focus,
                    onMoveSelection: controller.moveSelection, onSelect: onSelect, onCancel: onCancel, onCommit: onCommit
                )
        }
    }
}

struct MenuPanelHost: NSViewRepresentable {
    let controller: MenuProvider
    let isOpen: Bool
    let anchor: CGRect
    let size: CGSize
    let onSelect: (MenuItem) -> Void
    let onCancel: () -> Void
    let onCommit: () -> Void

    func makeCoordinator() -> MenuPanelPresenter { MenuPanelPresenter() }

    func makeNSView(context: Self.Context) -> MenuPanelAnchor {
        let view = MenuPanelAnchor(frame: .zero)
        view.isHidden = true
        return view
    }

    func updateNSView(_ view: MenuPanelAnchor, context: Self.Context) {
        let presenter = context.coordinator
        presenter.onResignKey = onCancel
        presenter.onEscape = onCancel

        guard isOpen else {
            view.onAttach = nil
            presenter.dismiss()
            return
        }

        let content = MenuPanelContent(
            controller: controller,
            onSelect: onSelect,
            onCancel: onCancel,
            onCommit: onCommit
        )

        view.onAttach = { [weak view] in
            guard let window = view?.window else { return }
            presenter.present(content, size: size, anchor: anchor, in: window)
        }
        view.onAttach?()
    }

    static func dismantleNSView(_ view: MenuPanelAnchor, coordinator: MenuPanelPresenter) {
        coordinator.dismiss()
    }
}

final class MenuPanelAnchor: NSView {
    var onAttach: (() -> Void)?
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); onAttach?() }
}

final class MenuPanelWindow: NSPanel {
    var onEscape: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { onEscape?() }
    override func keyDown(with event: NSEvent) { if event.keyCode == 53 { onEscape?() } else { super.keyDown(with: event) } }
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

        if let hosting = panel.contentView as? NSHostingView<MenuPanelContent> { hosting.rootView = content }
        else { panel.contentView = NSHostingView(rootView: content) }

        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = 13
        panel.contentView?.layer?.cornerCurve = .continuous
        panel.contentView?.layer?.masksToBounds = true

        panel.setFrame(frame(for: size, anchor: anchor, on: host.screen), display: true)

        if self.host !== host {
            self.host.map { $0.removeChildWindow(panel) }
            host.addChildWindow(panel, ordered: .above)
            self.host = host
        }

        switch content.controller.kind {
            case .fixed, .dynamic: panel.orderFront(nil)
            case .create, .update:
                if !panel.isKeyWindow { panel.makeKeyAndOrderFront(nil) }
        }
        if !isPresented { isPresented = true; observeResignKey(of: panel) }
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
        panel.hasShadow = true
        panel.animationBehavior = .utilityWindow
        panel.collectionBehavior = [.transient, .ignoresCycle]
        return panel
    }

    private func frame(for size: CGSize, anchor: CGRect, on screen: NSScreen?) -> NSRect {
        let bounds = screen?.visibleFrame ?? anchor
        let gap = Style.Spacing.label
        let padding = Style.Spacing.page
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

@Observable final class MenuProvider {
    private(set) var items: [MenuItem] = []
    private(set) var target: AnyHashable?

    var kind: MenuKind = .fixed
    var query = "" { didSet { if isOpen { refreshItems() } } }
    var selectedID: String?
    var replacementRange = NSRange(location: 0, length: 0)
    var anchorRect: CGRect = .zero
    var isOpen = false
    var formPrimary = ""
    var formCompleted = false

    private let fixedItems: [MenuItem]
    private let search: (String, MenuKind) -> [MenuItem]

    init(items: [MenuItem], search: @escaping (String, MenuKind) -> [MenuItem]) {
        self.fixedItems = items
        self.items = items
        self.search = search
    }

    var isInserting: Bool {
        switch kind {
            case .fixed, .dynamic, .create: return true
            case .update: return false
        }
    }

    var size: CGSize {
        switch kind {
            case .fixed, .dynamic:
                return CGSize(width: Metrics.menuWidth, height: Metrics.menuListHeight)
            case .create, .update:
                return CGSize(width: Metrics.menuWidth, height: Metrics.menuFormHeight)
        }
    }

    func open(kind: MenuKind, query: String, target: AnyHashable, replacementRange: NSRange, anchorRect: CGRect) {
        let reset = !isOpen || self.kind != kind
        isOpen = true
        self.kind = kind
        self.target = target
        self.query = query
        self.replacementRange = replacementRange
        self.anchorRect = anchorRect
        if reset {
            selectedID = nil
            formPrimary = ""
            formCompleted = false
        }
        refreshItems()
    }

    func edit(form: MenuFormKind, values: MenuFormValues, target: AnyHashable, anchorRect: CGRect) {
        self.target = target
        self.kind = .update(form)
        self.replacementRange = NSRange(location: 0, length: 0)
        self.anchorRect = anchorRect
        self.isOpen = true
        self.selectedID = nil
        self.formPrimary = values.primary
        self.formCompleted = values.completed
        self.query = ""
        refreshItems()
    }

    func close() {
        isOpen = false
        kind = .fixed
        query = ""
        target = nil
        replacementRange = NSRange(location: 0, length: 0)
        anchorRect = .zero
        selectedID = nil
        formPrimary = ""
        formCompleted = false
        items = []
    }

    func select(_ item: MenuItem) {
        guard item.isSelectable else { return }
        selectedID = item.id
    }

    func moveSelection(_ delta: Int) {
        let selectable = items.filter(\.isSelectable)
        guard !selectable.isEmpty else { selectedID = nil; return }
        guard let selectedID, let index = selectable.firstIndex(where: { $0.id == selectedID })
        else { self.selectedID = selectable.first?.id; return }
        self.selectedID = selectable[(index + delta + selectable.count) % selectable.count].id
    }

    func commit() -> MenuOutcome? {
        switch kind {
            case .fixed, .dynamic, .update(.artifact), .update(.command), .update(.document):
                guard let item = selectedItem else { return nil }
                if case .fixed = kind, let form = item.opens { openCreate(form); return nil }
                return outcome(.item(item))
            case .create(let form), .update(let form):
                return outcome(
                    .form(form, MenuFormValues(primary: formPrimary, completed: formCompleted))
                )
        }
    }

    private var normalizedMapper: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var selectedItem: MenuItem? {
        if let selectedID, let selected = items.first(where: { $0.id == selectedID }) { return selected }
        return items.first(where: \.isSelectable)
    }

    private var currentItems: [MenuItem] {
        switch kind {
            case .fixed:
                return trimmedDividers(in: fixedItems.filter {
                    if case .divider = $0 { return normalizedMapper.isEmpty }
                    return $0.matches(normalizedMapper)
                })
            case .dynamic, .update:
                return search(query, kind)
            case .create:
                return []
        }
    }

    private func outcome(_ choice: MenuOutcome.Choice) -> MenuOutcome? {
        guard let target else { return nil }
        return MenuOutcome(
            choice: choice,
            kind: kind,
            isInserting: isInserting,
            target: target,
            replacementRange: replacementRange
        )
    }

    private func openCreate(_ form: MenuFormKind) {
        kind = .create(form)
        query = ""
        selectedID = nil
        formPrimary = form == .task ? "Task" : ""
        formCompleted = false
        items = []
    }

    private func refreshItems() {
        items = currentItems
        let selectable = items.filter(\.isSelectable)
        if selectable.isEmpty { selectedID = nil }
        else if !selectable.contains(where: { $0.id == selectedID }) { selectedID = selectable.first?.id }
    }

    private func trimmedDividers(in items: [MenuItem]) -> [MenuItem] {
        var result: [MenuItem] = []
        for item in items {
            if case .divider = item, result.last?.isSelectable != true { continue }
            result.append(item)
        }
        while result.last?.isSelectable == false { result.removeLast() }
        return result
    }
}
