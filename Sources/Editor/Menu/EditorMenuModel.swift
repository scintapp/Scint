import AgencyRuntime
import AppKit
import SwiftUI


enum EditorMenuKind: Equatable {
    case command
    case reference
    case form(MenuFormKind)
}

enum MenuFormKind: Equatable {
    case task
    case link

    var title: String {
        switch self {
        case .task: return "New Task"
        case .link: return "New Link"
        }
    }

    var icon: String {
        switch self {
        case .task: return "checkmark.circle"
        case .link: return "link"
        }
    }

    var primaryPlaceholder: String {
        switch self {
        case .task: return "Task"
        case .link: return "Title"
        }
    }
}

enum MenuItem: Identifiable, Equatable {
    case commandItem(id: String, label: String, icon: String?, keywords: [String])
    case reference(Reference, name: String, description: String, tags: [String])
    case dividerItem(String)

    var id: String {
        switch self {
        case .commandItem(let id, _, _, _): return "command:\(id)"
        case .reference(let ref, _, _, _): return "reference:\(ref.id.uuidString)"
        case .dividerItem(let id): return "divider:\(id)"
        }
    }

    var commandID: String? {
        guard case .commandItem(let id, _, _, _) = self else { return nil }
        return id
    }

    var label: String {
        switch self {
        case .commandItem(_, let label, _, _): return label
        case .reference(_, let name, _, _): return name
        case .dividerItem: return ""
        }
    }

    var detail: String {
        switch self {
        case .commandItem: return ""
        case .reference(_, _, let description, let tags):
            if !description.isEmpty { return description }
            return tags.joined(separator: " ")
        case .dividerItem: return ""
        }
    }

    var ref: Reference? {
        guard case .reference(let ref, _, _, _) = self else { return nil }
        return ref
    }

    var icon: String? {
        switch self {
        case .commandItem(_, _, let icon, _): return icon
        case .reference: return nil
        case .dividerItem: return nil
        }
    }

    var isSelectable: Bool {
        if case .dividerItem = self { return false }
        return true
    }

    func matches(_ query: String) -> Bool {
        guard !query.isEmpty else { return true }

        switch self {
        case .commandItem(_, let label, _, let keywords):
            return label.localizedCaseInsensitiveContains(query)
                || keywords.contains { $0.localizedCaseInsensitiveContains(query) }
        case .reference(_, let name, let description, let tags):
            return name.localizedCaseInsensitiveContains(query)
                || description.localizedCaseInsensitiveContains(query)
                || tags.contains { $0.localizedCaseInsensitiveContains(query) }
        case .dividerItem:
            return false
        }
    }

    static func command(id: String, label: String, icon: String? = nil, keywords: [String] = []) -> MenuItem {
        .commandItem(id: id, label: label, icon: icon, keywords: keywords)
    }

    static func divider(_ id: String) -> MenuItem {
        .dividerItem(id)
    }
}

struct MenuCommit {
    let entries: [Block]
    let replacementRange: NSRange
}

@Observable final class MenuModel {
    private(set) var items: [MenuItem] = []
    private let commandItems: [MenuItem]
    private let makeEntries: (MenuItem) -> [Block]?
    private var normalizedQuery: String { query.lowercased().trimmingCharacters(in: .whitespaces) }

    private var currentItems: [MenuItem] {
        switch kind {
            case .command:
                let filtered = commandItems.filter { item in
                    if case .dividerItem = item { return normalizedQuery.isEmpty }
                    return item.matches(normalizedQuery)
                }
                return trimmedDividers(in: filtered)
            case .reference:
                return MenuSearch.items(for: query)
            case .form:
                return []
        }
    }

    var kind: EditorMenuKind = .command
    var query: String = ""
    var selectedID: String?
    var replacementRange = NSRange(location: 0, length: 0)
    var anchorRect: CGRect = .zero
    var isOpen = false
    var formPrimary = ""
    var formSecondary = ""

    var size: CGSize {
        switch kind {
        case .command: return CGSize(width: 240, height: 280)
        case .reference: return CGSize(width: 240, height: 280)
        case .form(.task): return CGSize(width: 320, height: 162)
        case .form(.link): return CGSize(width: 320, height: 214)
        }
    }

    init(items: [MenuItem] = [], makeEntries: @escaping (MenuItem) -> [Block]? = { _ in nil }) {
        self.commandItems = items
        self.makeEntries = makeEntries
        self.items = items
    }

