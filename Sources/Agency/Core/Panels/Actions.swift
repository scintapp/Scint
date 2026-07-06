import AppKit
import Observation
import SwiftUI
import OrderedCollections
import AgencyRuntime


@Observable @MainActor final class Actions: Panel {
    @ObservationIgnored var query = ""
    var state: Set<AnyHashable> = []
    var queryRevision = 0
    var model: Model = .commands
    var layout: Layout = .list
    var position: CGFloat = 0
    var presented: Bool = true
    var index: Int = 0

    enum Model: String, CaseIterable, Identifiable {
        case commands, interfaces, library, workspace

        var id: String { rawValue }
        var placeholder: String { label }

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

    func parameters(_ agency: AgencyModel) -> PanelParams {
        switch model {
            case .commands: SearchMap.parameters(agency, self)
            case .interfaces: InterfacesMap.parameters(agency, self)
            case .library: ComponentsMap.parameters(agency, self)
            case .workspace: StructuresMap.parameters(agency, self)
        }
    }

    func setQuery(_ value: String) {
        guard query != value else { return }
        query = value
        queryRevision += 1
        index = 0
    }

    func reset() {
        query = ""
        queryRevision += 1
        index = 0
    }

    func cycleModel() {
        let modes = Model.allCases
        guard let current = modes.firstIndex(of: model) else { return }
        model = modes[(current + 1) % modes.count]
    }

    func view(_ agency: AgencyModel) -> some View {
        ActionsPanelView(actions: self, agency: agency)
    }
}
