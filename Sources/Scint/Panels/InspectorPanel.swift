import SwiftUI


@Observable final class InspectorPanel: Panel {
    var mode: Modality = .fixed
    var state: PanelState = .init()
    var surface: PanelSurface = .artifacts

    enum PanelSurface: String, CaseIterable, Identifiable {
        case artifacts, commands, harness

        var id: String { rawValue }
        var label: String { rawValue.capitalized }

        var image: String {
            switch self {
                case .artifacts: "text.rectangle"
                case .commands: "rectangle.on.rectangle.badge.gearshape"
                case .harness: "rectangle.on.rectangle.badge.gearshape"
            }
        }
    }

    func controls(_ model: any Model) -> Controls {
        switch surface {
            case .artifacts: ArtifactsGroup.controls(model)
            case .commands: CommandsGroup.controls(model)
            case .harness: HarnessGroup.controls(model)
        }
    }

    func parameters(_ model: any Model) -> Params {
        switch surface {
            case .artifacts: ArtifactsGroup.parameters(model)
            case .commands: CommandsGroup.parameters(model)
            case .harness: HarnessGroup.parameters(model)
        }
    }

    func surface(_ model: any Model) -> some View {
        AnySurface(panel: self, model: model)
            .scrollEdgeEffectHidden()
            .toolbar {
                @Bindable var state = self.state
                ToolbarSpacer(.flexible, placement: .primaryAction)
                ToolbarItem(placement: .primaryAction) { InspectorToggle(presented: $state.presented) }
            }
    }
}

