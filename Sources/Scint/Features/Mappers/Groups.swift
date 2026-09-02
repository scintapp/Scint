import SwiftUI


struct MaterialsGroup: Mapper {
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
            sections: [
                .init(
                    id: "outline",
                    name: "Outline",
                    header: false,
                    items: items
                )
            ]
        )
    }
}

struct ArtifactsGroup: Mapper {
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

        func file(_ ref: Reference) -> Bool {
            guard let handler = Artifact.with(ref, { $0.handler }) else { return false }
            return handler.type == "file" || handler.type == "directory"
        }

        func sorted(_ refs: [Reference]) -> [Reference] {
            refs.sorted { $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending }
        }

        func item(_ ref: Reference, trailingKind: ItemParams.TrailingKind? = nil, active: Bool = true) -> ItemParams {
            let icon = Iconography.icon(for: ref)
            return .init(
                ref: ref,
                name: ref.descriptor.name,
                image: icon.symbol,
                tint: icon.tint,
                trailingKind: trailingKind,
                description: ref.descriptor.description,
                active: active
            )
        }

        let loaded = Space.with(space, { $0.artifacts }) ?? Workspace.with(space, { $0.artifacts }) ?? []
        let library = sorted(Runtime.shared.all(as: Artifact.self).map { $0.0 }.filter { !file($0) })

        return .init(
            ref: space,
            layout: .group,
            header: false,
            sections: [
                .init(
                    id: "artifacts",
                    name: "Artifacts",
                    items: [
                        .init(
                            key: "add-artifacts",
                            name: "Add Artifacts...",
                            image: "folder.badge.plus",
                            tint: Style.Tint.artifact,
                            trailingKind: .load,
                            items: library.map { item($0, active: loaded.contains($0)) }
                        )
                    ] + sorted(loaded.filter { !file($0) }).map { item($0, trailingKind: .remove) }
                ),
                .init(
                    id: "files",
                    name: "Files & Folders",
                    items: [
                        .init(
                            key: "add-files",
                            name: "Add Files...",
                            image: "folder.badge.plus",
                            tint: Style.Tint.artifact,
                            trailingKind: .button
                        )
                    ] + sorted(loaded.filter(file)).map { item($0, trailingKind: .remove) }
                )
            ]
        )
    }
}

struct CommandsGroup: Mapper {
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

        return .init(
            ref: space,
            name: space.descriptor.name,
            description: space.descriptor.description,
            layout: .group,
            header: false,
            sections: [
                .init(
                    id: "commands",
                    name: "Commands",
                    items: [
                        .init(
                            name: "Add Command...",
                            image: "switch.2",
                            tint: Style.Tint.command,
                            trailingKind: .load,
                            items: commandLibrary
                        )
                    ] + loadedCommands
                )
            ]
        )
    }
}

