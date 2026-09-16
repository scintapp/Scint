import SwiftUI


struct MaterialsGroup: Query {
    static func controls(_ model: any Model) -> Controls {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                if let entry = item.entryId { return model.session.selection.selected(ref, entry) }
                return model.session.selection.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                model.select(ref, entry: item.entryId, url: item.path)
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        func item(for block: Material.Block, origin: Reference) -> ItemParams {
            let icon = Iconography.icon(for: block)

            switch block {
                case .artifact(let ref), .command(let ref):
                    return .init(
                        ref: ref,
                        origin: origin,
                        name: ref.descriptor.name,
                        image: icon.symbol,
                        tint: Style.Foreground.subtle,
                        description: ref.descriptor.description
                    )
                case .text(let id, let text):
                    return .init(
                        ref: origin,
                        origin: origin,
                        entryId: id,
                        name: text,
                        image: icon.symbol,
                        tint: Style.Foreground.primary
                    )
                case .material(let ref):
                    let children = Material.with(ref, { material in
                        material.blocks.map { item(for: $0, origin: ref) }
                    }) ?? []

                    return .init(
                        ref: ref,
                        origin: origin,
                        name: ref.descriptor.name,
                        image: icon.symbol,
                        tint: Style.Foreground.subtle,
                        description: ref.descriptor.description,
                        items: children
                    )
                case .task(let id, let title, _):
                    return .init(
                        ref: origin,
                        origin: origin,
                        entryId: id,
                        name: title,
                        image: icon.symbol,
                        tint: Style.Foreground.subtle
                    )
            }
        }

        guard case .content(let material) = model.session.focus, material.type is Material.Type
                else { return .init(layout: .group) }
        let items = Material.with(material, { value in value.blocks.map { item(for: $0, origin: material) } }) ?? []

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

struct ArtifactsGroup: Query {
    static func controls(_ model: any Model) -> Controls {
        var focused: Reference? {
            if case .structure(let ref) = model.session.focus { return ref }
            else { return model.session.space }
        }
        guard let space = focused else { return .init() }

        func add(_ ref: Reference) {
            Space.with(space, { $0 })?.add(ref)
        }

        func remove(_ ref: Reference) {
            Space.with(space, { $0 })?.remove(ref)
            
        }

        func configure(_ value: Value?, for key: String) {
            Space.with(space, { $0 })?.configure(value, for: key)
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
                    Space.update(space) { $0.harness = ref }
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
                    Space.with(space, { $0 })?.add(artifact)
                }
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        var focused: Reference? {
            if case .structure(let ref) = model.session.focus { return ref }
            else { return model.session.space }
        }
        guard let space = focused else { return .init() }

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
                tint: Style.Foreground.subtle,
                trailingKind: trailingKind,
                description: ref.descriptor.description,
                active: active
            )
        }

        let loaded = Space.with(space, { $0.artifacts }) ?? []
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
                            tint: Style.Foreground.subtle,
                            trailingKind: .load,
                            items: library.map { item($0, active: loaded.contains($0)) }
                        )
                    ] + sorted(loaded.filter { !file($0) }).map { item($0, trailingKind: .remove) }
                ),
                .init(
                    id: "files",
                    name: "Folders",
                    items: [
                        .init(
                            key: "add-files",
                            name: "Add Files...",
                            image: "folder.badge.plus",
                            tint: Style.Foreground.subtle,
                            trailingKind: .button
                        )
                    ] + sorted(loaded.filter(file)).map { item($0, trailingKind: .remove) }
                )
            ]
        )
    }
}

struct CommandsGroup: Query {
    static func controls(_ model: any Model) -> Controls {
        var focused: Reference? {
            if case .structure(let ref) = model.session.focus { return ref }
            else { return model.session.space }
        }
        guard let space = focused else { return .init() }

        func add(_ ref: Reference) {
            Space.with(space, { $0 })?.add(ref)
        }

        func remove(_ ref: Reference) {
            Space.with(space, { $0 })?.remove(ref)
        }

        func configure(_ value: Value?, for key: String) {
            Space.with(space, { $0 })?.configure(value, for: key)
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
                    Space.update(space) { $0.harness = ref }
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
                    Space.with(space, { $0 })?.add(artifact)
                }
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        var focused: Reference? {
            if case .structure(let ref) = model.session.focus { return ref }
            else { return model.session.space }
        }
        guard let space = focused else { return .init() }

        let commands = Space.with(space, { $0.commands }) ?? []

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
                    tint: Style.Foreground.subtle,
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
                    tint: Style.Foreground.subtle,
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
                            tint: Style.Foreground.subtle,
                            trailingKind: .load,
                            items: commandLibrary
                        )
                    ] + loadedCommands
                )
            ]
        )
    }
}

