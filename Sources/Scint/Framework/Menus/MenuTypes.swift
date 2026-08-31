import AppKit
import Foundation


enum MenuFocus: Hashable { case filter, formPrimary }

/// What a completed form carries back to the host.
struct MenuFormValues: Equatable {
    var primary: String
    var completed: Bool

    static let empty = MenuFormValues(primary: "", completed: false)
}

/// What the host is asked to do once the reader picks something.
///
/// The menu produces one of these and stops. It does not know what a result becomes — a block, a
/// row, a chip — so nothing about `Material` reaches this layer.
struct MenuOutcome {
    enum Choice {
        case item(MenuItem)
        case form(MenuFormKind, MenuFormValues)
    }

    let choice: Choice
    /// Which menu produced this. Hosts that treat a `/` command differently from an `@` reference
    /// read it here rather than guessing from the choice.
    let kind: MenuKind
    /// True when the host should insert at `replacementRange`; false when it should replace `target`.
    let isInserting: Bool
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
    case material

    var name: String {
        switch self {
            case .task: return "Task"
            case .link: return "Link"
            case .artifact: return "Artifact"
            case .command: return "Command"
            case .material: return "Material"
        }
    }

    var icon: String {
        switch self {
            case .task: return "checkmark.circle"
            case .link: return "link"
            case .artifact: return "folder.badge.plus"
            case .command: return "curlybraces"
            case .material: return "textformat"
        }
    }

    func title(updating: Bool) -> String { "\(updating ? "Edit" : "New") \(name)" }

    var primaryPlaceholder: String {
        switch self {
            case .task: return "Task"
            case .link: return "URL"
            case .artifact, .command, .material: return "Search \(name.lowercased())s"
        }
    }
}

enum MenuItem: Identifiable, Equatable {
    case commandItem(id: String, label: String, icon: String?, keywords: [String], opens: MenuFormKind?)
    case reference(Reference, name: String, description: String, tags: [String])
    case dividerItem(String)

    var id: String {
        switch self {
            case .commandItem(let id, _, _, _, _): return "command:\(id)"
            case .reference(let ref, _, _, _): return "reference:\(ref.id.uuidString)"
            case .dividerItem(let id): return "divider:\(id)"
        }
    }

    var commandID: String? {
        guard case .commandItem(let id, _, _, _, _) = self else { return nil }
        return id
    }

    var label: String {
        switch self {
            case .commandItem(_, let label, _, _, _): return label
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

    /// The form this item raises when chosen, if any.
    var opens: MenuFormKind? {
        guard case .commandItem(_, _, _, _, let opens) = self else { return nil }
        return opens
    }

    var ref: Reference? {
        guard case .reference(let ref, _, _, _) = self else { return nil }
        return ref
    }

    var icon: String? {
        guard case .commandItem(_, _, let icon, _, _) = self else { return nil }
        return icon
    }

    var isSelectable: Bool {
        if case .dividerItem = self { return false }
        return true
    }

    func matches(_ query: String) -> Bool {
        guard !query.isEmpty else { return true }
        switch self {
            case .commandItem(_, let label, _, let keywords, _):
                return label.localizedCaseInsensitiveContains(query)
                    || keywords.contains { $0.localizedCaseInsensitiveContains(query) }
            case .reference(_, let name, let description, let tags):
                return name.localizedCaseInsensitiveContains(query)
                    || description.localizedCaseInsensitiveContains(query)
                    || tags.contains { $0.localizedCaseInsensitiveContains(query) }
            case .dividerItem: return false
        }
    }

    /// `opens` makes an item that raises a form instead of resolving to a result. The controller
    /// reads it off the item rather than recognising particular command ids.
    static func command(
        id: String,
        label: String,
        icon: String? = nil,
        keywords: [String] = [],
        opens: MenuFormKind? = nil
    ) -> MenuItem {
        .commandItem(id: id, label: label, icon: icon, keywords: keywords, opens: opens)
    }

    static func divider(_ id: String) -> MenuItem { .dividerItem(id) }
}
