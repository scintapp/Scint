import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


@Observable final class InputPanel: Panel {
    var state: PanelState = .init()
    var surface: PanelSurface = .input

    enum PanelSurface: String, CaseIterable, Identifiable {
        case input

        var id: String { rawValue }
        var label: String { rawValue.capitalized }

        var symbol: String { "square.fill.text.grid.1x2" }
    }

    func parameters(_ model: Model) -> Params {
        return .init(
            id: PanelKey.search.id,
            panel: .init(
                key: .input,
                sizing: .init(size: .init(width: 640, height: 90)),
                dismissal: [.escape, .outsideClick],
                movable: true,
                resizable: false,
                pinnable: false
            ),
        )
    }

    func surface(_ model: any Model) -> some View {
        AnySurface(panel: self, model: model)
    }
}

#Preview {
    @Previewable @State var panel = InputPanel()
    @Previewable @State var model: StudioModel?

    VStack {
        if let model {
            Float(content: panel.surface(model))
                .frame(width: 640, height: 90)
        }
    }
    .frame(width: 760, height: 210)
    .background(LinearGradient(colors: [.indigo, .pink, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
    .task {
        try? await Runtime.shared.load()
        model = StudioModel(Session(await AppData()))
    }
}