struct HarnessGroup: Mapper {
    static func controls(_ model: any Model) -> Controls {
        var space: Reference {
            if case .structure(let ref) = model.session.focused { return ref }
            else { return model.session.origin }
        }

        func load(_ ref: Reference) {
            if space.type is Workspace.Type { Workspace.update(space) { $0.harness = ref } }
            else { Space.update(space) { $0.harness = ref } }
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
                if let key = item.key {
                    configure(item.ref.map(Value.reference), for: key)
                    return
                }
                guard let ref = item.ref, ref.type is Harness.Type, !item.active else { return }
                load(ref)
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        var space: Reference {
            if case .structure(let ref) = model.session.focused { return ref }
            else { return model.session.origin }
        }

        let selectedHarness = Space.with(space, { $0.harness }).flatMap { $0 } ?? Workspace.with(space, { $0.harness }).flatMap { $0 }
        let declaration = selectedHarness.flatMap { ref in
            Harness.with(ref) { harness in
                (ref: ref, intent: harness.intent, parameters: harness.parameters)
            }
        }
        let harness = declaration?.ref
        let config = Space.with(space, { $0.config }) ?? Workspace.with(space, { $0.config }) ?? [:]
        let parameters: [Harness.Parameter]
        if let declaration, declaration.intent == .evaluate || declaration.intent == .observe {
            parameters = declaration.parameters
        } else {
            parameters = []
        }

        let settingItems = parameters.compactMap { parameter -> ItemParams? in
            guard case .argument(let key, let type, let required, let defaultValue) = parameter,
                  !required,
                  key != "continuation"
                    else { return nil }

            let configured = config[key]

            if let references = referenceOptions(type) {
                let selectedRef = configured?.references.first
                let icon = selectedRef.map { Iconography.icon(for: $0) }
                let image: String
                if case .reference = type { image = "switch.2" }
                else { image = "target" }

                let items = references.map { ref in
                    let icon = Iconography.icon(for: ref)
                    return ItemParams(
                        ref: ref,
                        key: key,
                        name: ref.descriptor.name,
                        image: icon.symbol,
                        tint: icon.tint,
                        description: ref.descriptor.description,
                        active: ref == selectedRef
                    )
                }

                return .init(
                    ref: selectedRef,
                    key: key,
                    name: label(key),
                    image: icon?.symbol ?? image,
                    tint: icon?.tint ?? Style.Tint.command,
                    trailingKind: .load,
                    description: selectedRef?.descriptor.name ?? "",
                    items: [
                        .init(
                            key: key,
                            name: "Default",
                            image: "circle.dashed",
                            tint: Style.Tint.command,
                            active: selectedRef == nil
                        )
                    ] + items
                )
            }

            let selectedValue = configured?.rendered.last ?? ""
            let choices = options(type)

            if !choices.isEmpty {
                var items = choices.compactMap { value -> ItemParams? in
                    guard let rendered = value.rendered.last, !rendered.isEmpty else { return nil }
                    return .init(name: label(rendered), value: rendered)
                }

                if !selectedValue.isEmpty, !items.contains(where: { $0.value == selectedValue }) {
                    items.append(.init(name: label(selectedValue), value: selectedValue))
                }

                return .init(
                    key: key,
                    name: label(key),
                    image: "slider.horizontal.3",
                    tint: Style.Tint.command,
                    trailingKind: .picker,
                    value: selectedValue,
                    items: [.init(name: "Default")] + items
                )
            }

            switch leaf(type) {
                case .bool:
                    let active = if case .bool(let value) = configured { value }
                    else if let defaultValue, case .bool(let value) = leaf(defaultValue) { value }
                    else { false }
                    return .init(
                        key: key,
                        name: label(key),
                        image: "switch.2",
                        tint: Style.Tint.command,
                        trailingKind: .toggle,
                        active: active
                    )
                case .date:
                    return .init(
                        key: key,
                        name: label(key),
                        image: "calendar",
                        tint: Style.Tint.command,
                        trailingKind: .date,
                        value: selectedValue
                    )
                case .string, .integer, .decimal:
                    return .init(
                        key: key,
                        name: label(key),
                        image: "slider.horizontal.3",
                        tint: Style.Tint.command,
                        trailingKind: .field,
                        value: selectedValue
                    )
                case .sequence, .collection, .reference:
                    return nil
            }
        }

        func label(_ value: String) -> String {
            value.reduce(into: "") { label, character in
                if character == "-" || character == "_" { label.append(" ") }
                else {
                    if character.isUppercase, !label.isEmpty { label.append(" ") }
                    label.append(character)
                }
            }.capitalized
        }

        func options(_ value: Value) -> [Value] {
            switch value {
                case .collection(let values) where values.count == 1: values.values.first.map(options) ?? []
                case .sequence(let values) where values.count > 1: values
                default: []
            }
        }

        func leaf(_ value: Value) -> Value {
            switch value {
                case .collection(let values) where values.count == 1: values.values.first.map(leaf) ?? value
                case .sequence(let values) where values.count > 1: values.first.map(leaf) ?? value
                default: value
            }
        }

        func referenceOptions(_ value: Value) -> [Reference]? {
            let references: [Reference]
            switch value {
                case .sequence(let values) where values.isEmpty:
                    references = Runtime.shared.all(as: Workspace.self).map { $0.0 }
                        + Runtime.shared.all(as: Space.self).map { $0.0 }
                case .reference(let ref) where ref.type is Command.Type:
                    references = Runtime.shared.all(as: Command.self).map { $0.0 }
                case .reference:
                    return nil
                default:
                    return nil
            }

            return references.sorted {
                $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending
            }
        }

        let loaderIcon = harness.map { Iconography.icon(for: $0) }
        let loader = ItemParams(
            ref: harness,
            name: harness?.descriptor.name ?? "Load Harness...",
            image: loaderIcon?.symbol ?? "gearshape",
            tint: loaderIcon?.tint ?? Style.Tint.command,
            trailingKind: .load,
            description: harness?.descriptor.description ?? "",
            items: Runtime.shared.all(as: Harness.self)
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
                        active: ref == harness
                    )
                }
        )

