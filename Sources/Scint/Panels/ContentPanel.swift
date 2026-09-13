import SwiftUI


@Observable final class ContentPanel: Panel {
    var mode: Modality = .fixed
    var state: PanelState = .init(presented: true, position: 340)
    var surface: PanelSurface = .project
    var detail: PanelDetail = .tasks

    enum PanelSurface: String, CaseIterable, Identifiable, Hashable {
        case project, material

        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var symbol: String { "square.and.pencil" }
    }

    enum PanelDetail: String, CaseIterable, Identifiable, Hashable {
        case transcript, tasks

        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var symbol: String {
            switch self {
                case .tasks: "checkmark.app"
                case .transcript: "ellipsis.bubble"
            }
        }
    }

    func surface(_ model: any Model) -> some View {
        HSplit(bindable.presented, bindable.position) {
            switch self.surface {
                case .material: MaterialsSurface(panel: self, model: model, state: state)
                case .project: SpaceSurface(ref: model.session.origin, panel: self, model: model)
            }
        } trailing: { handle in
            switch self.detail {
                case .tasks: TasksSurface(panel: self, model: model)
                case .transcript: TranscriptSurface(panel: self, model: model)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .toolbar {
            ToolbarItem(placement: .navigation) { NavigationButtons(model: model) }
        }
    }
}
