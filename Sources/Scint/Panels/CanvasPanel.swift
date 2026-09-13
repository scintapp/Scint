import Foundation
import SwiftUI


@Observable final class CanvasPanel: Panel {
    var mode: Modality = .fixed
    var state: PanelState = .init()
    var surface: PanelSurface = .space
    var axis: CanvasAxis = .vertical

    enum PanelSurface: String, CaseIterable, Identifiable {
        case space, tasks, transcript

        static let viewModes: [Self] = [.tasks, .transcript]

        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var symbol: String {
            switch self {
                case .space: "rectangle.stack"
                case .tasks: "checkmark.app"
                case .transcript: "ellipsis.bubble"
            }
        }
    }

    func surface(_ model: any Model) -> some View {
        ZStack(alignment: .top) {
            CanvasLayout(
                ref: model.session.space,
                axis: Bindable(self).axis,
                onBackground: { model.focus(nil) }
            ) { ref in
                SpaceSurface(ref: ref, panel: self, model: model)
                    .frame(width: 340)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Style.Background.base)
        .safeAreaInset(edge: .bottom) {
            ComposeBar(model: model) {}
                .padding(8)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) { NavigationButtons(model: model) }
            ToolbarItem(placement: .principal) { PathPicker(panel: self, model: model) }
        }
    }
}