        return .init(
            ref: space,
            name: space.descriptor.name,
            description: space.descriptor.description,
            layout: .group,
            header: false,
            sections: [
                .init(
                    id: "harness",
                    name: "Harness",
                    header: false,
                    items: [loader] + settingItems
                )
            ]
        )
    }
}

//struct OldHarnessGroup: Mapper {
//    static func controls(_ model: any Model) -> Controls {
//        var space: Reference {
//            if case .structure(let ref) = model.session.focused { return ref }
//            else { return model.session.origin }
//        }
//
//        func add(_ ref: Reference) {
//            if space.type is Workspace.Type { Workspace.with(space, { $0 })?.add(ref) }
//            else { Space.with(space, { $0 })?.add(ref) }
//        }
//
//        func remove(_ ref: Reference) {
//            if space.type is Workspace.Type { Workspace.with(space, { $0 })?.remove(ref) }
//            else { Space.with(space, { $0 })?.remove(ref) }
//        }
//
//        func configure(_ value: Value?, for key: String) {
//            if space.type is Workspace.Type { Workspace.with(space, { $0 })?.configure(value, for: key) }
//            else { Space.with(space, { $0 })?.configure(value, for: key) }
//        }
//
//        return .init(
//            onToggle: { item in
//                guard let key = item.key else { return }
//                configure(.bool(!item.active), for: key)
//            },
//            onChange: { item, selection in
//                guard let key = item.key else { return }
//                configure(selection.value.map(Value.string), for: key)
//            },
//            onValueChange: { item, value in
//                guard let key = item.key else { return }
//                configure(value.isEmpty ? nil : .string(value), for: key)
//            },
//            onSelect: { item in
//                guard let ref = item.ref, !item.active else { return }
//                add(ref)
//            },
//            onAction: { item in
//                if let ref = item.ref, ref.type is Harness.Type {
//                    if space.type is Workspace.Type { Workspace.update(space) { $0.harness = ref } }
//                    else { Space.update(space) { $0.harness = ref } }
//                    return
//                }
//
//                if let ref = item.ref, ref.type is Command.Type || ref.type is Artifact.Type {
//                    remove(ref)
//                    return
//                }
//
//                let panel = NSOpenPanel()
//                panel.title = "Add Files or Folders"
//                panel.prompt = "Add"
//                panel.canChooseFiles = true
//                panel.canChooseDirectories = true
//                panel.allowsMultipleSelection = true
//                guard panel.runModal() == .OK else { return }
//                for url in panel.urls {
//                    let artifact = Artifact.register(url.lastPathComponent, url)
//                    if space.type is Workspace.Type { Workspace.with(space, { $0 })?.add(artifact) }
//                    else { Space.with(space, { $0 })?.add(artifact) }
//                }
//            }
//        )
//    }
//
//    static func parameters(_ model: any Model) -> Params {
//        var space: Reference {
//            if case .structure(let ref) = model.session.focused { return ref }
//            else { return model.session.origin }
//        }
//
//        let harnesses = Space.with(space, { $0.harnesses }) ?? Workspace.with(space, { $0.harnesses }) ?? []
//        let harness = Space.with(space, { $0.harness }).flatMap { $0 } ?? Workspace.with(space, { $0.harness }).flatMap { $0 }
//        let config = Space.with(space, { $0.config }) ?? Workspace.with(space, { $0.config }) ?? [:]
//        let parameters = harness.flatMap { Harness.with($0, { $0.parameters }) } ?? []
//
//        let executionItems = parameters.compactMap { parameter -> ItemParams? in
//            guard case .argument(let key, let type, let required, let defaultValue) = parameter,
//                  !required,
//                  key != "continuation"
//                    else { return nil }
//
//            let configured = config[key]
//            let selected = configured?.rendered.last ?? ""
//            let choices = options(type)
//            if !choices.isEmpty {
//                var items = choices.compactMap { value -> ItemParams? in
//                    guard let rendered = value.rendered.last, !rendered.isEmpty else { return nil }
//                    return .init(name: label(rendered), value: rendered)
//                }
//                if !selected.isEmpty, !items.contains(where: { $0.value == selected }) {
//                    items.append(.init(name: label(selected), value: selected))
//                }
//                return .init(
//                    key: key,
//                    name: label(key),
//                    image: "slider.horizontal.3",
//                    tint: Style.Tint.command,
//                    trailingKind: .picker,
//                    value: selected,
//                    items: [.init(name: "Default")] + items
//                )
//            }
//
//            switch leaf(type) {
//                case .bool:
//                    let active = if case .bool(let value) = configured {
//                        value
//                    } else if let defaultValue, case .bool(let value) = leaf(defaultValue) {
//                        value
//                    } else {
//                        false
//                    }
//                    return .init(
//                        key: key,
//                        name: label(key),
//                        image: "switch.2",
//                        tint: Style.Tint.command,
//                        trailingKind: .toggle,
//                        active: active
//                    )
//                case .date:
//                    return .init(
//                        key: key,
//                        name: label(key),
//                        image: "calendar",
//                        tint: Style.Tint.command,
//                        trailingKind: .date,
//                        value: selected
//                    )
//                case .string, .integer, .decimal:
//                    return .init(
//                        key: key,
//                        name: label(key),
//                        image: "slider.horizontal.3",
//                        tint: Style.Tint.command,
//                        trailingKind: .field,
//                        value: selected
//                    )
//                case .sequence, .collection, .reference:
//                    return nil
//            }
//        }
//
//        func options(_ value: Value) -> [Value] {
//            switch value {
//                case .collection(let values) where values.count == 1:
//                    return values.values.first.map(options) ?? []
//                case .sequence(let values) where values.count > 1:
//                    return values
//                default:
//                    return []
//            }
//        }
//
//        func leaf(_ value: Value) -> Value {
//            switch value {
//                case .collection(let values) where values.count == 1:
//                    return values.values.first.map(leaf) ?? value
//                case .sequence(let values) where values.count > 1:
//                    return values.first.map(leaf) ?? value
//                default:
//                    return value
//            }
//        }
//
//        func label(_ value: String) -> String {
//            value.reduce(into: "") { label, character in
//                if character == "-" || character == "_" { label.append(" ") }
//                else {
//                    if character.isUppercase, !label.isEmpty { label.append(" ") }
//                    label.append(character)
//                }
//            }
//        }
//
//        let library = Runtime.shared.all(as: Harness.self)
//            .map { $0.0 }
//            .sorted {
//                $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending
//            }
//            .map { ref in
//                let icon = Iconography.icon(for: ref)
//                return ItemParams(
//                    ref: ref,
//                    name: ref.descriptor.name,
//                    image: icon.symbol,
//                    tint: icon.tint,
//                    description: ref.descriptor.description,
//                    active: harnesses.contains(ref)
//                )
//            }
//
//        let loaded = harnesses
//            .sorted {
//                $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending
//            }
//            .map { ref in
//                let icon = Iconography.icon(for: ref)
//                return ItemParams(
//                    ref: ref,
//                    name: ref.descriptor.name,
//                    image: icon.symbol,
//                    tint: icon.tint,
//                    trailingKind: ref == harness ? .value : .action,
//                    value: ref == harness ? "Active" : "Activate",
//                    description: ref.descriptor.description
//                )
//            }
//
//        var sections: [SectionParams] = [
//            .init(
//                id: "harness",
//                name: "Harness",
//                items: [
//                    .init(
//                        name: "Add Harness...",
//                        image: "gearshape",
//                        tint: Style.Tint.command,
//                        trailingKind: .load,
//                        items: library
//                    )
//                ] + loaded
//            )
//        ]
//
//        if !executionItems.isEmpty {
//            sections.append(
//                .init(
//                    id: "execution",
//                    name: "Execution",
//                    items: executionItems)
//            )
//        }
//
//        return .init(
//            ref: space,
//            name: space.descriptor.name,
//            description: space.descriptor.description,
//            layout: .group,
//            header: false,
//            sections: sections
//        )
//    }
//}
