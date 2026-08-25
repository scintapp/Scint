import SwiftUI


@Observable final class ContentPanel: Panel {
    var state: PanelState = .init(presented: true, position: 480)
    var surface: ContentSurface = .detail

    enum ContentSurface: String, CaseIterable, Identifiable {
        case detail, editor

        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var symbol: String {
            switch self {
                case .detail: "square.fill.text.grid.1x2"
                case .editor: "square.and.pencil"
            }
        }
    }

    func controls(_ model: any Model) -> Controls {
        switch surface {
            case .detail: SpaceGrid.controls(model)
            case .editor: SpaceGrid.controls(model)
        }
    }

    func parameters(_ model: any Model) -> Params {
        switch surface {
            case .detail: SpaceGrid.parameters(model)
            case .editor: SpaceGrid.parameters(model)
        }
    }

    func surface(_ model: any Model) -> some View {
        ComposeSurface(panel: self, model: model)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .safeAreaBar(edge: .top) {
                HStack(alignment: .center) {
                    PathBar(model: model)
                    Spacer()
                    BadgesBar(model: model)
                }
                .frame(maxHeight: 30)
                .padding(.horizontal, 8)
            }
            .toolbar {
                ToolbarItem(placement: .navigation) { NavigationButtons(model: model) }
                ToolbarItem(placement: .principal) { ActivityBar() }
                ToolbarSpacer(.flexible, placement: .primaryAction)
                ToolbarItem(placement: .primaryAction) { SplitPicker() }
            }
    }
}
