import AgencyRuntime
import SwiftUI


@Observable final class Actions: Panel {
    var model: Model = .commands
    var layout: Layout = .list
    var position: CGFloat = 0
    var presented: Bool = true
    var expanded: Set<AnyHashable> = []
    var index: Int = 0
    var query: String = ""
    var prompt: ControlPrompt?

    struct ControlPrompt: Hashable {
        let ref: Reference
        var arguments: String = ""
    }

    enum Model: String, CaseIterable, Identifiable {
        case commands, interfaces, library, workspace

        var id: String { rawValue }
        var placeholder: String { "\(label)" }

        var label: String {
            switch self {
            case .commands: "Commands"
            case .interfaces: "Interfaces"
            case .library: "Library"
            case .workspace: "Workspace"
            }
        }

        var image: String {
            switch self {
            case .commands: "command"
            case .interfaces: "switch.2"
            case .library: "building.columns"
            case .workspace: "cube.transparent"
            }
        }
    }

    func controls(_ agency: AgencyModel) -> Controls {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                return agency.session.selected.selected(ref, item.path)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.select(ref)
            }
        )
    }

    func parameters(_ agency: AgencyModel) -> Parameters { .init() }

    func reset() {
        query = ""
        index = 0
    }
}
