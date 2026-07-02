import AgencyRuntime


struct SheetMap: Mapper {
    static func controls(_ agency: AgencyModel, _ panel: any Panel) -> Controls {
        .init()
    }

    static func parameters(_ agency: AgencyModel, _ panel: any Panel) -> PanelParams {
        .init()
    }
}

struct SpaceMap: Mapper {
    static func controls(_ agency: AgencyModel, _ panel: any Panel) -> Controls {
        .init(
            focused: { item in
                guard let ref = item.ref else { return false }
                return agency.session.focused == .structure(ref)
                    || agency.session.focused == .interface(ref)
                    || agency.session.focused == .content(ref)
            },
            selected: { item in
                guard let ref = item.ref else { return false }
                if let url = item.path { return agency.session.selected.selected(ref, url) }
                if let entry = item.entryId { return agency.session.selected.selected(ref, entry) }
                return agency.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.focus(ref)
            },
            onOpen: { item in
                guard let ref = item.ref else { return }
                agency.select(ref)
                agency.open(ref)
                agency.focus(ref)
                if ref.type is Sheet.Type {
                    agency.studio.detail.model = .editor
                } else if ref.type is Space.Type {
                    agency.studio.detail.model = .browser
                    agency.studio.browser.model = .space
                } else if ref.type is Workspace.Type {
                    agency.studio.detail.model = .browser
                    agency.studio.browser.model = .workspace
                }
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

    static func parameters(_ agency: AgencyModel, _ panel: any Panel) -> PanelParams {
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
                image: Iconography.icon(for: ref).symbol
            )
        }

        return .init(
            components: [
                .init(
                    id: "space",
                    header: false,
                    items: spaceItems + stateItems
                ),
            ]
        )
    }
}

struct WorkspaceMap: Mapper {
    static func controls(_ agency: AgencyModel, _ panel: any Panel) -> Controls {
        .init(
            focused: { item in
                guard let ref = item.ref else { return false }
                return agency.session.focused == .structure(ref)
                    || agency.session.focused == .interface(ref)
                    || agency.session.focused == .content(ref)
            },
            selected: { item in
                guard let ref = item.ref else { return false }
                if let url = item.path { return agency.session.selected.selected(ref, url) }
                if let entry = item.entryId { return agency.session.selected.selected(ref, entry) }
                return agency.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.focus(ref)
            },
            onOpen: { item in
                guard let ref = item.ref else { return }
                agency.select(ref)
                agency.open(ref)
                agency.focus(ref)
                if ref.type is Sheet.Type {
                    agency.studio.detail.model = .editor
                } else if ref.type is Space.Type {
                    agency.studio.detail.model = .browser
                    agency.studio.browser.model = .space
                } else if ref.type is Workspace.Type {
                    agency.studio.detail.model = .browser
                    agency.studio.browser.model = .workspace
                }
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

    static func parameters(_ agency: AgencyModel, _ panel: any Panel) -> PanelParams {
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
                image: Iconography.icon(for: ref).symbol
            )
        }

        return .init(
            components: [
                .init(
                    id: "space",
                    header: false,
                    items: spaceItems + stateItems
                )
            ]
        )
    }
}
