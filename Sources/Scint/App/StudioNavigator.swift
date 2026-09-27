import SwiftUI
import ScintComponents


struct NavigatorToggle: View {
    @Binding var presented: Bool

    var body: some View {
        Button {
            presented.toggle()
            NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
        } label: {
            Image(systemName: "sidebar.squares.left")
                .foregroundStyle(Style.Foreground.primary)
        }
        .padding(.horizontal, 1)
        .labelsHidden()
        .overlay {
            Style.Background.canvas
                .opacity(0.4)
                .blendMode(.overlay)
                .allowsHitTesting(false)
        }
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

    @ViewBuilder
    func surface(_ model: any Model) -> some View {
        ZStack(alignment: .trailing) {
            VStack {
                Color.clear.frame(height: 8)
                AnySurface(panel: self, model: model)
                    .toolbar(removing: .sidebarToggle)
                    .scrollEdgeEffectStyle(.soft, for: .top)
                    .toolbar {
                        ToolbarItem(placement: .automatic) { NavigatorToggle(presented: bindable.presented) }
                        ToolbarSpacer(.flexible, placement: .automatic)
                        ToolbarItem(placement: .automatic) { }
                    }
            }
            Rectangle()
                .fill(Style.Border.panel)
                .ignoresSafeArea()
                .frame(maxWidth: 1, maxHeight: .infinity, alignment: .trailing)
        }
    }
}
