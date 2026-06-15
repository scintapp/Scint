import SwiftUI


struct InspectorTab: View {
    let inspector: Inspector.Model
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: inspector.image)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(selected ? .white.opacity(0.8) : .white.opacity(0.60))
                .frame(maxWidth: .infinity, maxHeight: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(selected ? Color.gray.opacity(0.1) : Color.clear)
                .stroke(selected ? Color.primary.opacity(0.16) : Color.clear, lineWidth: 0.7)
                .shadow(color: selected ? .black.opacity(0.4) : .clear, radius: 1, x: 0, y: 0.5)
        }
    }
}

struct InspectorTabs: View {
    let inspector: Inspector

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Inspector.Model.allCases, id: \.self) { tab in
                InspectorTab(
                    inspector: tab,
                    selected: inspector.model == tab,
                    action: { inspector.model = tab }
                )
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.black.opacity(0.05))
                .stroke(Color.primary.opacity(0.09), lineWidth: 0.5)
        }
        .padding([.horizontal, .bottom], 8)
    }
}

struct NavigatorTabs: View {
    @Environment(AgencyModel.self) var agency

    @ViewBuilder func effect(_ tab: Navigator.Model) -> some View {
        if agency.studio.navigator.model == tab {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.black.opacity(0.2))
                .glassEffect(.clear)
                .opacity(1)
        } else {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.gray.opacity(0.0))
                .glassEffect(.clear)
                .opacity(0)
        }
    }

    @ViewBuilder func tab(_ tab: Navigator.Model) -> some View {
        let navigator = agency.studio.navigator
        Button { navigator.model = tab } label: {
            Image(systemName: tab.image)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(navigator.model == tab ? .white.opacity(0.86) : .white.opacity(0.54))
                .frame(maxWidth: .infinity, maxHeight: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(effect(tab))
    }

    var body: some View {
        HStack(spacing: 0) { ForEach(Navigator.Model.allCases, id: \.self) { tab($0) } }
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.primary.opacity(0.075), lineWidth: 0.5)
            }
            .background(.clear)
            .padding(.horizontal, 8)
//            .frame(maxWidth: .infinity, maxHeight: 90, alignment: .bottom)
//            .overlay(alignment: .bottom) {
//                Rectangle()
//                    .fill(Color.gray.opacity(0.05))
//                    .blur(radius: 0.1)
//                    .frame(height: 1)
//            }
    }
}
