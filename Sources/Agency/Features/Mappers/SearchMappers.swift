import SwiftUI
import AgencyRuntime


struct ActivityMapper: Mapper {
    static func closures(_ agency: AgencyModel, _ frame: any Panel) -> Closures {
        return .init()
    }

    static func params(_ agency: AgencyModel, _ frame: any Panel) -> Params {
        let query = "\(agency.search.query) !service"
        let results = Runtime.shared.search(query, limit: 50).all

        return .init(
            nesting: .flat,
            sections: [
                .init(
                    id: "processes",
                    name: "Processes",
                    showsHeader: false,
                    items: results.map(item(from:))
                )
            ]
        )
    }
}

struct ContentMapper: Mapper {
    static func closures(_ agency: AgencyModel, _ frame: any Panel) -> Closures {
        Closures(
            selected: { _ in false },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.open(ref)
            }
        )
    }

    static func params(_ agency: AgencyModel, _ frame: any Panel) -> Params {
        let query = agency.search.query
        let results = Runtime.shared
            .search(query, limit: 50)
            .all
            .filter { $0.ref.type is Sheet.Type || $0.ref.type is Transcript.Type }

        return .init(
            nesting: .flat,
            sections: [
                .init(
                    id: "content",
                    name: "Content",
                    showsHeader: false,
                    items: results.map(item(from:))
                )
            ]
        )
    }
}

struct InterfacesMapper: Mapper {
    static func closures(_ agency: AgencyModel, _ frame: any Panel) -> Closures {
        .init(
            selected: { _ in false },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.select(ref)
            }
        )
    }

    static func params(_ agency: AgencyModel, _ frame: any Panel) -> Params {
        let services = Runtime.shared.search(agency.search.query, limit: 50).all.filter { $0.ref.type is Service.Type }
        let closures = Runtime.shared.search(agency.search.query, limit: 50).all.filter { $0.ref.type is Control.Type }
        let artifacts = Runtime.shared.search(agency.search.query, limit: 50).all.filter { $0.ref.type is Artifact.Type }

        return .init(
            nesting: .flat,
            sections: [
                .init(id: "artifacts", name: "Artifacts", items: artifacts.map(item(from:))),
                .init(id: "controls", name: "Controls", items: closures.map(item(from:))),
                .init(id: "services", name: "Services", items: services.map(item(from:))),
            ].filter { !$0.items.isEmpty }
        )
    }
}

struct SheetMapper: Mapper {
    static func params(_ agency: AgencyModel, _ frame: any Panel) -> Params {
        let query = "\(agency.search.query) !sheet"
        let results = Runtime.shared.search(query, limit: 50).all

        return .init(
            nesting: .flat,
            sections: [
                .init(
                    id: "sheets",
                    name: "Sheets",
                    showsHeader: false,
                    items: results.map(item(from:))
                )
            ]
        )
    }
}

struct SpacesMapper: Mapper {
    static func closures(_ agency: AgencyModel, _ frame: any Panel) -> Closures {
        .init(
            selected: { _ in false },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.select(ref)
            }
        )
    }

    static func params(_ agency: AgencyModel, _ frame: any Panel) -> Params {
        let results = Runtime.shared
            .search(agency.search.query, limit: 50)
            .all
            .filter { $0.ref.type is Space.Type }

        return .init(
            nesting: .flat,
            sections: [
                .init(
                    id: "space",
                    name: "Space",
                    showsHeader: false,
                    items: results.map(item(from:))
                )
            ]
        )
    }
}

struct PanelSearchMapper: Mapper {
    static func closures(_ agency: AgencyModel, _ frame: any Panel) -> Closures { .init() }
    
    static func params(_ agency: AgencyModel, _ frame: any Panel) -> Params {
        let query = agency.search.query
        let space = Runtime.shared.search("\(query) !structural",  limit: 50).all
        let sheets = Runtime.shared.search("\(query) !sheet", limit: 50).all
        let interfaces = Runtime.shared.search("\(query) !interfacing", limit: 50).all
        let processes = Runtime.shared.search("\(query) !service", limit: 50).all

        return .init(
            nesting: .flat,
            sections: [
                .init(id: "space", name: "Space", image: "cube.transparent", items: space.map(item(from:))),
                .init(id: "sheets", name: "Sheets", image: "text.alignleft", items: sheets.map(item(from:))),
                .init(id: "interfaces", name: "Interfaces", image: "switch.2", items: interfaces.map(item(from:))),
                .init(id: "processes", name: "Processes", image: "arrow.2.squarepath", items: processes.map(item(from:))),
            ]
        )
    }
}

struct MenuSearchMapper: Mapper {
    static func closures(_ agency: AgencyModel, _ frame: any Panel) -> Closures { .init() }

    static func params(_ agency: AgencyModel, _ frame: any Panel) -> Params {
        let query = agency.search.query
        let sheets = Runtime.shared.search("\(query) !sheet", limit: 10).all
        let interfaces = Runtime.shared.search("\(query) !interfacing", limit: 10).all

        return .init(
            nesting: .flat,
            sections: [
                .init(id: "sheets", name: "Sheets", image: "text.alignleft", items: sheets.map(item(from:))),
                .init(id: "interfaces", name: "Interfaces", image: "switch.2", items: interfaces.map(item(from:))),
            ]
        )
    }
}
