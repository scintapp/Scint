import Foundation
import SwiftUI


@Observable final class AssistantPanel: Panel {
    var mode: Modality = .fixed
    var state: PanelState = .init()
    var surface: PanelSurface = .composer

    enum PanelSurface: String, CaseIterable, Identifiable {
        case composer, editor, spaces, tasks

        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var symbol: String {
            switch self {
                case .tasks: "checkmark.app"
                case .spaces: "rectangle.stack"
                case .editor: "square.and.pencil"
                case .composer: "ellipsis.bubble"
            }
        }
    }

    func controls(_ model: any Model) -> Controls {
        SpaceInspector.controls(model)
    }

    func parameters(_ model: any Model) -> Params {
        SpaceInspector.parameters(model)
    }

    func surface(_ model: any Model) -> some View {
        Group {
            let structure = model.session.selected.structure
            switch surface {
                case .spaces:
                    DetailSurface(panel: self, model: model)
                case .editor:
                    switch structure {
                        case .none: DetailSurface(panel: self, model: model)
                        case .some(let ref): MaterialSurface(panel: self, model: model, ref: ref)
                    }
                case .composer:
                    ComposeSurface(panel: self, model: model)
                case .tasks:
                    TasksSurface(panel: self, model: model)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .toolbar {
            ToolbarItem(placement: .navigation) { NewSpaceButton(model: model) }
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarItem(placement: .principal) { AssistantPicker(panel: self) }
            ToolbarSpacer(.fixed, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) { HarnessPicker(panel: self, model: model) }
        }
        .safeAreaInset(edge: .top) {
            HStack(alignment: .center) {
                PathBar(model: model)
                Spacer()
                BadgeBar(model: model)
            }
            .padding(.horizontal, 8)
        }
    }
}
