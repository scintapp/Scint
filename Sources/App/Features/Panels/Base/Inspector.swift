import AgencyRuntime
import SwiftUI


@Observable final class Inspector: Panel {
    var model: Model = .settings
    var layout: Layout = .list
    var presented: Bool = false
    var position: CGFloat = 0
    var expanded: Set<AnyHashable> = []

    enum Model: String, CaseIterable {
        case settings, preview

        var label: String {
            switch self {
                case .settings: "Settings"
                case .preview: "Preview"
            }
        }

        var image: String {
            switch self {
                case .settings: "gearshape.2"
                case .preview: "eyeglasses"
            }
        }
    }

    func controls(_ agency: AgencyModel) -> Controls {
        switch model {
            case .settings: return SettingsMap.controls(agency, self)
            case .preview: return PreviewMap.controls(agency, self)
        }
    }

    func parameters(_ agency: AgencyModel) -> Parameters {
        switch model {
            case .settings: return SettingsMap.parameters(agency, self)
            case .preview: return PreviewMap.parameters(agency, self)
        }
    }

    func toolbar() -> some ToolbarContent {
        return Group {
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarItemGroup(placement: .primaryAction) { InspectorToggle() }
        }
    }

    func view(_ agency: AgencyModel) -> some View {
        VStack {
            InspectorTabs()
            Builder.build(agency, self)
        }
        .environment(agency)
        .scrollEdgeEffectStyle(.hard, for: .top)
        .toolbar(removing: .sidebarToggle)
        .toolbar { toolbar() }
    }
}
