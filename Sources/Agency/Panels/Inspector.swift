import AgencyRuntime
import SwiftUI


@Observable final class Inspector: Panel {
    var model: Model = .settings
    var presented: Bool = false
    var position: CGFloat = 280
    var state = SurfaceState()

    enum Model: String, CaseIterable {
        case outline, settings

        var label: String {
            switch self {
                case .outline: "Outline"
                case .settings: "Settings"
            }
        }

        var image: String {
            switch self {
                case .outline: "text.alignleft"
                case .settings: "app"
            }
        }

        @MainActor var icon: Iconography.Icon {
            switch self {
                case .outline: Iconography.model(.sheet(.sheet))
                case .settings: Iconography.model(.space)
            }
        }
    }

    func controls(_ agency: AgencyModel) -> Controls {
        switch model {
            case .outline: SheetOutlineMap.controls(agency)
            case .settings: SpaceSettingsMap.controls(agency)
        }
    }

    func parameters(_ agency: AgencyModel) -> Params {
        switch model {
            case .outline: SheetOutlineMap.parameters(agency)
            case .settings: SpaceSettingsMap.parameters(agency)
        }
    }

    func toolbar() -> some ToolbarContent {
        Group {
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) { InspectorToggle() }
        }
    }

    func view(_ agency: AgencyModel) -> some View {
        VStack(alignment: .leading) {
            Builder.build(self, parameters(agency), controls(agency))
                .scrollEdgeEffectStyle(.soft, for: .top)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .toolbar(removing: .sidebarToggle)
        .toolbar { toolbar() }
        .safeAreaBar(edge: .top) { InspectorTabs() }
    }
}
