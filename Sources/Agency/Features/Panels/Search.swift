import AgencyRuntime
import SwiftUI
import Foundation


@Observable final class Search: Panel {
    var model: Model = .all
    var position: CGFloat = 0
    var presented: Bool = true
    var expanded: Set<AnyHashable> = []

    var query: String = ""
    var index: Int = 0
    var details: AgencyRuntime.SearchResultDetails?
    var prompt: ControlPrompt?

    struct ControlPrompt: Hashable {
        let ref: Reference
        var arguments: String = ""
    }

    enum Model: String, CaseIterable, Identifiable {
        case all, space, library, activities

        var id: String { rawValue }

        var label: String {
            switch self {
            case .all: "Search"
            case .space: "Space"
            case .library: "Library"
            case .activities: "Activity"
            }
        }

        var image: String {
            switch self {
            case .all: "magnifyingglass"
            case .space: "cube.transparent"
            case .library: "building.columns"
            case .activities: "play.square.stack"
            }
        }

        var placeholder: String {
            switch self {
            case .all: "Search"
            default: "\(label)"
            }
        }
    }

    func closures(_ agency: AgencyModel) -> Closures {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                return agency.session.selected(ref, item.path)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.select(ref, url: item.path)
            }
        )
    }

    func params(_ agency: AgencyModel) -> Params { PanelSearchMapper.params(agency, self) }

    func reset() {
        query = ""
        index = 0
        details = nil
    }
}

