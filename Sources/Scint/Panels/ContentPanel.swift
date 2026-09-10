import SwiftUI


@Observable final class ContentPanel: Panel {
    var mode: Modality = .fixed
    var state: PanelState = .init(presented: true, position: 340)
    var surface: PanelSurface = .project
    var detail: PanelDetail = .space

    enum PanelSurface: String, CaseIterable, Identifiable, Hashable {
        case project, material

        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var symbol: String { "square.and.pencil" }
    }

    enum PanelDetail: String, CaseIterable, Identifiable, Hashable {
        case space, transcript, tasks

        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var symbol: String {
            switch self {
                case .tasks: "checkmark.app"
                case .space: "square.fill.text.grid.1x2"
                case .transcript: "ellipsis.bubble"
            }
        }
    }

    func surface(_ model: any Model) -> some View {
        HSplit(bindable.presented, bindable.position) {
            VStack {
                switch model.session.opened.material {
                    case .none: MaterialsSurface(panel: self, model: model, state: state)
                    case .some(let ref): MaterialSurface(panel: self, model: model, ref: ref)
                }
            }
        } trailing: { handle in
            VStack {
                switch self.detail {
                    case .space: SpaceSurface(panel: self, model: model)
                    case .tasks: TasksSurface(panel: self, model: model)
                    case .transcript: TranscriptSurface(panel: self, model: model)
                }
            }
            .frame(width: self.state.position)
            .overlay {
                HStack {
                    handle
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .toolbar {
            ToolbarItem(placement: .navigation) { NavigationButtons(model: model) }
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarSpacer(.fixed, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) { DetailPicker(panel: self) }
        }
    }
}
