import SwiftUI


@Observable final class ContentPanel: Panel {
    var mode: Modality = .fixed
    var state: PanelState = .init(presented: true, position: 340)
    var surface: PanelSurface = .materials
    var detail: PanelDetail = .detail

    enum PanelSurface: String, CaseIterable, Identifiable, Hashable {
        case materials, charts

        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var symbol: String {
            switch self {
                case .materials: "square.and.pencil"
                case .charts: "flowchart"
            }
        }
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
            switch self.surface {
                case .materials: MaterialsSurface(panel: self, model: model)
                case .charts: ChartsSurface(panel: self, model: model)
            }
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
                        .frame(width: 440)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .toolbar {
            ToolbarItem(placement: .navigation) { NavigationButtons(model: model) }
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarItem(placement: .principal) { ContentPicker(panel: self) }
            ToolbarSpacer(.flexible, placement: .primaryAction)
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
