import SwiftUI
import ScintComponents


@Observable final class NavigatorFrame: Frame {
    var state: StateContainer = .init(presented: true)
    var surface: HostSurface = .navigator

    enum HostSurface: String, CaseIterable, Identifiable {
        case navigator
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var image: String { "sidebar.squares.left" }
    }

    func controls(_ model: any Model) -> Controls { NavigatorMapper.controls(model) }
    func parameters(_ model: any Model) -> Params { NavigatorMapper.parameters(model) }

    func surface(_ model: AppModel) -> some View {
        ZStack(alignment: .trailing) {
            VStack {
                Color.clear.frame(height: 8)
                AnySurface(host: self, model: model)
                    .toolbar(removing: .sidebarToggle)
                    .scrollEdgeEffectStyle(.soft, for: .top)
                    .toolbar {
                        ToolbarItem(placement: .automatic) { NavigatorToggle(presented: bindable.presented) }
                        ToolbarSpacer(.flexible, placement: .automatic)
                        ToolbarItem(placement: .automatic) { }
                    }
            }

            Rectangle()
                .fill(Style.Border.base)
                .ignoresSafeArea()
                .frame(width: 1, alignment: .trailing)
                .frame(maxHeight: .infinity)
            Rectangle()
                .fill(.black)
                .ignoresSafeArea()
                .frame(width: 0.5, alignment: .trailing)
                .frame(maxHeight: .infinity)
        }
    }
}
