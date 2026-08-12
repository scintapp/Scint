import SwiftUI


struct MaterialGroup: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                if let entry = item.entryId { return model.session.selected.selected(ref, entry) }
                return model.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                model.select(ref, entry: item.entryId, url: item.path)
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        func item(for block: Material.Block, owner: Reference) -> ItemParams {
            let icon = Iconography.icon(for: block)

            switch block {
                case .artifact(let ref), .command(let ref):
                    return .init(
                        ref: ref,
                        origin: owner,
                        name: ref.descriptor.name,
                        image: icon.symbol,
                        tint: icon.tint,
                        description: ref.descriptor.description
                    )
                case .text(let id, let text):
                    return .init(
                        ref: owner,
                        origin: owner,
                        entryId: id,
                        name: text,
                        image: icon.symbol,
                        tint: icon.tint
                    )
                case .material(let ref):
                    let children = Material.with(ref, { material in
                        material.blocks.map { item(for: $0, owner: ref) }
                    }) ?? []

                    return .init(
                        ref: ref,
                        origin: owner,
                        name: ref.descriptor.name,
                        image: icon.symbol,
                        tint: icon.tint,
                        description: ref.descriptor.description,
                        items: children
                    )
                case .task(let id, let title, _):
                    return .init(
                        ref: owner,
                        origin: owner,
                        entryId: id,
                        name: title,
                        image: icon.symbol,
                        tint: icon.tint
                    )
            }
        }

        guard case .content(let material) = model.session.focused, material.type is Material.Type
                else { return .init(layout: .group) }
        let items = Material.with(material, { value in value.blocks.map { item(for: $0, owner: material) } }) ?? []

        return .init(
            ref: material,
            name: material.descriptor.name,
            description: material.descriptor.description,
            layout: .group,
            nesting: .recursive,
            header: false,
            components: [
                .init(
                    id: "outline",
                    name: "Content Outline",
                    header: true,
                    items: items
                )
            ]
        )
    }
}

