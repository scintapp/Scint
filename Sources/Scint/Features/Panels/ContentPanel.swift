import SwiftUI


@Observable final class ContentPanel: Panel {
    var mode: Modality = .fixed
    var state: PanelState = .init(presented: true, position: 340)
    var surface: PanelSurface = .list
    var detail: PanelDetail = .detail

    enum PanelSurface: String, CaseIterable, Identifiable, Hashable {
        case singe, list

        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var symbol: String { "square.and.pencil" }
    }

    enum PanelDetail: String, CaseIterable, Identifiable, Hashable {
        case tasks, detail, compose
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var symbol: String {
            switch self {
                case .tasks: "checkmark.app"
                case .detail: "square.fill.text.grid.1x2"
                case .compose: "ellipsis.bubble"
            }
        }
    }

    func surface(_ model: any Model) -> some View {
        HSplit(state.bindable.presented, state.bindable.position) {
            MaterialsSurface(panel: self, model: model)
                .scrollEdgeEffectStyle(.soft, for: .top)
        } trailing: { handle in
            switch self.detail {
                case .detail:
                    DetailSurface(panel: self, model: model)
                        .frame(width: 340)
                case .tasks:
                    TasksSurface(panel: self, model: model)
                        .frame(width: 340)
                case .compose:
                    ComposeSurface(panel: self, model: model)
                        .frame(width: 560)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .toolbar {
            ToolbarItem(placement: .navigation) { NavigationButtons(model: model) } 
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarSpacer(.fixed, placement: .primaryAction)
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
        .scrollEdgeEffectStyle(.soft, for: .top)
    }
}
