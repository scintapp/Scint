import SwiftUI


@Observable final class ContentPanel: Panel {
    var state: PanelState = .init(presented: true, position: 300)
    var surface: ContentSurface = .detail

    enum ContentSurface: String, CaseIterable, Identifiable, Hashable {
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
                        .frame(width: 300)
                case .tasks:
                    TasksSurface(panel: self, model: model)
                        .frame(width: 300)
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
                    BadgeBar(model: model)
                }
                .frame(maxHeight: 30)
                .padding(.horizontal, 8)

                Rectangle()
                    .fill(Style.Border.card)
                    .frame(height: 0.5)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) { NavigationButtons(model: model) }
            ToolbarItem(placement: .principal) { ActivityBar() }
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) { ContentPicker(panel: self) }
        }
    }
}
