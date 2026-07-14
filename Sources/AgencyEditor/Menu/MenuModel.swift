import AgencyRuntime
import AppKit
import SwiftUI


struct MenuInsertion {
    let blocks: [Sheet.Block]
    let target: AnyHashable
    let replacementRange: NSRange
}

enum MenuKind: Equatable {
    case fixed
    case dynamic
    case create(MenuFormKind)
    case update(MenuFormKind)
}

enum MenuFormKind: Equatable {
    case task
    case link
    case artifact
    case command
    case sheet

    var name: String {
        switch self {
            case .task: return "Task"
            case .link: return "Link"
            case .artifact: return "Artifact"
            case .command: return "Command"
            case .sheet: return "Sheet"
        }
    }

    var icon: String {
        switch self {
            case .task: return "checkmark.circle"
            case .link: return "link"
            case .artifact: return "folder.badge.plus"
            case .command: return "curlybraces"
            case .sheet: return "textformat"
        }
    }

    func title(updating: Bool) -> String { "\(updating ? "Edit" : "New") \(name)" }

    var primaryPlaceholder: String {
        switch self {
            case .task: return "Task"
            case .link: return "URL"
            case .artifact, .command, .sheet: return "Search \(name.lowercased())s"
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
            case .commandItem, .dividerItem: return ""
            case .reference(_, _, let description, let tags):
                return description.isEmpty ? tags.joined(separator: " ") : description
        }
    }

    var ref: Reference? {
        guard case .reference(let ref, _, _, _) = self else { return nil }
        return ref
    }

    var icon: String? {
        guard case .commandItem(_, _, let icon, _) = self else { return nil }
        return icon
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
            case .dividerItem: return false
        }
    }

    static func command(id: String, label: String, icon: String? = nil, keywords: [String] = []) -> MenuItem {
        .commandItem(id: id, label: label, icon: icon, keywords: keywords)
    }

    static func divider(_ id: String) -> MenuItem { .dividerItem(id) }
}

@Observable final class MenuModel {
    private let sheet: SheetModel
    private let fixedItems: [MenuItem]
    private let makeBlocks: (MenuItem) -> [Sheet.Block]?
    private var target: AnyHashable?

    private var normalizedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var currentItems: [MenuItem] {
        switch kind {
            case .fixed:
                return trimmedDividers(in: fixedItems.filter {
                    if case .dividerItem = $0 { return normalizedQuery.isEmpty }
                    return $0.matches(normalizedQuery)
                })
            case .dynamic:
                return MenuSearch.items(for: query)
            case .update(let form) where form == .artifact || form == .command || form == .sheet:
                return MenuSearch.items(for: query) { ref in
                    switch form {
                        case .artifact: return ref.type == Artifact.self
                        case .command: return ref.type == Command.self
                        case .sheet: return ref.type == Sheet.self
                        default: return false
                    }
                }
            case .create, .update:
                return []
        }
    }

    private(set) var items: [MenuItem] = []
    var kind: MenuKind = .fixed
    var query = "" { didSet { if isOpen { refreshItems() } } }
    var selectedID: String?
    var replacementRange = NSRange(location: 0, length: 0)
    var anchorRect: CGRect = .zero
    var isOpen = false
    var formPrimary = ""
    var formCompleted = false

    var isInserting: Bool {
        switch kind {
            case .fixed, .dynamic, .create: return true
            case .update: return false
        }
    }

    var size: CGSize {
        switch kind {
            case .fixed, .dynamic: return CGSize(width: 300, height: 336)
            case .create, .update(.task), .update(.link): return CGSize(width: 320, height: 162)
            case .update: return CGSize(width: 300, height: 336)
        }
    }

