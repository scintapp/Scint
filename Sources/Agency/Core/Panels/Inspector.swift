import AgencyRuntime
import SwiftUI


@Observable final class Inspector: Panel {
    var model: Model = .settings
    var layout: Layout = .group
    var presented: Bool = true
    var expanded: Set<AnyHashable> = []
    var position: CGFloat = 280
    var state: Set<AnyHashable> = []

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

        @MainActor
        var icon: Iconography.Icon {
            switch self {
                case .outline: Iconography.model(.sheet(.sheet))
                case .settings: Iconography.model(.space)
            }
        }
    }

    func controls(_ agency: AgencyModel) -> Controls {
        switch model {
            case .outline: SheetOutlineMap.controls(agency, self)
            case .settings: SpaceSettingsMap.controls(agency, self)
        }
    }

    func parameters(_ agency: AgencyModel) -> PanelParams {
        switch model {
            case .outline: SheetOutlineMap.parameters(agency, self)
            case .settings: SpaceSettingsMap.parameters(agency, self)
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
            InspectorTabs()
                .frame(alignment: .top)
            Builder.build(agency, self)
                .scrollEdgeEffectStyle(.hard, for: .top)
                .padding(.top, -8)
        }
        .frame(maxHeight: .infinity)
        .toolbar(removing: .sidebarToggle)
        .toolbar { toolbar() }
    }
}
