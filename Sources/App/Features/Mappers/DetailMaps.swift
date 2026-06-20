import AgencyRuntime


struct ComposerMap: Mapper {
    static func controls(_ agency: AgencyModel, _ panel: some Panel) -> Controls {
        WorkspaceMap.controls(agency, panel)
    }

    static func parameters(_ agency: AgencyModel, _ panel: some Panel) -> Parameters {
        WorkspaceMap.parameters(agency, panel)
    }
}

struct BrowserMap: Mapper {
    static func controls(_ agency: AgencyModel, _ panel: some Panel) -> Controls {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                if let url = item.path { return agency.session.selected.selected(ref, url) }
                if let entry = item.entryId { return agency.session.selected.selected(ref, entry) }
                return agency.session.selected.selected(ref) || agency.session.isFocused(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.focus(ref)
            },
            onOpen: { item in
                guard let ref = item.ref else { return }
                agency.select(ref)
                agency.open(ref)
            },
            surfaceActions: {
                guard let owner = agency.session.selected.space else { return [] }
                return Action.surfaceItems(for: owner)
            },
            surfaceDropTarget: {
                agency.session.selected.space.map { .init(ref: $0, name: $0.descriptor.name) }
            },
            itemActions: { item in
                Action.itemItems(for: item)
            }
        )
    }

    static func parameters(_ agency: AgencyModel, _ panel: some Panel) -> Parameters {
        guard let space = agency.session.selected.space else { return WorkspaceMap.parameters(agency, panel) }
        let closure = Space.with(space, { $0.closure })
        let state = closure.flatMap { Closure.with($0, { $0.state }) } ?? []
        let spaces = Space.with(space, { $0.spaces }) ?? []

        let spaceItems: [ItemParams] = spaces
            .filter { $0.type is Space.Type }
            .map { child in
                return .init(
                    ref: child,
                    origin: space,
                    name: child.descriptor.name
                )
            }

        let stateItems: [ItemParams] = state.map { ref in
            .init(
                ref: ref,
                origin: space,
                name: ref.descriptor.name,
                image: Design.Component.icon(for: ref)
            )
        }

        return .init(
            sections: [
                .init(
                    id: "space",
                    header: false,
                    layout: panel.layout,
                    items: spaceItems + stateItems
                ),
            ],
            columns: [
                .init(title: "Name", width: 320, value: .primary)
            ]
        )
    }
}

struct WorkspaceMap: Mapper {
    static func controls(_ agency: AgencyModel, _ panel: some Panel) -> Controls {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                if let url = item.path { return agency.session.selected.selected(ref, url) }
                if let entry = item.entryId { return agency.session.selected.selected(ref, entry) }
                return agency.session.selected.selected(ref) || agency.session.isFocused(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.focus(ref)
            },
            onOpen: { item in
                guard let ref = item.ref else { return }
                agency.select(ref)
                agency.open(ref)
            },
            surfaceActions: {
                Action.surfaceItems(for: agency.session.workspace)
            },
            surfaceDropTarget: {
                .init(ref: agency.session.workspace, name: "Workspace")
            },
            itemActions: { item in
                Action.itemItems(for: item)
            }
        )
    }

    static func parameters(_ agency: AgencyModel, _ panel: some Panel) -> Parameters {
        let spaces = Workspace.with(agency.session.workspace, { $0.spaces }) ?? []
        let closure = Workspace.with(agency.session.workspace, { $0.closure })
        let state = closure.flatMap { Closure.with($0, { $0.state }) } ?? []

        let spaceItems: [ItemParams] = spaces
            .filter { $0.type is Space.Type }
            .map { space in
                return .init(
                    ref: space,
                    origin: agency.session.workspace,
                    name: space.descriptor.name
                )
            }

        let stateItems: [ItemParams] = state.map { ref in
            .init(
                ref: ref,
                origin: agency.session.workspace,
                name: ref.descriptor.name,
                image: Design.Component.icon(for: ref)
            )
        }

        return .init(
            sections: [
                .init(
                    id: "space",
                    header: false,
                    layout: panel.layout,
                    items: spaceItems + stateItems
                )
            ],
            columns: [
                .init(title: "Name", width: 320, value: .primary)
            ]
        )
    }
}
