import SwiftUI


@Observable final class InspectorPanel: Panel {
    var state: PanelState = .init()
    var surface: InspectorSurface = .context

    enum InspectorSurface: String, CaseIterable, Identifiable {
        case context, settings, transcripts

        var id: String { rawValue }
        var label: String { rawValue.capitalized }

        var image: String {
            switch self {
                case .context: "text.rectangle"
                case .settings: "rectangle.on.rectangle.badge.gearshape"
                case .transcripts: "rectangle.and.text.magnifyingglass"
            }
        }
    }

    func controls(_ model: any Model) -> Controls {
        switch surface {
            case .context: FoldersGroup.controls(model)
            case .settings: SpaceGroup.controls(model)
            case .transcripts: TranscriptsList.controls(model)
        }
    }

    func parameters(_ model: any Model) -> Params {
        switch surface {
            case .context: FoldersGroup.parameters(model)
            case .settings: SpaceGroup.parameters(model)
            case .transcripts: TranscriptsList.parameters(model)
        }
    }

    func surface(_ model: any Model) -> some View {
        Group {
            switch surface {
                case .context: AnySurface(panel: self, model: model)
                case .settings: AnySurface(panel: self, model: model)
                case .transcripts: AnySurface(panel: self, model: model)
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .safeAreaBar(edge: .top) { InspectorTabs(panel: self) }
        .toolbar {
            @Bindable var state = self.state
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) { InspectorToggle(presented: $state.presented) }
        }
    }
}

