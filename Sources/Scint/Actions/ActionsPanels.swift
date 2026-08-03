import SwiftUI


@Observable final class Actions: Panel {
    var query = ""
    var state: StateContainer = .init()
    var surface: ActionsSurface = .everything

    enum ActionsSurface: String, CaseIterable, Identifiable {
        case everything, content, interfaces, workspace

        var id: String { rawValue }
        var placeholder: String { label }

        var label: String {
            switch self {
                case .everything: "Everything"
                case .content: "Content"
                case .interfaces: "Interfaces"
                case .workspace: "Workspace"
            }
        }

        var image: String {
            switch self {
                case .everything: "magnifyingglass"
                case .content: "command"
                case .interfaces: "switch.2"
                case .workspace: "cube.transparent"
            }
        }
    }

    func panel(_ model: any Model) -> some View { AnySurface(panel: self, model: model) }
}
