import AppKit
import Foundation


enum MenuFocus: Hashable { case filter, formPrimary }

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

    static func command(id: String, label: String, icon: String? = nil,
                        keywords: [String] = [], opens: MenuFormKind? = nil) -> MenuItem {

        .commandItem(id: id, label: label, icon: icon, keywords: keywords, opens: opens)
    }

    static func divider(_ id: String) -> MenuItem { .dividerItem(id) }
}

struct MenuFormValues: Equatable {
    var primary: String
    var completed: Bool

    static let empty = MenuFormValues(primary: "", completed: false)
}

struct MenuOutcome {
    enum Choice {
        case item(MenuItem)
        case form(MenuFormKind, MenuFormValues)
    }

    let choice: Choice
    let kind: MenuKind
    let isInserting: Bool
    let target: AnyHashable
    let replacementRange: NSRange
}
