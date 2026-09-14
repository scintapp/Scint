import SwiftUI


//struct InspectorTabs: View {
//    let panel: SettingsPanel
//
//    func tab(_ surface: SettingsPanel.PanelSurface) -> some View {
//        Button { panel.surface = surface } label: {
//            Image(systemName: surface.image)
//                .frame(maxWidth: .infinity, maxHeight: 28, alignment: .center)
//                .foregroundStyle(Style.Foreground.primary)
//                .font(.system(size: 12.5))
//                .contentShape(Style.Shape.panel)
//        }
//        .buttonStyle(.plain)
//        .background(
//            Style.Shape.panel
//                .inset(by: 2)
//                .contentShape(Style.Shape.panel)
//                .opacity(panel.surface == surface ? 0.3 : 0.0)
//        )
//    }
//
//    var body: some View {
//        HStack(alignment: .center) {
//            HStack { ForEach(SettingsPanel.PanelSurface.allCases, id: \.self) { tab($0) } }
//                .frame(maxWidth: .infinity, maxHeight: 28)
//                .glassEffect(.regular, in: Style.Shape.panel)
//                .padding(.horizontal, 8)
//        }
//        .frame(maxWidth: .infinity, maxHeight: 30)
//    }
//}

struct NavigatorTabs: View {
    let panel: NavigatorPanel
    var surface: NavigatorPanel.PanelSurface { panel.surface }

    func tab(_ surface: NavigatorPanel.PanelSurface) -> some View {
        Button { panel.surface = surface } label: {
            Image(systemName: surface.image)
                .frame(maxWidth: .infinity, maxHeight: 28, alignment: .center)
                .foregroundStyle(Style.Foreground.primary)
                .font(.system(size: 12.5))
                .contentShape(Style.Shape.panel)
        }
        .buttonStyle(.plain)
        .background(
            Style.Shape.panel
                .inset(by: 2)
                .contentShape(Style.Shape.panel)
                .opacity(panel.surface == surface ? 0.3 : 0.0)
        )
    }

    var body: some View {
        HStack(alignment: .center) {
            HStack { ForEach(NavigatorPanel.PanelSurface.allCases, id: \.self) { tab($0) } }
                .frame(maxWidth: .infinity, maxHeight: 28)
                .glassEffect(.regular, in: Style.Shape.panel)
                .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: 30)
    }
}
