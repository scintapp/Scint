import SwiftUI


struct InspectorTabs: View {
    @Environment(AgencyModel.self) var agency
    var inspector: Inspector { agency.studio.inspector }
    let shape = RoundedRectangle(cornerRadius: 24, style: .circular)

    @ViewBuilder func effect(_ tab: Inspector.Model) -> some View {
        RoundedRectangle(cornerRadius: 24, style: .circular)
            .glassEffect(.regular, in: shape)
            .opacity(inspector.model == tab ? 0.2 : 0.0)
    }

    @ViewBuilder func tab(_ tab: Inspector.Model) -> some View {
        Button { inspector.model = tab } label: {
            Image(systemName: tab.image)
                .frame(maxWidth: .infinity, maxHeight: 24)
                .foregroundStyle(inspector.model == tab ? Color.primary.opacity(0.9) : .primary.opacity(0.6))
                .font(.system(size: 13, weight: .medium))
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .background(effect(tab))
        .padding(2)
    }

    var body: some View {
        Group {
            HStack(spacing: 0) { ForEach(Inspector.Model.allCases, id: \.self) { tab($0) } }
                .glassEffect(.regular, in: shape)
        }
        .padding(.horizontal, 8)
    }
}

struct NavigatorTabs: View {
    @Environment(AgencyModel.self) var agency
    var navigator: Navigator { agency.studio.navigator }
    let shape = RoundedRectangle(cornerRadius: 24, style: .circular)

    @ViewBuilder func effect(_ tab: Navigator.Model) -> some View {
        RoundedRectangle(cornerRadius: 24, style: .circular)
            .contentShape(shape)
            .glassEffect(.regular, in: shape)
            .opacity(navigator.model == tab ? 0.2 : 0.0)
    }

    @ViewBuilder func tab(_ tab: Navigator.Model) -> some View {
        Button { navigator.model = tab } label: {
            Image(systemName: tab.image)
                .frame(maxWidth: .infinity, maxHeight: 24)
                .foregroundStyle(navigator.model == tab ? Color.primary.opacity(0.9) : .primary.opacity(0.6))
                .font(.system(size: 13, weight: .medium))
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .background(effect(tab))
        .padding(2)
    }

    var body: some View {
        HStack(spacing: 0) { ForEach(Navigator.Model.allCases, id: \.self) { tab($0) } }
            .glassEffect(.regular, in: shape)
            .padding(.horizontal, 8)
    }
}

