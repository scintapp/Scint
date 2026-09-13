import SwiftUI


@Observable final class SettingsPanel: Panel {
    var mode: Modality = .fixed
    var state: PanelState = .init()
    var surface: PanelSurface = .harness

    enum PanelSurface: String, CaseIterable, Identifiable {
        case harness
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var image: String { "rectangle.on.rectangle.badge.gearshape" }
    }

    func controls(_ model: any Model) -> Controls {
        SpaceSettings.controls(model)
    }

    func parameters(_ model: any Model) -> Params {
        SpaceSettings.parameters(model)
    }

    func surface(_ model: any Model) -> some View {
        AnySurface(panel: self, model: model)
            .toolbar {
                ToolbarSpacer(.flexible, placement: .primaryAction)
                ToolbarItem(placement: .primaryAction) { InspectorToggle(presented: bindable.presented) }
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
    }
}
