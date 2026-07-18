import SwiftUI

enum InspectorModel: String, CaseIterable {
    case space, sheet

    var label: String {
        switch self {
            case .space: "Space Inspector"
            case .sheet: "Sheet Inspector"
        }
    }

    var image: String {
        switch self {
            case .space: "app"
            case .sheet: "text.alignleft"
        }
    }

    @MainActor var icon: Iconography.Icon {
        switch self {
            case .space: Iconography.model(.space)
            case .sheet: Iconography.model(.sheet(.sheet))
        }
    }
}

@Observable final class Inspector: Panel {
    var model: InspectorModel = .space
    var state: StateContainer = .init()

    func controls(_ agency: AgencyModel) -> Controls { InspectorMap.controls(agency) }
    func parameters(_ agency: AgencyModel) -> Params { InspectorMap.parameters(agency) }

    func surface(_ agency: AgencyModel) -> some View {
        @Bindable var state = self.state
        let surface = AnySurface(panel: self)

        return surface.view(surface, parameters(agency), controls(agency))
            .environment(agency)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .safeAreaBar(edge: .top) { InspectorTabs() }
            .toolbar {
                ToolbarSpacer(.flexible, placement: .primaryAction)
                ToolbarItem(placement: .primaryAction) { InspectorToggle(presented: $state.presented) }
            }
    }
}
