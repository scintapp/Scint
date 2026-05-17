import AgencyRuntime
import SwiftUI
import Foundation


@Observable final class Search {
    var scope: Scope = .everything
    var index: Int = 0
    var query: String = ""
    var details: AgencyRuntime.SearchResultDetails?

    enum Scope: String, CaseIterable, Identifiable {
        case everything, space, controls, library, activity

        var id: String { rawValue }

        var label: String {
            switch self {
            case .everything: "Search"
            case .space: "Space"
            case .controls: "Controls"
            case .library: "Library"
            case .activity: "Activity"
            }
        }

        var image: String {
            switch self {
            case .everything: "magnifyingglass"
            case .space: "cube.transparent"
            case .controls: "switch.2"
            case .library: "building.columns"
            case .activity: "play.square.stack"
            }
        }

        var placeholder: String {
            switch self {
            case .everything: "Search"
            default: "\(label)"
            }
        }
    }

    func closures(_ agency: AgencyModel) -> Closures {
        .init(
            selected: {
                item in guard let ref = item.ref else { return false }
                return agency.session.selected(ref, item.path)
            },
            onSelect: {
                item in guard let ref = item.ref else { return }
                agency.select(ref, url: item.path)
            }
        )
    }

    func params(_ agency: AgencyModel) -> Params {
        switch agency.search.scope {
        case .everything: SearchMapper.params(agency)
        case .space: SpacesMapper.params(agency)
        case .controls: InterfacesMapper.params(agency)
        case .library: LibraryMapper.params(agency)
        case .activity: ActivityMapper.params(agency)
        }
    }

    func reset() {
        query = ""
        index = 0
        details = nil
    }
}


//@Observable final class Search: Frame {
//    var presented: Bool = true
//    var position: CGFloat = 0
//    var expanded: Set<AnyHashable> = []
//
//    var active: Scope = .all
//    var query: String = ""
//
//    enum Scope: String, CaseIterable, Identifiable {
//        case all, space, sheets, artifacts, services
//
//        var id: String { rawValue }
//
//        var label: String {
//            switch self {
//            case .all: "All"
//            case .space: "Space"
//            case .sheets: "Sheets"
//            case .artifacts: "Artifacts"
//            case .services: "Services"
//            }
//        }
//
//        var image: String {
//            switch self {
//            case .all: "magnifyingglass"
//            case .space: "cube.transparent"
//            case .sheets: "text.alignleft"
//            case .artifacts: "archivebox"
//            case .services: "arrow.2.squarepath"
//            }
//        }
//    }
//
//    static func params(_ agency: AgencyModel) -> Params {
//        SearchMapper.params(agency)
//    }
//
//    func closures(_ agency: AgencyModel) -> Closures {
//        .init(
//            selected: { item in
//                guard let ref = item.ref else { return false }
//                return agency.session.selected(ref, item.path)
//            },
//            onSelect: { item in
//                guard let ref = item.ref else { return }
//                agency.select(ref, url: item.path)
//            }
//        )
//    }
//
//    @MainActor func build(_ agency: AgencyModel) -> some View {
//        Constructor.build(self, Self.params(agency), closures(agency))
//    }
//}
