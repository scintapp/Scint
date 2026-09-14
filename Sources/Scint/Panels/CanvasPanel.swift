import Foundation
import SwiftUI


struct CanvasZoom: View {
    var viewport: CanvasViewport

    var body: some View {
        Group {
            Button { viewport.zoom(-1) } label: { Image(systemName: "minus") }
            Button { viewport.actual() } label: { Text(viewport.percentage) }
            Button { viewport.zoom(-1) } label: { Image(systemName: "plus") }
        }
        .buttonStyle(.automatic)
        .font(.system(size: 11, weight: .medium))
    }
}

struct CanvasPresentation: View {
    var panel: CanvasPanel

    var body: some View {
        ForEach(CanvasAxis.allCases) { option in
            Toggle(isOn: .init(get: { panel.axis == option }, set: { if $0 { panel.axis = option } })) {
                Image(systemName: option.symbol)
            }
        }
    }
}

struct CanvasControl<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ControlGroup {
            content
        }
        .controlSize(.extraLarge)
        .controlGroupStyle(.navigation)
        .glassEffect(.regular.tint(Style.Background.glass.opacity(0.75)), in: Capsule())
        .foregroundStyle(Style.Foreground.primary, Style.Foreground.faint, Style.Foreground.muted)
        .tint(Style.Background.control)
    }
}

@Observable final class CanvasPanel: Panel {
    var scint: ScintModel
    var mode: Modality = .fixed
    var state: PanelState = .init()
    var surface: PanelSurface = .space
    var viewport: CanvasViewport = .init()
    var axis: CanvasAxis = .vertical

    init(_ scint: ScintModel) { self.scint = scint }

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
            CanvasLayout(ref: model.session.space, axis: axis, viewport: viewport, onBackground: { model.focus(nil) }) { ref in
                NodeSurface(ref: ref, panel: self, model: model)
                    .frame(width: 320)
            }
        }
        .ignoresSafeArea(.container, edges: .trailing)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Style.Background.void)
        .safeAreaInset(edge: .bottom) {
            HStack(alignment: .bottom) {
                CanvasControl { CanvasZoom(viewport: viewport) }
                Spacer()
//                ComposeBar(model: model) {}
                Spacer()
                CanvasControl { CanvasPresentation(panel: self) }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) { NavigationButtons(model: model)  }
            ToolbarSpacer(.flexible, placement: .automatic)
            ToolbarItem(placement: .principal) { PathPicker(panel: self, model: model)  }
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) {  AssistantPicker(panel: scint.studio.assistant, model: model) }
        }
    }
}
