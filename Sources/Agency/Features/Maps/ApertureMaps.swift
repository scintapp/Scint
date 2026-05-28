import SwiftUI
import AgencyRuntime


struct ComponentsMap: Mapper {
    static func closures(_ agency: AgencyModel, _ panel: any Panel) -> Closures {
        .init(
            selected: { _ in false },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.select(ref)
            }
        )
    }

    static func params(_ agency: AgencyModel, _ panel: any Panel) -> Params {
        let sheets = Runtime.shared.query(agency.aperture.query, limit: 50).all.filter { $0.ref.type is Sheet.Type }
        let transcripts = Runtime.shared.query(agency.aperture.query, limit: 50).all.filter { $0.ref.type is Transcript.Type }

        return .init(
            nesting: .flat,
            sections: [
                .init(id: "sheets", name: "Sheets", items: sheets.map(item(from:))),
                .init(id: "transcripts", name: "Transcripts", items: transcripts.map(item(from:))),
            ].filter { !$0.items.isEmpty }
        )
    }
}

struct InterfacesMap: Mapper {
    static func closures(_ agency: AgencyModel, _ panel: any Panel) -> Closures {
        .init(
            selected: { _ in false },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.select(ref)
            }
        )
    }

    static func params(_ agency: AgencyModel, _ panel: any Panel) -> Params {
        let artifacts = Runtime.shared.query(agency.aperture.query, limit: 50).all.filter { $0.ref.type is Artifact.Type }
        let controls = Runtime.shared.query(agency.aperture.query, limit: 50).all.filter { $0.ref.type is Command.Type }
        let services = Runtime.shared.query(agency.aperture.query, limit: 50).all.filter { $0.ref.type is Harness.Type }

        return .init(
            nesting: .flat,
            sections: [
                .init(id: "artifacts", name: "Artifacts", items: artifacts.map(item(from:))),
                .init(id: "controls", name: "Controls", items: controls.map(item(from:))),
                .init(id: "services", name: "Harness", items: services.map(item(from:))),
            ].filter { !$0.items.isEmpty }
        )
    }
}

struct StructuresMap: Mapper {
    static func closures(_ agency: AgencyModel, _ panel: any Panel) -> Closures {
        .init(
            selected: { _ in false },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.select(ref)
            }
        )
    }

    static func params(_ agency: AgencyModel, _ panel: any Panel) -> Params {
        let results = Runtime.shared.query(agency.aperture.query, limit: 50).all.filter { $0.ref.type is Space.Type }

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

struct SearchMap: Mapper {
    static func closures(_ agency: AgencyModel, _ panel: any Panel) -> Closures { .init() }
    
    static func params(_ agency: AgencyModel, _ panel: any Panel) -> Params {
        let query = agency.aperture.query
        let components = Runtime.shared.query("\(query) !components", limit: 20).all
        let controls = Runtime.shared.query("\(query) !control", limit: 20).all
        let services = Runtime.shared.query("\(query) !service", limit: 20).all
        let spaces = Runtime.shared.query("\(query) !space",  limit: 20).all

        return .init(
            nesting: .flat,
            sections: [
                .init(id: "components", name: "Sheets", image: "text.alignleft", items: components.map(item(from:))),
                .init(id: "controls", name: "Controls", image: "switch.2", items: controls.map(item(from:))),
                .init(id: "services", name: "Harness", image: "arrow.2.squarepath", items: services.map(item(from:))),
                .init(id: "spaces", name: "Workspaces", image: "cube.transparent", items: spaces.map(item(from:)))
            ]
        )
    }
}

struct MenuMap: Mapper {
    static func closures(_ agency: AgencyModel, _ panel: any Panel) -> Closures { .init() }

    static func params(_ agency: AgencyModel, _ panel: any Panel) -> Params {
        let query = agency.aperture.query
        let components = Runtime.shared.query("\(query) !components", limit: 8).all
        let controls = Runtime.shared.query("\(query) !control", limit: 8).all
        let services = Runtime.shared.query("\(query) !service", limit: 8).all
        let spaces = Runtime.shared.query("\(query) !space",  limit: 8).all

        return .init(
            nesting: .flat,
            sections: [
                .init(id: "components", name: "Sheets", image: "text.alignleft", items: components.map(item(from:))),
                .init(id: "controls", name: "Controls", image: "switch.2", items: controls.map(item(from:))),
                .init(id: "services", name: "Harness", image: "arrow.2.squarepath", items: services.map(item(from:))),
                .init(id: "spaces", name: "Workspaces", image: "cube.transparent", items: spaces.map(item(from:)))
            ]
        )
    }
}