    func open(kind: EditorMenuKind, query: String, replacementRange: NSRange, anchorRect: CGRect) {
        let wasClosed = !isOpen
        let kindChanged = self.kind != kind

        isOpen = true
        self.kind = kind
        self.query = query
        self.replacementRange = replacementRange
        refreshItems()

        if wasClosed || kindChanged {
            self.anchorRect = anchorRect
            selectedID = nil
            formPrimary = ""
            formSecondary = ""
        }

        ensureValidSelection()
    }

    func close() {
        isOpen = false
        kind = .command
        query = ""
        replacementRange = NSRange(location: 0, length: 0)
        anchorRect = .zero
        selectedID = nil
        formPrimary = ""
        formSecondary = ""
        items = []
    }

    func select(_ item: MenuItem) {
        guard item.isSelectable else { return }
        selectedID = item.id
    }

    func moveSelection(_ delta: Int) {
        let selectable = items.filter(\.isSelectable)
        guard !selectable.isEmpty else {
            selectedID = nil
            return
        }

        guard let selectedID, let index = selectable.firstIndex(where: { $0.id == selectedID })
        else {
            self.selectedID = selectable.first?.id
            return
        }

        self.selectedID = selectable[(index + delta + selectable.count) % selectable.count].id
    }

    func handleCommand(_ selector: Selector) -> (handled: Bool, commit: MenuCommit?) {
        guard isOpen else { return (false, nil) }

        switch selector {
        case #selector(NSResponder.insertNewline(_:)):
            return (true, commitSelection())
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

    func commitSelection() -> MenuCommit? {
        switch kind {
        case .command, .reference:
            guard let selected = selectedItem else { return nil }
            return commit(selected)
        case .form(let formKind):
            return commitForm(formKind)
        }
    }

    private var selectedItem: MenuItem? {
        if let selectedID, let selected = items.first(where: { $0.id == selectedID }) {
            return selected
        }
        return items.first(where: \.isSelectable)
    }

    private func commit(_ item: MenuItem) -> MenuCommit? {
        switch item {
        case .commandItem:
            if item.commandID == "new-task" {
                openForm(.task)
                return nil
            }
            if item.commandID == "new-link" {
                openForm(.link)
                return nil
            }

            guard let entries = makeEntries(item), !entries.isEmpty else { return nil }
            let range = replacementRange
            close()
            return MenuCommit(entries: entries, replacementRange: range)

        case .reference(let ref, _, _, _):
            guard let entry = MenuSearch.entry(for: ref) else { return nil }
            let range = replacementRange
            close()
            return MenuCommit(entries: [entry], replacementRange: range)

        case .dividerItem:
            return nil
        }
    }

    private func openForm(_ formKind: MenuFormKind) {
        kind = .form(formKind)
        query = ""
        selectedID = nil
        formPrimary = defaultPrimaryValue(for: formKind)
        formSecondary = ""
        items = []
    }

    private func commitForm(_ kind: MenuFormKind) -> MenuCommit? {
        let title = formPrimary.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry: Block

        switch kind {
        case .task:
            entry = .task(UUID(), title.isEmpty ? "Task" : title, false)
        case .link:
            let fallbackTitle = title.isEmpty ? "Link" : title
            let url = normalizedURL(from: formSecondary)
            let ref = Artifact.register(fallbackTitle, url!)
            if url == nil { Artifact.update(ref) { $0.handle = .http(nil) } }
            entry = .artifact(ref)
        }

        let range = replacementRange
        close()
        return MenuCommit(entries: [entry], replacementRange: range)
    }

    private func ensureValidSelection() {
        let selectable = items.filter(\.isSelectable)
        if selectable.isEmpty { selectedID = nil }
        else if !selectable.contains(where: { $0.id == selectedID }) { selectedID = selectable.first?.id }
    }

    private func refreshItems() { items = currentItems }

    private func trimmedDividers(in items: [MenuItem]) -> [MenuItem] {
        var result: [MenuItem] = []
        var previousWasDivider = true

        for item in items {
            if case .dividerItem = item {
                guard !previousWasDivider else { continue }
                previousWasDivider = true
                result.append(item)
            } else {
                previousWasDivider = false
                result.append(item)
            }
        }

        while result.last?.isSelectable == false { result.removeLast() }
        return result
    }

    private func defaultPrimaryValue(for formKind: MenuFormKind) -> String {
        switch formKind {
        case .task: return "Task"
        case .link: return "Link"
        }
    }

    private func normalizedURL(from value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil { return url }
        return URL(string: "https://\(trimmed)")
    }
}
