import Foundation
import SwiftUI


@Observable final class AssistantPanel: Panel {
    var mode: Modality = .fixed
    var state: PanelState = .init()
    var surface: PanelSurface = .harness

    enum PanelSurface: String, CaseIterable, Identifiable {
        case harness, material, transcript

        var id: String { rawValue }
        var label: String { rawValue.capitalized }

        var symbol: String {
            switch self {
                case .harness: "gearshape"
                case .material: "text.alignleft"
                case .transcript: "text.bubble"
            }
        }
    }

    func surface(_ model: any Model) -> some View {
        Group {
            switch surface {
                case .harness: HarnessSurface(ref: model.session.origin, panel: self, model: model)
                case .material: MaterialSurface(panel: self, model: model)
                case .transcript: TranscriptSurface(panel: self, model: model)
                }
            }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .toolbar {
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) { AssistantPicker(panel: self, model: model) }
        }
    }
}
