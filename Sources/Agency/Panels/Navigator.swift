import AgencyRuntime
import SwiftUI


@Observable final class Navigator: Panel {
    var model: Model = .workspace
    var presented: Bool = true
    var state = SurfaceState()

    enum Model: CaseIterable {
        case workspace, directories, transcripts, library

        var label: String {
            switch self {
                case .workspace: "Workspace"
                case .directories: "Files"
                case .transcripts: "Transcripts"
                case .library: "Library"
            }
        }

        var image: String {
            switch self {
                case .workspace: "app"
                case .directories: "folder"
                case .transcripts: "bubble.left.and.text.bubble.right"
                case .library: "books.vertical"
            }
        }
    }

    func controls(_ agency: AgencyModel) -> Controls {
            switch self.model {
                case .library: LibraryMap.controls(agency)
                case .workspace: NavigatorMap.controls(agency)
                case .directories: DirectoryMap.controls(agency)
                case .transcripts: EmptyMap.controls(agency)
        }
    }

    func parameters(_ agency: AgencyModel) -> Params {
        switch self.model {
            case .library: LibraryMap.parameters(agency)
            case .workspace: NavigatorMap.parameters(agency)
            case .directories: DirectoryMap.parameters(agency)
            case .transcripts: EmptyMap.parameters(agency)
        }
    }

    func toolbar() -> some ToolbarContent {
        Group {
            ToolbarItem(placement: .primaryAction) { NavigatorToggle() }
            ToolbarSpacer(.fixed, placement: .primaryAction)
        }
    }

    func view(_ agency: AgencyModel) -> some View {
        VStack(alignment: .leading) {
            Builder.build(self, parameters(agency), controls(agency))
                .scrollEdgeEffectStyle(.soft, for: .top)
        }
        .frame(maxHeight: .infinity)
        .toolbar(removing: .sidebarToggle)
        .toolbar { toolbar() }
        .safeAreaBar(edge: .top) { NavigatorTabs() }
        .safeAreaBar(edge: .bottom) { FilterInput() }
    }
}
