import SwiftUI


@Observable final class NavigatorPanel: Panel {
    var mode: Modality = .fixed
    var state: PanelState = .init(presented: true)
    var surface: PanelSurface = .execute

    enum PanelSurface: String, CaseIterable {
        case compose, execute
        var label: String { rawValue.capitalized }

        var image: String {
            switch self {
                case .compose: ""
                case .execute: ""
            }
        }
    }

    func controls(_ model: any Model) -> Controls {
        switch surface {
            case .compose: NavigatorQuery.controls(model)
            case .execute: FlatSpacesList.controls(model)
        }
    }

    func parameters(_ model: any Model) -> Params {
        switch surface {
            case .compose: NavigatorQuery.parameters(model)
            case .execute: FlatSpacesList.parameters(model)
        }
    }

    func surface(_ model: any Model) -> some View {
        AnySurface(panel: self, model: model)
            .toolbar(removing: .sidebarToggle)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .toolbar {
                ToolbarItem(placement: .automatic) { NavigatorToggle(presented: bindable.presented) }
                ToolbarSpacer(.flexible, placement: .automatic)
            }
    }
}
