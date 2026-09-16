import SwiftUI


struct NavigatorPicker: View {
    @Environment(ScintModel.self) var scint
    var navigator: NavigatorPanel { scint.app.studio.navigator }

    private var selection: Binding<NavigatorPanel.PanelSurface> {
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
        .foregroundStyle(Style.Foreground.primary, Style.Foreground.secondary, Style.Foreground.faint)
        .tint(Style.Background.control)
    }
}

@Observable final class NavigatorPanel: Panel {
    var mode: Modality = .fixed
    var state: PanelState = .init(presented: true)
    var surface: PanelSurface = .execute

    enum PanelSurface: String, CaseIterable, Identifiable {
        case compose, execute

        var id: String { rawValue }
        var label: String { rawValue.capitalized }

        var image: String {
            switch self {
                case .compose: "rectangle.3.offgrid"
                case .execute: "play.fill"
            }
        }
    }

    func controls(_ model: any Model) -> Controls {
        switch surface {
            case .compose: NavigatorComposeQuery.controls(model)
            case .execute: NavigatorExecuteQuery.controls(model)
        }
    }

    func parameters(_ model: any Model) -> Params {
        switch surface {
            case .compose: NavigatorComposeQuery.parameters(model)
            case .execute: NavigatorExecuteQuery.parameters(model)
        }
    }

    func surface(_ model: any Model) -> some View {
        AnySurface(panel: self, model: model)
            .toolbar(removing: .sidebarToggle)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .toolbar {
                ToolbarItem(placement: .automatic) { NavigatorToggle(presented: bindable.presented) }
                ToolbarSpacer(.flexible, placement: .automatic)
                ToolbarItem(placement: .automatic) { NavigatorPicker() }
            }
    }
}
