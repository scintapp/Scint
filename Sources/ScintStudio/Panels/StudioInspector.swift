import SwiftUI


@Observable final class StudioInspector: Panel {
    var surface: InspectorSurface = .context
    var state: StateContainer = .init()

    enum InspectorSurface: String, CaseIterable {
        case context, settings

        var label: String {
            switch self {
                case .context: "Context"
                case .settings: "Settings"
            }
        }

        var image: String {
            switch self {
                case .context: "ellipses.bubble"
                case .settings: "gear"
            }
        }

        @MainActor var icon: Iconography.Icon {
            switch self {
                case .context: Iconography.model(.space)
                case .settings: Iconography.model(.sheet(.sheet))
            }
        }
    }

    func panel(_ model: any Model) -> some View {
        Group {
            switch self.surface {
                case .context: SpaceTranscripts(panel: self, model: model)
                case .settings: SpaceSettings(panel: self, model: model)
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .safeAreaBar(edge: .top) { InspectorTabs(inspector: self) }
        .toolbar {
            @Bindable var state = self.state
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) { InspectorToggle(presented: $state.presented) }
        }
    }
}
