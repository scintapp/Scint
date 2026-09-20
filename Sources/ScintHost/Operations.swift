import Foundation


enum Operation: Sendable {
    case space(SpaceAction)
    case document(DocumentAction)
    case interface(InterfaceAction)
    case library(LibraryAction)

    enum SpaceAction: String, CaseIterable, Sendable { case read, create, add, start, stop }
    enum DocumentAction: String, CaseIterable, Sendable { case create, read, append }
    enum InterfaceAction: String, CaseIterable, Sendable { case describe, run }
    enum LibraryAction: String, CaseIterable, Sendable { case search }

    static let all: [Operation] =
        SpaceAction.allCases.map(Operation.space)
        + DocumentAction.allCases.map(Operation.document)
        + InterfaceAction.allCases.map(Operation.interface)
        + LibraryAction.allCases.map(Operation.library)

    var group: String {
        switch self {
            case .space: "space"
            case .document: "document"
            case .interface: "interface"
            case .library: "library"
        }
    }

    var action: String {
        switch self {
            case .space(let action): action.rawValue
            case .document(let action): action.rawValue
            case .interface(let action): action.rawValue
            case .library(let action): action.rawValue
        }
    }

    var name: String { "\(group).\(action)" }

    static func named(_ recorded: String) -> Operation? {
        let canonical = (recorded.components(separatedBy: "__").last ?? recorded)
            .replacingOccurrences(of: "_", with: ".")
        return all.first { $0.name == canonical }
    }

    var sentence: String {
        let verb = switch action {
            case "read": "Read"
            case "create": "Created"
            case "add": "Added to"
            case "append": "Appended to"
            case "start": "Started"
            case "stop": "Stopped"
            case "describe": "Described"
            case "run": "Ran"
            case "search": "Searched"
            default: "Used"
        }
        return "\(verb) \(group)"
    }

    var symbol: String {
        switch self {
            case .space(.read): "square.stack"
            case .space(.create): "plus.square"
            case .space(.add): "tray.and.arrow.down"
            case .space(.start): "play"
            case .space(.stop): "stop"
            case .document(.create): "doc.badge.plus"
            case .document(.read): "book"
            case .document(.append): "pencil"
            case .interface(.describe): "info.circle"
            case .interface(.run): "switch.2"
            case .library(.search): "magnifyingglass"
        }
    }
}
