import AgencyRuntime


struct MenuMap: Mapper {
    static func parameters(_ agency: AgencyModel, _ panel: any Panel) -> PanelParams {
        let query = agency.studio.palette.query
        let components = Runtime.shared.search("\(query) !components", limit: 8).all
        let controls = Runtime.shared.search("\(query) !control", limit: 8).all
        let services = Runtime.shared.search("\(query) !service", limit: 8).all
        let spaces = Runtime.shared.search("\(query) !space",  limit: 8).all

        return .init(
            nesting: .flat,
            components: [
                .init(id: "components", name: "Sheets", image: "text.alignleft", items: components.map(item(from:))),
                .init(id: "controls", name: "Controls", image: "switch.2", items: controls.map(item(from:))),
                .init(id: "services", name: "Harness", image: "arrow.2.squarepath", items: services.map(item(from:))),
                .init(id: "spaces", name: "Workspaces", image: "cube.transparent", items: spaces.map(item(from:)))
            ]
        )
    }
}
