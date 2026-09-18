import Foundation


/// Stable operation identifiers retained for activity presentation.
///
/// This type does not define MCP schemas, execute runtime behavior, or authorize requests.
enum Op: Sendable {
    case space(SpaceAction)
    case material(MaterialAction)
    case interface(InterfaceAction)
    case library(LibraryAction)

    enum SpaceAction: String, CaseIterable, Sendable { case read, create, add, start, stop }
    enum MaterialAction: String, CaseIterable, Sendable { case create, read, append }
    enum InterfaceAction: String, CaseIterable, Sendable { case describe, run }
    enum LibraryAction: String, CaseIterable, Sendable { case search }

    static let all: [Op] =
        SpaceAction.allCases.map(Op.space)
        + MaterialAction.allCases.map(Op.material)
        + InterfaceAction.allCases.map(Op.interface)
        + LibraryAction.allCases.map(Op.library)

    var group: String {
        switch self {
            case .space: "space"
            case .material: "material"
            case .interface: "interface"
            case .library: "library"
        }
    }

    var action: String {
        switch self {
            case .space(let action): action.rawValue
            case .material(let action): action.rawValue
            case .interface(let action): action.rawValue
            case .library(let action): action.rawValue
        }
    }

    var name: String { "\(group).\(action)" }

    static func named(_ recorded: String) -> Op? {
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
            case .material(.create): "doc.badge.plus"
            case .material(.read): "book"
            case .material(.append): "pencil"
            case .interface(.describe): "info.circle"
            case .interface(.run): "switch.2"
            case .library(.search): "magnifyingglass"
        }
    }
}
