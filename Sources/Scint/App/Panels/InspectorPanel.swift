import Foundation
import SwiftUI
import ScintComponents


@Observable final class InspectorPanel: Panel {
    var state: PanelState = .init()
    var surface: PanelSurface = .documents

    enum PanelSurface: String, CaseIterable, Identifiable {
        case documents, transcripts, settings

        var id: String { rawValue }
        var label: String { rawValue.capitalized }

        var symbol: String {
            switch self {
                case .documents: "text.alignleft"
                case .transcripts: "text.bubble"
                case .settings: "switch.2"
            }
        }
    }

    func surface(_ model: any Model) -> some View {
        let hole = PanelHole(insets: EdgeInsets(top: 9, leading: 0, bottom: 9, trailing: 9), radius: Metrics.inspectorHoleRadius)

        return VStack {
            switch surface {
                case .documents: DocumentContent(panel: self, model: model)
                case .transcripts: TranscriptContent(panel: self, model: model)
                case .settings: SpaceSettings(panel: self, model: model)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding([.trailing, .vertical], 9)
        .background {
            Color.clear
                .glassEffect(.clear.tint(Style.Background.canvas.opacity(0.75)), in: hole.inset(by: -2))
                .opacity(0.5)
                .ignoresSafeArea()
        }
        .overlay {
            ZStack {
                PanelFrame(hole: hole).fill(Style.Background.canvas, style: FillStyle(eoFill: true))
                hole.strokeBorder(Style.Border.hairline, lineWidth: 1).opacity(0.5)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        .toolbar {
            ToolbarSpacer(.fixed, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) { }
        }
    }
}
