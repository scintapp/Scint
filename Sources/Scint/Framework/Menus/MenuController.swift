import AppKit
import SwiftUI


/// A filterable command palette: a list of items, or a small form, plus the keyboard handling
/// that drives both.
///
/// It knows nothing about what a host does with a result. Choosing an item or submitting a form
/// produces a `MenuOutcome` and stops there — applying it is the host's job. Everything that used
/// to make this an editor component arrives through the initialiser instead: the fixed items, and
/// a `search` closure that decides what a query matches.
@Observable final class MenuController {
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

    /// - Parameters:
    ///   - items: the palette shown before anything is typed.
    ///   - search: resolves a query for the reference-backed kinds. Returning `[]` for a kind is
    ///     how a host says "this kind is a form, not a list".
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
                return CGSize(width: Style.Spacing.menuWidth, height: Style.Spacing.menuListHeight)
            case .create, .update:
                return CGSize(width: Style.Spacing.menuWidth, height: Style.Spacing.menuFormHeight)
        }
    }

    // MARK: - Presenting

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

    /// Opens straight onto a filled-in form, for editing something that already exists. The host
    /// works out which form and what to prefill; this used to read a `Material.Block` directly.
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

    // MARK: - Selection

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

    // MARK: - Committing

    func handleInput(_ selector: Selector) -> (handled: Bool, outcome: MenuOutcome?) {
        guard isOpen else { return (false, nil) }
        switch selector {
            case #selector(NSResponder.insertNewline(_:)):
                return (true, commit())
            case #selector(NSResponder.insertTab(_:)), #selector(NSResponder.moveDown(_:)):
                moveSelection(1)
                return (true, nil)
            case #selector(NSResponder.moveUp(_:)):
                moveSelection(-1)
                return (true, nil)
            case #selector(NSResponder.cancelOperation(_:)):
                close()
                return (true, nil)
            default:
                return (false, nil)
        }
    }

    /// The choice the host should act on, or nil when there is nothing to commit yet — including
    /// when the chosen item raises a form, which replaces the menu's contents in place.
    func commit() -> MenuOutcome? {
        switch kind {
            case .fixed, .dynamic, .update(.artifact), .update(.command), .update(.material):
                guard let item = selectedItem else { return nil }
                if case .fixed = kind, let form = item.opens { openCreate(form); return nil }
                return outcome(.item(item))
            case .create(let form), .update(let form):
                return outcome(
                    .form(form, MenuFormValues(primary: formPrimary, completed: formCompleted))
                )
        }
    }

    // MARK: - Contents

    private var normalizedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var selectedItem: MenuItem? {
        if let selectedID, let selected = items.first(where: { $0.id == selectedID }) { return selected }
        return items.first(where: \.isSelectable)
    }

    private var currentItems: [MenuItem] {
        switch kind {
            case .fixed:
                return trimmedDividers(in: fixedItems.filter {
                    if case .dividerItem = $0 { return normalizedQuery.isEmpty }
                    return $0.matches(normalizedQuery)
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
            if case .dividerItem = item, result.last?.isSelectable != true { continue }
            result.append(item)
        }
        while result.last?.isSelectable == false { result.removeLast() }
        return result
    }
}
