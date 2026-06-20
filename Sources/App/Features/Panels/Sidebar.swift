import AgencyRuntime
import SwiftUI


@Observable final class Navigator: Panel {
    var model: Model = .spaces
    var layout: Layout = .list
    var position: CGFloat = 0
    var presented: Bool = true
    var expanded: Set<AnyHashable> = []

    enum Model: CaseIterable {
        case spaces, library

        var label: String {
            switch self {
            case .spaces: "Spaces"
            case .library: "Library"
            }
        }

        var image: String {
            switch self {
            case .spaces: "cube.transparent"
            case .library: "building.columns"
            }
        }
    }

    func controls(_ agency: AgencyModel) -> Controls {
        switch self.model {
            case .spaces: NavigatorMap.controls(agency, self)
            case .library: LibraryMap.controls(agency, self)
        }
    }

    func parameters(_ agency: AgencyModel) -> Parameters {
        switch self.model {
        case .spaces: NavigatorMap.parameters(agency, self)
        case .library: LibraryMap.parameters(agency, self)
        }
    }

    func toolbar() -> some ToolbarContent {
        @Bindable var navigator = self

        return Group {
            ToolbarItem(placement: .primaryAction) { NavigatorToggle(presented: $navigator.presented) }
        }
    }

    func view(_ agency: AgencyModel) -> some View {
        VStack {
            Builder.build(agency, self)
            FilterInput()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar(removing: .sidebarToggle)
        .toolbar { toolbar() }
    }
}


