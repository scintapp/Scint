import AgencyRuntime
import SwiftUI


@Observable final class Navigator: Panel {
    var model: Model = .workspace
    var context: Context = .navigator
    var layout: Layout = .list
    var position: CGFloat = 0
    var presented: Bool = true
    var expanded: Set<AnyHashable> = []

    enum Context: String, CaseIterable { case navigator, library }

    enum Model: CaseIterable {
        case workspace, directories, transcripts

        var label: String {
            switch self {
                case .workspace: "Spaces"
                case .directories: "Files"
                case .transcripts: "Transcripts"
            }
        }

        var image: String {
            switch self {
                case .workspace: "app"
                case .directories: "folder"
                case .transcripts: "bubble.left.and.text.bubble.right"
            }
        }
    }

    func controls(_ agency: AgencyModel) -> Controls {
        if context == .library { LibraryMap.controls(agency, self) }
        else {
            switch self.model {
                case .workspace: NavigatorMap.controls(agency, self)
                case .directories: DirectoryMap.controls(agency, self)
                case .transcripts: TranscriptsMap.controls(agency, self)
            }
        }
    }

    func parameters(_ agency: AgencyModel) -> PanelParams {
        if context == .library { LibraryMap.parameters(agency, self) }
        else {
            switch self.model {
                case .workspace: NavigatorMap.parameters(agency, self)
                case .directories: DirectoryMap.parameters(agency, self)
                case .transcripts: TranscriptsMap.parameters(agency, self)
            }
        }
    }

    func toolbar() -> some ToolbarContent {
        @Bindable var navigator = self
        return ToolbarItem(placement: .primaryAction) { NavigatorPickerToggle() }
    }

    func view(_ agency: AgencyModel) -> some View {
        VStack {
            switch context {
                case .library:
                    Builder.build(agency, self)
                    FilterInput()
                case .navigator:
                    NavigatorTabs()
                    Builder.build(agency, self)
                    FilterInput()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar(removing: .sidebarToggle)
        .toolbar { toolbar() }
    }
}


