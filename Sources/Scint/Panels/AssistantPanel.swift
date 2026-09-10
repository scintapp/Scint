import Foundation
import SwiftUI


@Observable final class AssistantPanel: Panel {
    var mode: Modality = .fixed
    var state: PanelState = .init()
    var surface: PanelSurface = .space

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

    func controls(_ model: any Model) -> Controls { SpaceSettings.controls(model) }
    func parameters(_ model: any Model) -> Params { SpaceSettings.parameters(model) }

    func surface(_ model: any Model) -> some View {
        Group {
            switch surface {
                case .space:
                    switch model.session.opened.material {
                        case .none: SpaceSurface(panel: self, model: model)
                        case .some(let ref): MaterialSurface(panel: self, model: model, ref: ref)
                    }
                case .transcript:
                    TranscriptSurface(panel: self, model: model)
                case .tasks:
                    TasksSurface(panel: self, model: model)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .toolbar {
            ToolbarItem(placement: .navigation) { BackButton(model: model) }
            ToolbarSpacer(.flexible, placement: .automatic)
            ToolbarItem(placement: .primaryAction) { AssistantSurfacePicker(panel: self) }
            ToolbarSpacer(.fixed, placement: .automatic)
            ToolbarItem(placement: .primaryAction) { SettingsPicker(panel: self, model: model) }
        }
        .safeAreaInset(edge: .top) {
            HStack(alignment: .center) {
                PathBar(model: model)
                Spacer()
                RunningBadge(model: model)
                Badges(model: model)
            }
            .padding(.horizontal, 8)
        }
        .safeAreaInset(edge: .bottom) {
            ComposeBar(model: model) { self.surface = .transcript }
        }
    }
}
