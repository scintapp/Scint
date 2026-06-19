import SwiftUI


struct InspectorTabs: View {
    @Environment(AgencyModel.self) var agency
    var inspector: Inspector { agency.studio.inspector }
    let rectangle = RoundedRectangle(cornerRadius: 26, style: .circular)

    @ViewBuilder func effect(_ tab: Inspector.Model) -> some View {
        RoundedRectangle(cornerRadius: 26, style: .circular)
            .glassEffect(.clear.tint(.primary.opacity(0.2)), in: rectangle)
            .opacity(inspector.model == tab ? 0.2 : 0.0)
    }

    @ViewBuilder func tab(_ tab: Inspector.Model) -> some View {
        Button { inspector.model = tab } label: {
            Image(systemName: tab.image)
                .frame(maxWidth: .infinity, maxHeight: 26)
                .foregroundStyle(inspector.model == tab ? Color.primary.opacity(0.9) : .primary.opacity(0.6))
                .font(.system(size: 13, weight: .medium))
                .contentShape(rectangle)
        }
        .buttonStyle(.plain)
        .background(effect(tab))
        .padding(1.6)
    }

    var body: some View {
        Group {
            HStack(spacing: 0) { ForEach(Inspector.Model.allCases, id: \.self) { tab($0) } }
                .glassEffect(.regular, in: rectangle)
        }
        .padding(.horizontal, 8)
    }
}

struct NavigatorTabs: View {
    @Environment(AgencyModel.self) var agency
    var navigator: Navigator { agency.studio.navigator }
    let rectangle = RoundedRectangle(cornerRadius: 26, style: .circular)

    @ViewBuilder func effect(_ tab: Navigator.Model) -> some View {
        RoundedRectangle(cornerRadius: 26, style: .circular)
            .contentShape(rectangle)
            .glassEffect(.clear.tint(.primary.opacity(0.2)), in: rectangle)
            .opacity(navigator.model == tab ? 0.2 : 0.0)
    }

    @ViewBuilder func tab(_ tab: Navigator.Model) -> some View {
        Button { navigator.model = tab } label: {
            Image(systemName: tab.image)
                .frame(maxWidth: .infinity, maxHeight: 26)
                .foregroundStyle(navigator.model == tab ? Color.primary.opacity(0.9) : .primary.opacity(0.6))
                .font(.system(size: 13, weight: .medium))
                .contentShape(rectangle)
        }
        .buttonStyle(.plain)
        .background(effect(tab))
        .padding(1.6)
    }

    var body: some View {
        HStack(spacing: 0) { ForEach(Navigator.Model.allCases, id: \.self) { tab($0) } }
            .glassEffect(.regular, in: rectangle)
            .padding(.horizontal, 8)
    }
}
