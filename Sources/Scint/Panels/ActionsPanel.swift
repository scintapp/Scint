import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


@Observable final class ActionsPanel: Panel {
    var state: PanelState = .init()
    var surface: PanelSurface = .composer

    enum PanelSurface: String, CaseIterable, Identifiable {
        case composer, editor

        var id: String { rawValue }
        var label: String { rawValue.capitalized }

        var symbol: String {
            switch self {
                case .composer: "square.fill.text.grid.1x2"
                case .editor: "square.and.pencil"
            }
        }
    }

    func surface(_ model: any Model) -> some View {
        AnySurface(panel: self, model: model)
    }
}

#Preview {
    @Previewable @State var panel = ActionsPanel()
    @Previewable @State var model: StudioModel?

    VStack {
        if let model {
            Float(content: panel.surface(model))
                .frame(width: 640, height: 480)
        }
    }
    .frame(width: 760, height: 600)
    .background(LinearGradient(colors: [.indigo, .pink, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
    .task {
        try? await Runtime.shared.load()
        model = StudioModel(Session(await ScintData()))
    }
}
