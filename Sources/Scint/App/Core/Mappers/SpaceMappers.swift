import SwiftUI
import ScintRuntime
import ScintComponents

struct ProjectsList: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init(
            focused: { item in
                guard let ref = item.ref else { return false }
                return model.session.focus == .structure(ref)
            },
            selected: { item in
                guard let ref = item.ref else { return false }
                if let url = item.path { return model.session.selection.selected(ref, url) }
                return model.session.selection.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                model.select(ref, entry: item.entryId, url: item.path)
            },
            surfaceDropTarget: {
                .init(name: "Projects")
            },
            wrapLink: { view, item, _ in
                guard let ref = item.ref else { return view }
                return AnyView(view.contextMenu { ContextActionMenu(ref: ref, model: model) })
            },
            dropTypes: { item in
                item.ref == nil ? [.space] : ReferenceTransfer.dropTypes(for: item)
            },
            onDrop: { providers, target in
                target.ref == nil ? ReferenceTransfer.detach(providers) : ReferenceTransfer.handle(providers, target: target, sharing: true)
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        var projects: [Reference] {
            guard let projects = Space.with(model.session.projects, { $0.spaces })
                    else { return [] }
            return Array(projects)
        }

        func sorted(_ refs: [Reference]) -> [Reference] {
            refs.sorted { $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending }
        }

        func children(of ref: Reference) -> [Reference] {
            sorted(Space.with(ref, { Array($0.spaces) }) ?? [])
        }

        func descendants(of ref: Reference) -> [Reference] {
            children(of: ref).flatMap { [$0] + descendants(of: $0) }
        }

        func item(_ ref: Reference, origin: Reference) -> ItemParams {
            let dot = Iconography.dot(for: ref)
            return .init(ref: ref, origin: origin, name: ref.descriptor.name, image: dot.symbol, tint: dot.tint)
        }

        func working(_ refs: [Reference]) -> Int {
            refs.count { ref in
                switch ref.context?.state {
                    case .active, .working: true
                    default: false
                }
            }
        }

        func root(_ ref: Reference) -> ItemParams {
            let below = descendants(of: ref)
            let active = working(below)

            return .init(
                ref: ref,
                origin: ref,
                name: ref.descriptor.name,
                image: Iconography.icon(for: ref).symbol,
                tint: Iconography.icon(for: ref).tint,
                count: active > 0 ? active : nil,
                items: below.map { item($0, origin: ref) }
            )
        }

        return .init(
            id: "projects",
            header: false,
            sections: [
                .init(
                    id: "projects",
                    name: "Projects",
                    items: sorted(projects).map(root)
                )
            ]
        )
    }
}

struct SpaceOutlineMapper: Mapper {
    static func controls(_ model: any Model) -> Controls {
        let harness = HarnessGroup.controls(model)
        let commands = CommandsGroup.controls(model)
        let artifacts = ArtifactsGroup.controls(model)

        func source(for item: ItemParams) -> Controls {
            if let key = item.key {
                if key == "add-artifacts" || key == "add-files" { return artifacts }
                return harness
            }
            if item.ref?.type is Command.Type { return commands }
            if item.ref?.type is Harness.Type { return harness }
            return artifacts
        }

        return .init(
            onToggle: { item in source(for: item).onToggle?(item) },
            onChange: { item, selection in source(for: item).onChange?(item, selection) },
            onValueChange: { item, value in source(for: item).onValueChange?(item, value) },
            onSelect: { item in source(for: item).onSelect?(item) },
            onAction: { item in source(for: item).onAction?(item) }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        var focused: Reference? {
            if case .structure(let ref) = model.session.focus { return ref }
            return nil
        }
        guard let space = focused else { return .init() }

        return .init(
            ref: space,
            layout: .group,
            header: true,
            sections: DocumentsGroup.parameters(model).sections + ArtifactsGroup.parameters(model).sections
        )
    }
}

struct SpaceSettingsMapper: Mapper {
    static func controls(_ model: any Model) -> Controls {
        let harness = HarnessGroup.controls(model)
        let commands = CommandsGroup.controls(model)
        let artifacts = ArtifactsGroup.controls(model)

        func source(for item: ItemParams) -> Controls {
            if let key = item.key {
                if key == "add-artifacts" || key == "add-files" { return artifacts }
                return harness
            }
            if item.ref?.type is Command.Type { return commands }
            if item.ref?.type is Harness.Type { return harness }
            return artifacts
        }

        return .init(
            onToggle: { item in source(for: item).onToggle?(item) },
            onChange: { item, selection in source(for: item).onChange?(item, selection) },
            onValueChange: { item, value in source(for: item).onValueChange?(item, value) },
            onSelect: { item in source(for: item).onSelect?(item) },
            onAction: { item in source(for: item).onAction?(item) }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        var focused: Reference? {
            if case .structure(let ref) = model.session.focus { return ref }
            return nil
        }
        guard let space = focused else { return .init() }

        return .init(
            ref: space,
            layout: .group,
            header: true,
            sections: HarnessGroup.parameters(model).sections + CommandsGroup.parameters(model).sections
        )
    }
}

struct SpaceMapper: Mapper {
    static func settings(_ panel: any Panel, _ model: any Model) -> some View {
        let surface = AnySurface(panel: panel, model: model)
        return surface.render(
            surface,
            SpaceSettingsMapper.parameters(model),
            SpaceSettingsMapper.controls(model))
        .frame(maxHeight: .infinity)
        .scrollEdgeEffectStyle(.soft, for: .top)
    }

    static func outline(_ panel: any Panel, _ model: any Model) -> some View {
        let surface = AnySurface(panel: panel, model: model)
        return surface.render(
            surface,
            SpaceOutlineMapper.parameters(model),
            SpaceOutlineMapper.controls(model))
        .frame(maxHeight: .infinity)
        .scrollEdgeEffectStyle(.soft, for: .top)
    }
}
