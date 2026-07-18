import SwiftUI


enum ActionsModel: String, CaseIterable, Identifiable {
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

@Observable final class Actions: Panel {
    var model: ActionsModel = .everything
    var state: StateContainer = .init()
    var query = ""

    func controls(_ agency: AgencyModel) -> Controls { ActionsMaps.controls(agency) }
    func parameters(_ agency: AgencyModel) -> Params { ActionsMaps.parameters(agency) }

    func surface(_ agency: AgencyModel) -> some View {
        ZStack {
            @Bindable var state = self.state

            VStack {
                EmptyView()
            }
            .environment(agency)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}
