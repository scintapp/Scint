import Foundation
import SwiftUI


struct PanelHole: InsettableShape {
    var insets: EdgeInsets
    var radius: CGFloat
    var amount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let hole = CGRect(
            x: rect.minX + insets.leading,
            y: rect.minY + insets.top,
            width: rect.width - insets.leading - insets.trailing,
            height: rect.height - insets.top - insets.bottom
        ).insetBy(dx: amount, dy: amount)
        return Path(roundedRect: hole, cornerRadius: max(0, radius - amount), style: .continuous)
    }

    func inset(by amount: CGFloat) -> Self {
        var hole = self
        hole.amount += amount
        return hole
    }
}

struct PanelFrame: Shape {
    var hole: PanelHole

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        path.addPath(hole.path(in: rect))
        return path
    }
}

@Observable final class AssistantPanel: Panel {
    var mode: Modality = .fixed
    var state: PanelState = .init()
    var surface: PanelSurface = .harness

    enum PanelSurface: String, CaseIterable, Identifiable {
        case harness, transcript, material

        var id: String { rawValue }
        var label: String { rawValue.capitalized }

        var symbol: String {
            switch self {
                case .harness: "gearshape"
                case .transcript: "text.bubble"
                case .material: "text.alignleft"
            }
        }
    }

    func surface(_ model: any Model) -> some View {
        let hole = PanelHole(insets: EdgeInsets(top: 9, leading: 0, bottom: 9, trailing: 9), radius: Style.Shape.holeRadius)

        return VStack {
            switch surface {
                case .harness: HarnessSurface(panel: self, model: model)
                case .transcript: TranscriptSurface(panel: self, model: model)
                case .material: MaterialSurface(panel: self, model: model)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding([.trailing, .vertical], 9)
        .background {
            Color.clear
                .glassEffect(.clear.tint(Style.Background.base.opacity(0.75)), in: hole.inset(by: -2))
                .opacity(0.5)
                .ignoresSafeArea()
        }
        .overlay {
            ZStack {
                PanelFrame(hole: hole).fill(Style.Background.base, style: FillStyle(eoFill: true))
                hole.strokeBorder(Style.Border.handle, lineWidth: 1).opacity(0.5)
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
