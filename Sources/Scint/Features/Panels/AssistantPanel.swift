import Foundation
import SwiftUI


@Observable final class AssistantPanel: Panel {
    var mode: Modality = .fixed
    var state: PanelState = .init()
    var surface: PanelSurface = .composer

    enum PanelSurface: String, CaseIterable, Identifiable {
        case composer, editor, tasks
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }

    func surface(_ model: any Model) -> some View {
        TranscriptSurface(panel: self, model: model)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .safeAreaBar(edge: .bottom) {
                ZStack(alignment: .top) {
                    if let input = model.session.input {
                        EditorComponent(input, minHeight: 30, maxHeight: 256)
                            .id(input)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                    }
                    ComposeControls(model: model)
                        .frame(alignment: .trailing)
                        .opacity(0)
                    Rectangle()
                        .fill(Style.Background.overlay)
                        .frame(height: 0.75)
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) { TranscriptPicker(model: model) }
                ToolbarItem(placement: .primaryAction) { HarnessPicker(panel: self, model: model) }
            }
    }
}
