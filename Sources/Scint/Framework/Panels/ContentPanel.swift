import SwiftUI


@Observable final class ContentPanel: Panel {
    var mode: Modality = .fixed
    var state: PanelState = .init(presented: true, position: 340)
    var surface: PanelSurface = .edit
    var detail: PanelDetail = .space

    enum PanelSurface: String, CaseIterable, Identifiable, Hashable {
        case edit, compose

        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var symbol: String {
            switch self {
                case .edit: "square.and.pencil"
                case .compose: "ellipsis.bubble"
            }
        }
    }

    enum PanelDetail: String, CaseIterable, Identifiable, Hashable {
        case space, tasks
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var symbol: String {
            switch self {
                case .space: "square.fill.text.grid.1x2"
                case .tasks: "checkmark.app"
            }
        }
    }

    func surface(_ model: any Model) -> some View {
        HSplit(state.bindable.presented, state.bindable.position) {
            switch self.surface {
                case .edit: EditSurface(panel: self, model: model)
                case .compose: ComposeSurface(panel: self, model: model)
            }
        } trailing: { handle in
            ScrollView {
                DetailSurface(panel: self, model: model)
                TasksSurface(panel: self, model: model)
            }
            .frame(width: 340)
            .scrollEdgeEffectHidden()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .toolbar {
            ToolbarItem(placement: .navigation) { NavigationButtons(model: model) }
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) { ComposeToggle(panel: self) }
            ToolbarItem(placement: .primaryAction) { DetailPicker(panel: self) }
        }
        .safeAreaInset(edge: .top) {
            ZStack(alignment: .bottom) {
                HStack(alignment: .center) {
                    PathBar(model: model)
                    Spacer()
                    BadgeBar(model: model)
                }
                .frame(maxHeight: 33.5)
                .padding(.horizontal, 8)
            }
        }
    }
}
