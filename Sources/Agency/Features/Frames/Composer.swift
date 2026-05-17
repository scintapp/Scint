import AgencyRuntime
import SwiftUI
import Foundation


@Observable final class Composer: Frame {
    var model: Scope = .everywhere
    var presented: Bool = true
    var position: CGFloat = 0
    var expanded: Set<AnyHashable> = []
    var index: Int = 0
    var query: String = ""
    var details: AgencyRuntime.SearchDetails?

    enum Scope: String, CaseIterable, Identifiable {
        case everywhere, library, processes, space

        var id: String { rawValue }

        var label: String {
            switch self {
            case .everywhere: "Everything"
            case .library: "Library"
            case .processes: "Processes"
            case .space: "Space"
            }
        }

        var image: String {
            switch self {
            case .everywhere: "magnifyingglass"
            case .library: "building.columns"
            case .processes: "arrow.2.squarepath"
            case .space: "cube.transparent"
            }
        }

        var placeholder: String {
            switch self {
            case .everywhere: "Search"
            default: "\(label)"
            }
        }
    }

    static func controls(_ agency: AgencyModel) -> Controls {
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

    static func params(_ agency: AgencyModel) -> Params {
        switch agency.studio.composer.model {
        case .everywhere: SearchMapper.params(agency)
        case .library: LibraryMapper.params(agency)
        case .processes: ProcessMapper.params(agency)
        case .space: SpacesMapper.params(agency)
        }
    }

    func build(_ agency: AgencyModel) -> some View {
        EmptyView()
    }

    func reset() {
        query = ""
        index = 0
        details = nil
        expanded.removeAll()
    }
}

