import SwiftUI


struct InspectorTabs: View {
    let panel: InspectorPanel

    func tab(_ surface: InspectorPanel.InspectorSurface) -> some View {
        Button { panel.surface = surface } label: {
            Image(systemName: surface.image)
                .frame(maxWidth: .infinity, maxHeight: 28, alignment: .center)
                .foregroundStyle(Style.Foreground.primary)
                .font(.system(size: 12.5))
                .contentShape(Style.Shape.tab)
        }
        .buttonStyle(.plain)
        .background(
            Style.Shape.tab
                .inset(by: 2)
                .contentShape(Style.Shape.tab)
                .opacity(panel.surface == surface ? 0.3 : 0.0)
        )
    }

    var body: some View {
        HStack(alignment: .center) {
            HStack { ForEach(InspectorPanel.InspectorSurface.allCases, id: \.self) { tab($0) } }
                .frame(maxWidth: .infinity, maxHeight: 28)
                .glassEffect(.regular, in: Style.Shape.tab)
                .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: 30)
    }
}

struct NavigatorTabs: View {
    let panel: NavigatorPanel
    var surface: NavigatorPanel.NavigatorSurface { panel.surface }

    func tab(_ surface: NavigatorPanel.NavigatorSurface) -> some View {
        Button { panel.surface = surface } label: {
            Image(systemName: surface.image)
                .frame(maxWidth: .infinity, maxHeight: 28, alignment: .center)
                .foregroundStyle(Style.Foreground.primary)
                .font(.system(size: 12.5))
                .contentShape(Style.Shape.tab)
        }
        .buttonStyle(.plain)
        .background(
            Style.Shape.tab
                .inset(by: 2)
                .contentShape(Style.Shape.tab)
                .opacity(panel.surface == surface ? 0.3 : 0.0)
        )
    }

    var body: some View {
        HStack(alignment: .center) {
            HStack { ForEach(NavigatorPanel.NavigatorSurface.allCases, id: \.self) { tab($0) } }
                .frame(maxWidth: .infinity, maxHeight: 28)
                .glassEffect(.regular, in: Style.Shape.tab)
                .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: 30)
    }
}
