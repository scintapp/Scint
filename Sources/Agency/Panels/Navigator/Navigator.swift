import AgencyRuntime
import Foundation
import SwiftUI

@Observable final class Navigator: Panel {
    var model: Model = .workspace
    var layout: Layout = .list
    var position: CGFloat = 0
    var presented: Bool = true
    var expanded: Set<AnyHashable> = []

    enum Model: CaseIterable {
        case workspace, library, notifications

        var label: String {
            switch self {
            case .workspace: "Workspace"
            case .library: "Library"
            case .notifications: "Notifications"
            }
        }

        var image: String {
            switch self {
            case .workspace: "cube.transparent"
            case .library: "building.columns"
            case .notifications: "app.badge"
            }
        }
    }

    func parameters(_ agency: AgencyModel) -> Parameters {
        switch agency.studio.navigator.model {
        case .workspace: WorkspaceMap.parameters(agency, self)
        case .library: LibraryMap.parameters(agency, self)
        case .notifications: NotificationsMap.parameters(agency, self)
        }
    }

    func controls(_ agency: AgencyModel) -> Controls {
        switch agency.studio.navigator.model {
        case .workspace: WorkspaceMap.controls(agency, self)
        case .library: LibraryMap.controls(agency, self)
        case .notifications: NotificationsMap.controls(agency, self)
        }
    }

    func toolbar() -> some ToolbarContent {
        @Bindable var navigator = self

        return Group {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    self.presented.toggle()
                    NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
                } label: {
                    Image(systemName: "sidebar.squares.leading")
                        .foregroundStyle(.primary.opacity(0.9))
                }
                .padding(.horizontal, 1)
                .labelsHidden()
            }
            ToolbarSpacer(.fixed, placement: .automatic)
        }
    }

    @MainActor func view(_ agency: AgencyModel) -> some View {
        VStack {
            Color.clear.frame(height: 50)
            NavigatorTabs()
            Builder.build(agency, self)
        }
        .ignoresSafeArea(.container, edges: .top)
        .scrollEdgeEffectStyle(.hard, for: .top)
        .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 330)
        .toolbar(removing: .sidebarToggle)
        .toolbar { toolbar() }
    }
}



