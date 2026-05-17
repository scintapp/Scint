import AgencyRuntime
import AppKit
import SwiftUI


enum MenuSubmenu: String, Equatable {
    case controls
    case skills

    var title: String {
        switch self {
        case .controls: return "Controls"
        case .skills: return "Skills"
        }
    }

    var placeholder: String {
        switch self {
        case .controls: return "Controls will be listed here."
        case .skills: return "Skills will be listed here."
        }
    }
}

enum MenuActivation {
    case insert(item: MenuItem, replacementRange: NSRange)
    case openSubmenu(MenuSubmenu)
}

struct MenuItem: Identifiable, Equatable {
    enum Kind: Equatable {
        case action
        case submenu(MenuSubmenu)
        case divider
    }

    let id: String
    let label: String
    let icon: String?
    let keywords: [String]
    let kind: Kind

    init(id: String, label: String, icon: String? = nil, keywords: [String] = []) {
        self.init(id: id, label: label, icon: icon, keywords: keywords, kind: .action)
    }

    init(id: String, label: String, icon: String? = nil, submenu: MenuSubmenu, keywords: [String] = []) {
        self.init(id: id, label: label, icon: icon, keywords: keywords, kind: .submenu(submenu))
    }

    private init(id: String, label: String, icon: String?, keywords: [String], kind: Kind) {
        self.id = id
        self.label = label
        self.icon = icon
        self.keywords = keywords
        self.kind = kind
    }

    static func divider(_ id: String) -> MenuItem {
        MenuItem(id: id, label: "", icon: nil, keywords: [], kind: .divider)
    }

    var isSelectable: Bool {
        if case .divider = kind { return false }
        return true
    }

    var submenu: MenuSubmenu? {
        guard case .submenu(let submenu) = kind else { return nil }
        return submenu
    }
}

@Observable final class MenuModel {
    var items: [MenuItem]
    var query: String = ""
    var item: String?
    var replacementRange = NSRange(location: 0, length: 0)
    var anchorRect: CGRect = .zero
    var presentedSubmenu: MenuSubmenu?
    var isOpen = false

    var filtered: [MenuItem] {
        let q = normalizedQuery
        guard !q.isEmpty else { return items }
        return items.filter { item in
            item.isSelectable && (
                item.label.localizedCaseInsensitiveContains(q)
                || item.keywords.contains { $0.localizedCaseInsensitiveContains(q) }
            )
        }
    }

    private var normalizedQuery: String {
        query.lowercased().trimmingCharacters(in: .whitespaces)
    }

    init(items: [MenuItem] = []) { self.items = items }

    func open(query: String, replacementRange: NSRange, anchorRect: CGRect) {
        let wasClosed = !isOpen
        isOpen = true
        self.query = query
        self.replacementRange = replacementRange
        if wasClosed {
            self.anchorRect = anchorRect
            presentedSubmenu = nil
        }
        ensureValidSelection()
    }

    func close() {
        isOpen = false
        query = ""
        replacementRange = NSRange(location: 0, length: 0)
        anchorRect = .zero
        presentedSubmenu = nil
        item = nil
    }

    func select(itemId: String) {
        item = itemId
    }

    func cycle(reverse: Bool = false) {
        let items = selectableItems
        guard !items.isEmpty else { return }
        guard let current = item,
              let idx = items.firstIndex(where: { $0.id == current }) else {
            item = items.first?.id
            return
        }
        let next = reverse
            ? (idx - 1 + items.count) % items.count
            : (idx + 1) % items.count
        item = items[next].id
    }

    func activateSelection() -> MenuActivation? {
        guard isOpen,
              let item = selectedMenuItem else { return nil }

        switch item.kind {
        case .action:
            return .insert(item: item, replacementRange: replacementRange)
        case .submenu(let submenu):
            presentedSubmenu = submenu
            return .openSubmenu(submenu)
        case .divider:
            return nil
        }
    }

    func openSubmenuForSelection() {
        guard let submenu = selectedMenuItem?.submenu else { return }
        presentedSubmenu = submenu
    }

    func closeSubmenu() {
        presentedSubmenu = nil
    }

    private var selectableItems: [MenuItem] {
        filtered.filter(\.isSelectable)
    }

    private var selectedMenuItem: MenuItem? {
        guard let item else { return nil }
        return filtered.first(where: { $0.id == item })
    }

    private func ensureValidSelection() {
        let items = selectableItems
        if items.isEmpty {
            item = nil
        } else if !items.contains(where: { $0.id == item }) {
            item = items.first?.id
        }
    }
}
