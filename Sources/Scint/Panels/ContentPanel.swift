import SwiftUI


@Observable final class ContentPanel: Panel {
    var state: PanelState = .init(presented: true, position: 340)
    var surface: PanelSurface = .detail

    enum PanelSurface: String, CaseIterable, Identifiable, Hashable {
        case detail, tasks, editor

        var id: String { rawValue }
        var label: String { rawValue.capitalized }

        var symbol: String {
            switch self {
                case .detail: "square.fill.text.grid.1x2"
                case .tasks: "checkmark.app"
                case .editor: "square.and.pencil"
            }
        }
    }

    func surface(_ model: any Model) -> some View {
        HSplit(state.bindable.presented, state.bindable.position) {
            ComposeSurface(panel: self, model: model)
        } trailing: { handle in
            switch self.surface {
                case .detail:
                    DetailSurface(panel: self, model: model)
                        .frame(width: 340)
                case .tasks:
                    TasksSurface(panel: self, model: model)
                        .frame(width: 340)
                case .editor:
                    EditSurface(panel: self, model: model)
                        .frame(width: self.state.position)
                        .overlay(alignment: .leading) { handle }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .safeAreaBar(edge: .top) {
            ZStack(alignment: .bottom) {
                HStack(alignment: .center) {
                    PathBar(model: model)
                    Spacer()
                    switch surface {
                        case .detail: BadgeBar(model: model)
                        case .tasks: BadgeBar(model: model)
                        case .editor: EditorBar(model: model)
                    }
                }
                .frame(maxHeight: 30)
                .padding(.horizontal, 8)

                Rectangle()
                    .fill(Style.Border.base)
                    .frame(height: 0.5)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) { NavigationButtons(model: model) }
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) { ContentPicker(panel: self) }
        }
    }
}
