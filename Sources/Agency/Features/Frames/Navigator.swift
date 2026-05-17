import AgencyRuntime
import Foundation
import SwiftUI


struct NavigatorTabs: View {
    @Environment(AgencyModel.self) var agency

    @ViewBuilder func effect(_ tab: Navigator.Tab) -> some View {
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

    @ViewBuilder func tab(_ tab: Navigator.Tab) -> some View {
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
        HStack(spacing: 0) { ForEach(Navigator.Tab.allCases, id: \.self) { tab($0) } }
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.primary.opacity(0.075), lineWidth: 0.5)
            }
            .background(.clear)
            .padding([.horizontal, .bottom], 8)
            .frame(maxWidth: .infinity, maxHeight: 81, alignment: .bottom)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.gray.opacity(0.05))
                    .blur(radius: 0.1)
                    .frame(height: 1)
            }
    }
}

struct NavigatorToolbar: ToolbarContent {
    @Environment(AgencyModel.self) var agency

    var body: some ToolbarContent {
        @Bindable var navigator = agency.studio.navigator

        ToolbarItem(placement: .primaryAction) { NavigatorToggle(presented: $navigator.presented) }
            .sharedBackgroundVisibility(agency.studio.navigator.presented ? .hidden : .visible)
        ToolbarSpacer(.fixed, placement: .automatic)
    }
}

@Observable final class Navigator: Frame {
    var model: Tab = .boundaries
    var position: CGFloat = 0
    var presented: Bool = true
    var expanded: Set<AnyHashable> = []

    enum Tab: String, CaseIterable {
        case boundaries, contexts, notifications

        var label: String {
            switch self {
            case .boundaries: "Boundaries"
            case .contexts: "Processes"
            case .notifications: "Notifications"
            }
        }

        var image: String {
            switch self {
            case .boundaries: "cube.transparent"
            case .contexts: "building.columns"
            case .notifications: "app.badge"
            }
        }
    }

    func params(_ agency: AgencyModel) -> Params {
        switch agency.studio.navigator.model {
        case .boundaries: BoundaryMapper.params(agency, self)
        case .contexts: ActivityMapper.params(agency, self)
        case .notifications: NotificationsMapper.params(agency, self)
        }
    }

    func closures(_ agency: AgencyModel) -> Closures {
        switch agency.studio.navigator.model {
        case .boundaries: BoundaryMapper.closures(agency, self)
        case .contexts: ActivityMapper.closures(agency, self)
        case .notifications: SpacesMapper.closures(agency, self)
        }
    }

    @MainActor func build(_ agency: AgencyModel) -> some View {
        VStack {
            NavigatorTabs()
            Constructor.build(self, params(agency), closures(agency))
        }
    }
}



