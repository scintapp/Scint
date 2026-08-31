import SwiftUI


@Observable final class TasksPanel: Panel {
    var mode: Modality = .floating
    var state: PanelState = .init(expanded: ["open", "done"])
    var surface: PanelSurface = .floating

    enum PanelSurface: String, CaseIterable, Identifiable {
        case fixed, floating
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var symbol: String { "checkmark.app" }
    }

    func parameters(_ model: any Model) -> Params {
        switch surface {
            case .fixed:
                return .init()
            case .floating:
                return .init(
                    panel: .init(
                        key: .tasks,
                        sizing: .init(size: .init(width: 640, height: 480)),
                        dismissal: [.escape, .outsideClick],
                        resizable: true,
                        pinnable: true
                    )
                )
        }
    }

    func surface(_ model: any Model) -> some View {
        TasksSurface(panel: self, model: model)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