    init(sheet: SheetModel, items: [MenuItem], makeBlocks: @escaping (MenuItem) -> [Sheet.Block]?) {
        self.sheet = sheet
        self.fixedItems = items
        self.makeBlocks = makeBlocks
        self.items = items
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

    func edit(_ block: Sheet.Block, anchorRect: CGRect) {
        target = block.id
        replacementRange = NSRange(location: 0, length: 0)
        self.anchorRect = anchorRect
        isOpen = true
        selectedID = nil
        formCompleted = false

        switch block {
            case .task(_, let text, let completed):
                kind = .update(.task)
                formPrimary = text
                formCompleted = completed
            case .artifact(let ref):
                let link = Artifact.with(ref) { artifact -> (Bool, String) in
                    if case .http(let url) = artifact.handle { return (true, url?.absoluteString ?? "") }
                    return (false, "")
                } ?? (false, "")
                kind = .update(link.0 ? .link : .artifact)
                formPrimary = link.1
            case .command:
                kind = .update(.command)
                formPrimary = ""
            case .sheet:
                kind = .update(.sheet)
                formPrimary = ""
            case .text:
                close()
                return
        }
        query = ""
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

    func handleInput(_ selector: Selector) -> (handled: Bool, result: (AnyHashable, NSRange?)?) {
        guard isOpen else { return (false, nil) }
        switch selector {
            case #selector(NSResponder.insertNewline(_:)): return (true, commitSelection())
            case #selector(NSResponder.insertTab(_:)), #selector(NSResponder.moveDown(_:)):
                moveSelection(1)
                return (true, nil)
            case #selector(NSResponder.moveUp(_:)):
                moveSelection(-1)
                return (true, nil)
            case #selector(NSResponder.cancelOperation(_:)):
                close()
                return (true, nil)
            default: return (false, nil)
        }
    }

    func commitSelection() -> (AnyHashable, NSRange?)? {
        switch kind {
            case .fixed, .dynamic, .update(.artifact), .update(.command), .update(.sheet):
                guard let item = selectedItem else { return nil }
                return commit(item)
            case .create(let form), .update(let form):
                return commitForm(form)
        }
    }

    private var selectedItem: MenuItem? {
        if let selectedID, let selected = items.first(where: { $0.id == selectedID }) { return selected }
        return items.first(where: \.isSelectable)
    }

    private func commit(_ item: MenuItem) -> (AnyHashable, NSRange?)? {
        if case .fixed = kind, item.commandID == "new-task" { openCreate(.task); return nil }
        if case .fixed = kind, item.commandID == "new-link" { openCreate(.link); return nil }

        let blocks: [Sheet.Block]
        if let ref = item.ref, let block = MenuSearch.block(for: ref) { blocks = [block] }
        else if let built = makeBlocks(item), !built.isEmpty { blocks = built }
        else { return nil }

        if case .update = kind {
            guard let target, let block = blocks.first, let id = sheet.update(block, replacing: target) else { return nil }
            close()
            return (id, nil)
        }

        guard let target else { return nil }
        return apply(MenuInsertion(blocks: blocks, target: target, replacementRange: replacementRange))
    }

    private func openCreate(_ form: MenuFormKind) {
        kind = .create(form)
        query = ""
        selectedID = nil
        formPrimary = form == .task ? "Task" : ""
        formCompleted = false
        items = []
    }

    private func commitForm(_ form: MenuFormKind) -> (AnyHashable, NSRange?)? {
        let value = formPrimary.trimmingCharacters(in: .whitespacesAndNewlines)
        let block: Sheet.Block

        switch form {
            case .task:
                if case .update = kind, let target, case .task(let id, _, _) = sheet.block(id: target) {
                    block = .task(id, value.isEmpty ? "Task" : value, formCompleted)
                } else {
                    block = .task(UUID(), value.isEmpty ? "Task" : value, formCompleted)
                }
            case .link:
                guard let url = normalizedURL(from: value) else { return nil }
                block = .artifact(Artifact.register(url.host(percentEncoded: false) ?? url.absoluteString, url))
            case .artifact, .command, .sheet:
                return nil
        }

        if case .update = kind {
            guard let target, let id = sheet.update(block, replacing: target) else { return nil }
            close()
            return (id, nil)
        }

        guard let target else { return nil }
        return apply(MenuInsertion(blocks: [block], target: target, replacementRange: replacementRange))
    }

    private func apply(_ insertion: MenuInsertion) -> (AnyHashable, NSRange?)? {
        let result = sheet.insert(insertion.blocks, replacing: insertion.replacementRange, in: insertion.target)
        if result != nil { close() }
        return result
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

    private func normalizedURL(from value: String) -> URL? {
        guard !value.isEmpty else { return nil }
        if let url = URL(string: value), url.scheme != nil { return url }
        return URL(string: "https://\(value)")
    }
}
