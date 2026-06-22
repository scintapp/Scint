import AgencyRuntime


struct ActionMap: Mapper {
    static func controls(_ agency: AgencyModel, _ panel: any Panel) -> Controls {
        .init()
    }

    static func parameters(_ agency: AgencyModel, _ panel: any Panel) -> Parameters {
        let query = agency.studio.actions.query
        let components = agency.search("\(query) !components", limit: 20).all
        let controls = Runtime.shared.search("\(query) !control", limit: 20).all
        let services = Runtime.shared.search("\(query) !service", limit: 20).all
        let spaces = Runtime.shared.search("\(query) !space",  limit: 20).all

        return .init(
            nesting: .flat,
            sections: [
                .init(
                    id: "components",
                    name: "Sheets",
                    header: false,
                    image: "text.alignleft",
                    items: components.map(item(from:))
                ),
                .init(
                    id: "controls",
                    name: "Controls",
                    header: false,
                    image: "switch.2",
                    items: controls.map(item(from:))
                ),
                .init(
                    id: "services",
                    name: "Harness",
                    header: false,
                    image: "arrow.2.squarepath",
                    items: services.map(item(from:))
                ),
                .init(
                    id: "spaces",
                    name: "Workspaces",
                    header: false,
                    image: "cube.transparent",
                    items: spaces.map(item(from:))
                )
            ]
        )
    }
}