struct HarnessGroup: Query {
    static func controls(_ model: any Model) -> Controls {
        var focused: Reference? {
            if case .structure(let ref) = model.session.focus { return ref }
            else { return model.session.space }
        }
        guard let space = focused else { return .init() }

        func load(_ ref: Reference) {
            Space.update(space) { $0.harness = ref }
        }

        func configure(_ value: Value?, for key: String) {
            Space.with(space, { $0 })?.configure(value, for: key)
        }

        func gate(_ item: ItemParams, _ key: String) {
            guard !item.active else { return configure(nil, for: key) }

            let opening = item.trailingKind == .time
                ? Calendar.current.date(bySetting: .minute, value: 0, of: .now.addingTimeInterval(3600)) ?? .now
                : Date.now

            configure(.string(Value.formatter.string(from: opening)), for: key)
        }

        func choose(_ item: ItemParams, _ key: String) {
            let resting = item.value ?? ""
            let panel = NSOpenPanel()
            panel.title = "Choose Folder"
            panel.prompt = "Choose"
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.canCreateDirectories = true
            panel.allowsMultipleSelection = false
            panel.directoryURL = resting.isEmpty ? nil : URL(fileURLWithPath: resting)
            guard panel.runModal() == .OK, let url = panel.url else { return }
            configure(.string(url.path(percentEncoded: false)), for: key)
        }

        return .init(
            onToggle: { item in
                guard let key = item.key else { return }
                switch item.trailingKind {
                    case .date, .time: gate(item, key)
                    default: configure(.bool(!item.active), for: key)
                }
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
            },
            onAction: { item in
                guard let key = item.key, item.trailingKind == .action else { return }
                choose(item, key)
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        var focused: Reference? {
            if case .structure(let ref) = model.session.focus { return ref }
            else { return model.session.space }
        }
        guard let space = focused else { return .init() }

        let selectedHarness = Space.with(space, { $0.harness }).flatMap { $0 }
        let declaration = selectedHarness.flatMap { ref in
            Harness.with(ref) { harness in
                (ref: ref, intent: harness.intent, parameters: harness.parameters)
            }
        }
        let harness = declaration?.ref
        let config = Space.with(space, { $0.config }) ?? [:]
        let parameters: [Harness.Parameter]
        if let declaration, declaration.intent == .evaluate || declaration.intent == .observe {
            parameters = declaration.parameters
        } else {
            parameters = []
        }

        let settingItems = parameters.compactMap { parameter -> ItemParams? in
            guard case .argument(let key, let type, let required, let defaultValue) = parameter,
                  !required
                    else { return nil }

            let configured = config[key]

            if let references = referenceOptions(type) {
                let selectedRef = configured?.references.first
                let icon = selectedRef.map { Iconography.icon(for: $0) }

                let items = references.map { ref in
                    let icon = Iconography.icon(for: ref)
                    return ItemParams(
                        ref: ref,
                        key: key,
                        name: ref.descriptor.name,
                        image: icon.symbol,
                        tint: Style.Foreground.subtle,
                        description: ref.descriptor.description,
                        active: ref == selectedRef
                    )
                }

                return .init(
                    ref: selectedRef,
                    key: key,
                    name: label(key),
                    image: icon?.symbol ?? symbol(key),
                    tint: Style.Foreground.subtle,
                    trailingKind: .load,
                    description: selectedRef?.descriptor.name ?? "",
                    items: [
                        .init(
                            key: key,
                            name: "Default",
                            image: "circle.dashed",
                            tint: Style.Foreground.subtle,
                            active: selectedRef == nil
                        )
                    ] + items
                )
            }

            let ordered = scale(type)
            let resting = ordered == nil ? "" : (defaultValue.map(leaf)?.rendered.last ?? "")
            let selectedValue = configured?.rendered.last ?? resting
            let choices = ordered ?? options(type)

            if !choices.isEmpty {
                var items = choices.compactMap { value -> ItemParams? in
                    guard let rendered = value.rendered.last, !rendered.isEmpty else { return nil }
                    return .init(key: key, name: label(rendered), value: rendered)
                }

                if !selectedValue.isEmpty, !items.contains(where: { $0.value == selectedValue }) {
                    items.append(.init(key: key, name: label(selectedValue), value: selectedValue))
                }

                return .init(
                    key: key,
                    name: label(key),
                    image: symbol(key),
                    tint: Style.Foreground.muted,
                    trailingKind: ordered == nil ? .picker : .range,
                    value: selectedValue,
                    description: selectedValue.isEmpty ? "Default" : label(selectedValue),
                    items: ordered == nil ? [.init(name: "Default")] + items : items
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
                        image: symbol(key),
                        tint: Style.Foreground.muted,
                        trailingKind: .toggle,
                        active: active
                    )
                case .date:
                    return .init(
                        key: key,
                        name: label(key),
                        image: symbol(key),
                        tint: Style.Foreground.muted,
                        trailingKind: clock(key) ? .time : .date,
                        value: selectedValue,
                        active: configured != nil
                    )

                // A folder is chosen, not typed. `.action` already renders a button wired to
                // onAction, so the row needs no control of its own.
                case .string where directory(key):
                    let chosen = selectedValue.isEmpty
                        ? (defaultValue.map(leaf)?.rendered.last ?? "")
                        : selectedValue
                    return .init(
                        key: key,
                        name: label(key),
                        image: symbol(key),
                        tint: Style.Foreground.muted,
                        trailingKind: .action,
                        value: "Choose",
                        description: chosen.isEmpty
                            ? "No folder"
                            : URL(fileURLWithPath: chosen).lastPathComponent
                    )
                case .string, .integer, .decimal:
                    return .init(
                        key: key,
                        name: label(key),
                        image: symbol(key),
                        tint: Style.Foreground.muted,
                        trailingKind: .field,
                        value: selectedValue
                    )
                case .sequence, .range, .collection, .reference:
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

        func clock(_ key: String) -> Bool { key.lowercased().contains("time") }

        func directory(_ key: String) -> Bool {
            let key = key.lowercased()
            return key.contains("dir") || key.contains("folder") || key.contains("path")
        }

        func symbol(_ key: String) -> String {
            if directory(key) { return "folder" }
            if clock(key) { return "clock" }

            let key = key.lowercased()
            return switch true {
                case key.contains("model"): "cpu"
                case key.contains("reason"), key.contains("effort"): "brain"
                case key.contains("sandbox"), key.contains("permission"): "lock.shield"
                case key.contains("command"): "switch.2"
                case key.contains("target"), key.contains("space"): "square.stack"
                case key.contains("schedule"), key.contains("date"), key == "at": "calendar"
                case key.contains("repeat"), key.contains("every"): "repeat"
                case key.contains("url"), key.contains("endpoint"): "link"
                case key.contains("interval"), key.contains("latency"), key.contains("timeout"): "timer"
                case key.contains("event"): "bolt"
                case key.contains("label"), key.contains("name"): "tag"
                case key.contains("check"), key.contains("query"): "magnifyingglass"
                default: "slider.horizontal.3"
            }
        }

        func scale(_ value: Value) -> [Value]? {
            switch value {
                case .collection(let values) where values.count == 1: values.values.first.flatMap(scale)
                case .range(let values): values
                default: nil
            }
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
                case .range(let values): values.first.map(leaf) ?? value
                default: value
            }
        }

        func referenceOptions(_ value: Value) -> [Reference]? {
            let references: [Reference]
            switch value {
                case .sequence(let values) where values.isEmpty:
                    references = Runtime.shared.all(as: Space.self).map { $0.0 }
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

        let loader = ItemParams(
            ref: harness,
            name: harness == nil ? "Set Harness" : "Change Harness",
            image: "arrow.triangle.2.circlepath",
            tint: Style.Foreground.subtle,
            trailingKind: .load,
            items: Runtime.shared.all(as: Harness.self)
                .map { $0.0 }
                .sorted {
                    $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending
                }
                .map { ref in
                    return ItemParams(
                        ref: ref,
                        name: ref.descriptor.name,
                        image: "arrow.triangle.2.circlepath",
                        tint: Style.Foreground.subtle,
                        description: ref.descriptor.description,
                        active: ref == harness
                    )
                }
        )

        var sections: [SectionParams] = [
            .init(
                id: "harness",
                header: false,
                tint: Style.Foreground.subtle,
                items: [loader]
            )
        ]

        if !settingItems.isEmpty {
            sections.append(
                .init(id: "harness-settings", name: "Harness Settings", header: false, tint: Style.Foreground.subtle, items: settingItems)
            )
        }

        return .init(
            ref: space,
            name: space.descriptor.name,
            description: space.descriptor.description,
            layout: .group,
            header: false,
            sections: sections

        )
    }
}

struct SpaceSettings: Query {
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
            else { return model.session.space }
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