struct SpaceGroup: Mapper {
    static func controls(_ model: any Model) -> Controls {
        var space: Reference {
            if case .structure(let ref) = model.session.focused { return ref }
            else { return model.session.origin }
        }

        func add(_ ref: Reference) {
            if space.type is Workspace.Type { Workspace.with(space, { $0 })?.add(ref) }
            else { Space.with(space, { $0 })?.add(ref) }
        }

        func remove(_ ref: Reference) {
            if space.type is Workspace.Type { Workspace.with(space, { $0 })?.remove(ref) }
            else { Space.with(space, { $0 })?.remove(ref) }
        }

        func configure(_ value: Value?, for key: String) {
            if space.type is Workspace.Type { Workspace.with(space, { $0 })?.configure(value, for: key) }
            else { Space.with(space, { $0 })?.configure(value, for: key) }
        }

        return .init(
            onToggle: { item in
                guard let key = item.key else { return }
                configure(.bool(!item.active), for: key)
            },
            onChange: { item, selection in
                guard let key = item.key else { return }
                configure(selection.value.map(Value.string), for: key)
            },
            onValueChange: { item, value in
                guard let key = item.key else { return }
                configure(value.isEmpty ? nil : .string(value), for: key)
            },
            onSelect: { item in
                guard let ref = item.ref, !item.active else { return }
                add(ref)
            },
            onAction: { item in
                if let ref = item.ref, ref.type is Harness.Type {
                    if space.type is Workspace.Type { Workspace.update(space) { $0.harness = ref } }
                    else { Space.update(space) { $0.harness = ref } }
                    return
                }

                if let ref = item.ref, ref.type is Command.Type || ref.type is Artifact.Type {
                    remove(ref)
                    return
                }

                let panel = NSOpenPanel()
                panel.title = "Add Files or Folders"
                panel.prompt = "Add"
                panel.canChooseFiles = true
                panel.canChooseDirectories = true
                panel.allowsMultipleSelection = true
                guard panel.runModal() == .OK else { return }
                for url in panel.urls {
                    let artifact = Artifact.register(url.lastPathComponent, url)
                    if space.type is Workspace.Type { Workspace.with(space, { $0 })?.add(artifact) }
                    else { Space.with(space, { $0 })?.add(artifact) }
                }
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        var space: Reference {
            if case .structure(let ref) = model.session.focused { return ref }
            else { return model.session.origin }
        }

        let commands = Space.with(space, { $0.commands }) ?? Workspace.with(space, { $0.commands }) ?? []
        let harnesses = Space.with(space, { $0.harnesses }) ?? Workspace.with(space, { $0.harnesses }) ?? []
        let harness = Space.with(space, { $0.harness }).flatMap { $0 } ?? Workspace.with(space, { $0.harness })
        let config = Space.with(space, { $0.config }) ?? Workspace.with(space, { $0.config }) ?? [:]
        let parameters = harness.flatMap { Harness.with($0, { $0.parameters }) } ?? []

        let executionItems = parameters.compactMap { parameter -> ItemParams? in
            guard case .argument(let key, let type, let required, let defaultValue) = parameter,
                  !required,
                  key != "continuation"
                    else { return nil }

            let configured = config[key]
            let selected = configured?.rendered.last ?? ""
            let choices = options(type)
            if !choices.isEmpty {
                var items = choices.compactMap { value -> ItemParams? in
                    guard let rendered = value.rendered.last, !rendered.isEmpty else { return nil }
                    return .init(name: label(rendered), value: rendered)
                }
                if !selected.isEmpty, !items.contains(where: { $0.value == selected }) {
                    items.append(.init(name: label(selected), value: selected))
                }
                return .init(
                    key: key,
                    name: label(key),
                    image: "slider.horizontal.3",
                    tint: Design.Tint.command,
                    trailingKind: .picker,
                    value: selected,
                    items: [.init(name: "Default")] + items
                )
            }

            switch leaf(type) {
                case .bool:
                    let active = if case .bool(let value) = configured {
                        value
                    } else if let defaultValue, case .bool(let value) = leaf(defaultValue) {
                        value
                    } else {
                        false
                    }
                    return .init(
                        key: key,
                        name: label(key),
                        image: "switch.2",
                        tint: Design.Tint.command,
                        trailingKind: .toggle,
                        active: active
                    )
                case .string, .integer, .decimal:
                    return .init(
                        key: key,
                        name: label(key),
                        image: "slider.horizontal.3",
                        tint: Design.Tint.command,
                        trailingKind: .field,
                        value: selected
                    )
                case .sequence, .collection, .reference:
                    return nil
            }
        }

        func options(_ value: Value) -> [Value] {
            switch value {
                case .collection(let values) where values.count == 1:
                    return values.values.first.map(options) ?? []
                case .sequence(let values) where values.count > 1:
                    return values
                default:
                    return []
            }
        }

        func leaf(_ value: Value) -> Value {
            switch value {
                case .collection(let values) where values.count == 1:
                    return values.values.first.map(leaf) ?? value
                case .sequence(let values) where values.count > 1:
                    return values.first.map(leaf) ?? value
                default:
                    return value
            }
        }

        func label(_ value: String) -> String {
            value.reduce(into: "") { label, character in
                if character == "-" || character == "_" { label.append(" ") }
                else {
                    if character.isUppercase, !label.isEmpty { label.append(" ") }
                    label.append(character)
                }
            }
        }

        let artifacts = (Space.with(space, { $0.artifacts }) ?? Workspace.with(space, { $0.artifacts }) ?? [])
            .filter { ref in
                Artifact.with(ref) { artifact in
                    switch artifact.handler {
                        case .app, .directory, .file, .image, .script, .skill, .executable: true
                        case .bookmark: false
                    }
                }!
            }.map { ref in
                ItemParams(
                    ref: ref,
                    name: ref.descriptor.name,
                    trailingKind: .remove
                )
            }

        let library = Runtime.shared.all(as: Harness.self)
            .map { $0.0 }
            .sorted {
                $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending
            }
            .map { ref in
                let icon = Iconography.icon(for: ref)
                return ItemParams(
                    ref: ref,
                    name: ref.descriptor.name,
                    image: icon.symbol,
                    tint: icon.tint,
                    description: ref.descriptor.description,
                    active: harnesses.contains(ref)
                )
            }

        let loaded = harnesses
            .sorted {
                $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending
            }
            .map { ref in
                let icon = Iconography.icon(for: ref)
                return ItemParams(
                    ref: ref,
                    name: ref.descriptor.name,
                    image: icon.symbol,
                    tint: icon.tint,
                    trailingKind: ref == harness ? .value : .action,
                    value: ref == harness ? "Active" : "Activate",
                    description: ref.descriptor.description
                )
            }

        let commandLibrary = Runtime.shared.all(as: Command.self)
            .map { $0.0 }
            .sorted {
                $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending
            }
            .map { ref in
                let icon = Iconography.icon(for: ref)
                return ItemParams(
                    ref: ref,
                    name: ref.descriptor.name,
                    image: icon.symbol,
                    tint: icon.tint,
                    description: ref.descriptor.description,
                    active: commands.contains(ref)
                )
            }

        let loadedCommands = commands
            .sorted {
                $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending
            }
            .map { ref in
                let icon = Iconography.icon(for: ref)
                return ItemParams(
                    ref: ref,
                    name: ref.descriptor.name,
                    image: icon.symbol,
                    tint: icon.tint,
                    trailingKind: .remove,
                    description: ref.descriptor.description
                )
            }

        let commandLoaderIcon = Iconography.Icon(symbol: "switch.2", tint: Design.Tint.command)

        let loaderIcon = Iconography.Icon(symbol: "gear.badge.checkmark", tint: Design.Tint.command)

        var components: [SectionParams] = [
            .init(
                id: "harnesses",
                name: "Harnesses",
                items: [
                    .init(
                        name: "Add Harness...",
                        image: loaderIcon.symbol,
                        tint: loaderIcon.tint,
                        trailingKind: .load,
                        items: library
                    )
                ] + loaded
            ),
            .init(
                id: "commands",
                name: "Commands",
                items: [
                    .init(
                        name: "Add Command...",
                        image: commandLoaderIcon.symbol,
                        tint: commandLoaderIcon.tint,
                        trailingKind: .load,
                        items: commandLibrary
                    )
                ] + loadedCommands
            ),
        ]

        components.append(
            .init(
                id: "files",
                name: "Files & Folders",
                items: [
                    .init(
                        key: "add-files",
                        name: "Add Files...",
                        image: "folder.badge.plus",
                        tint: Design.Tint.artifact,
                        trailingKind: .button
                    )
                ] + artifacts
            )
        )

        if !executionItems.isEmpty {
            components.append(.init(id: "execution", name: "Execution", items: executionItems))
        }

        return .init(
            ref: space,
            name: space.descriptor.name,
            description: space.descriptor.description,
            layout: .group,
            header: false,
            components: components
        )
    }
}
