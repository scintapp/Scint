import ScintComponents
import SwiftUI


struct NavigatorPicker: View {
    @Environment(ScintModel.self) var scint
    var navigator: NavigatorPanel { scint.app.studio.navigator }

    var selection: Binding<NavigatorPanel.PanelSurface> {
        Binding(get: { navigator.surface }, set: { navigator.surface = $0 })
    }

    var body: some View {
        Picker("Content", selection: selection) {
            ForEach(NavigatorPanel.PanelSurface.allCases) { surface in
                Image(systemName: surface.image).tag(surface)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .foregroundStyle(Style.Foreground.primary, Style.Foreground.primary, Style.Foreground.secondary)
        .tint(Style.Background.selection)
    }
}

@Observable final class NavigatorPanel: Panel {
    var state: PanelState = .init(presented: true)
    var surface: PanelSurface = .navigator

    enum PanelSurface: String, CaseIterable, Identifiable {
        case navigator
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var image: String { "sidebar.squares.left" }
    }

    func controls(_ model: any Model) -> Controls {
        NavigatorQuery.controls(model)
    }

    func parameters(_ model: any Model) -> Params {
        NavigatorQuery.parameters(model)
    }

    func surface(_ model: any Model) -> some View {
        ZStack(alignment: .trailing) {
            AnySurface(panel: self, model: model)
                .toolbar(removing: .sidebarToggle)
                .scrollEdgeEffectStyle(.soft, for: .top)
                .toolbar {
                    ToolbarItem(placement: .automatic) { NavigatorToggle(presented: bindable.presented) }
                    ToolbarSpacer(.flexible, placement: .automatic)
                    ToolbarItem(placement: .automatic) { CanvasToggle() }
                }
            Rectangle()
                .fill(Style.Border.hairline)
                .ignoresSafeArea()
                .frame(maxWidth: 1, maxHeight: .infinity, alignment: .trailing)
        }
    }
}
