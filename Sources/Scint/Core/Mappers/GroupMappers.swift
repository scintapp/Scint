import SwiftUI
import ScintRuntime
import ScintComponents


struct DocumentsGroup: Mapper {
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
        func item(for block: ScintRuntime.Document.Block, origin: Reference) -> ItemParams {
            let icon = Iconography.icon(for: block)

            switch block {
                case .artifact(let ref), .command(let ref):
                    return .init(
                        ref: ref,
                        origin: origin,
                        name: ref.descriptor.name,
                        image: icon.symbol,
                        tint: Style.Foreground.secondary,
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
                case .document(let ref):
                    let children = Document.with(ref, { document in
                        document.blocks.map { item(for: $0, origin: ref) }
                    }) ?? []

                    return .init(
                        ref: ref,
                        origin: origin,
                        name: ref.descriptor.name,
                        image: icon.symbol,
                        tint: Style.Foreground.secondary,
                        description: ref.descriptor.description,
                        items: children
                    )
                case .data(let id, _):
                    return .init(
                        ref: origin,
                        origin: origin,
                        entryId: id,
                        name: "Data",
                        image: icon.symbol,
                        tint: Style.Foreground.secondary
                    )
                case .frame(let id, _):
                    return .init(
                        ref: origin,
                        origin: origin,
                        entryId: id,
                        name: "",
                        image: icon.symbol,
                        tint: Style.Foreground.secondary
                    )
                case .task(let id, let title, _, _):
                    return .init(
                        ref: origin,
                        origin: origin,
                        entryId: id,
                        name: title,
                        image: icon.symbol,
                        tint: Style.Foreground.secondary
                    )
            }
        }

        guard case .content(let document) = model.session.focus, document.type is ScintRuntime.Document.Type
                else { return .init(layout: .group) }
        let items = Document.with(document, { value in value.blocks.map { item(for: $0, origin: document) } }) ?? []

        return .init(
            ref: document,
            name: document.descriptor.name,
            description: document.descriptor.description,
            layout: .group,
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
        var focused: Reference? {
            if case .structure(let ref) = model.session.focus { return ref }
            return nil
        }
        guard let space = focused else { return .init() }

        func add(_ ref: Reference) {
            Space.with(space, { $0 })?.add(ref)
        }

        func remove(_ ref: Reference) {
            Space.with(space, { $0 })?.remove(ref)

        }

        return .init(
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
                    let artifact = Artifact.new(url.lastPathComponent, url)
                    Space.with(space, { $0 })?.add(artifact)
                }
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        var focused: Reference? {
            if case .structure(let ref) = model.session.focus { return ref }
            return nil
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
                tint: Style.Foreground.secondary,
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
                            tint: Style.Foreground.secondary,
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
                            tint: Style.Foreground.secondary,
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
        var focused: Reference? {
            if case .structure(let ref) = model.session.focus { return ref }
            return nil
        }
        guard let space = focused else { return .init() }

        func add(_ ref: Reference) {
            Space.with(space, { $0 })?.add(ref)
        }

        func remove(_ ref: Reference) {
            Space.with(space, { $0 })?.remove(ref)
        }

        return .init(
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
                    let artifact = Artifact.new(url.lastPathComponent, url)
                    Space.with(space, { $0 })?.add(artifact)
                }
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        var focused: Reference? {
            if case .structure(let ref) = model.session.focus { return ref }
            return nil
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
                    tint: Style.Foreground.secondary,
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
                    tint: Style.Foreground.secondary,
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
                            tint: Style.Foreground.secondary,
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
        var focused: Reference? {
            if case .structure(let ref) = model.session.focus { return ref }
            return nil
        }

        guard let space = focused else { return .init() }
        return controls(for: space)
    }

    static func controls(for space: Reference, owner: Reference? = nil) -> Controls {
        func load(_ ref: Reference) {
            Space.update(space) { $0.harness = ref }
        }

        func configure(_ value: Value?, for key: String) {
            if let owner, Sheet.with(owner, { _ in true }) != nil {
                var values: [String: Value] = if case .collection(let values)? = Sheet.with(owner, { $0.data }) ?? nil { values } else { [:] }
                values[key] = value
                Sheet.with(owner) { $0.data = .collection(values) }
                return
            }
            guard let owner = owner ?? (Space.with(space, { $0.harness }) ?? nil) else { return }
            Space.with(space) { space in
                var values: [String: Value] = if case .collection(let values)? = space.config[owner] { values } else { [:] }
                values[key] = value
                space.configure(.collection(values), for: owner)
            }
        }

        func hour() -> Date {
            Calendar.current.date(bySetting: .minute, value: 0, of: .now.addingTimeInterval(3600)) ?? .now
        }

        func when(_ key: String) -> When? {
            if let owner, case .collection(let values)? = Sheet.with(owner, { $0.data }) ?? nil {
                return if case .when(let when)? = values[key] { when } else { nil }
            }
            guard let owner = owner ?? (Space.with(space, { $0.harness }) ?? nil),
                  case .collection(let values)? = Space.with(space, { $0.config[owner] }) ?? nil,
                  case .when(let when)? = values[key]
            else { return nil }
            return when
        }

        func gate(_ item: ItemParams, _ key: String) {
            guard !item.active else { return configure(nil, for: key) }

            let opening = item.trailingKind == .date ? Date.now : hour()

            configure(item.trailingKind == .moment ? .when(When(opening)) : .string(Value.formatter.string(from: opening)), for: key)
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
                    case .date, .time, .moment: gate(item, key)
                    default: configure(.bool(!item.active), for: key)
                }
            },
            onChange: { item, selection in
                if let ref = selection.ref, ref.type is Harness.Type { return load(ref) }
                guard let key = item.key else { return }
                if key == "when", let repeats = selection.value.flatMap({ When.Repeat(rawValue: $0) }) {
                    guard let moment = when(key)?.date ?? (repeats == .never ? nil : hour()) else { return }
                    return configure(.when(When(moment, repeats: repeats)), for: key)
                }
                configure(selection.value.map(Value.string), for: key)
            },
            onValueChange: { item, value in
                guard let key = item.key else { return }
                if item.trailingKind == .moment, let moment = Value.formatter.date(from: value) {
                    return configure(.when(When(moment, repeats: when(key)?.repeats ?? .never)), for: key)
                }
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
            return nil
        }

        guard let space = focused else { return .init() }

        let selectedHarness = Space.with(space, { $0.harness }).flatMap { $0 }

        let declaration = selectedHarness.flatMap { ref in
            Harness.with(ref) { harness in
                (ref: ref, intent: harness.intent, commands: harness.commands, parameters: harness.parameters)
            }
        }

        let harness = declaration?.ref
        let config: [String: Value] = if let harness, case .collection(let values)? = Space.with(space, { $0.config[harness] }) ?? nil { values } else { [:] }

        func passthroughKey(_ parameter: Parameter) -> String? {
            let declared: (key: String, type: Value)? = switch parameter {
                case .argument(let key, let type, _, _), .link(let key, let type, _, _), .callback(let key, let type): (key, type)
                default: nil
            }
            guard let (key, type) = declared else { return nil }
            func accepts(_ value: Value) -> Bool {
                switch value {
                    case .reference(let ref): ref.type is Command.Type
                    case .collection(let values) where values.count == 1: values.values.first.map(accepts) ?? false
                    default: false
                }
            }
            return accepts(type) ? key : nil
        }

        let passthrough = (declaration?.parameters ?? []).filter { passthroughKey($0) != nil }
        let passthroughKeys = Set(passthrough.compactMap(passthroughKey))

        let passthroughCommand = passthroughKeys.sorted().lazy
            .compactMap { config[$0]?.references.first }
            .first

        let passthroughParameters = passthroughCommand.flatMap { Command.with($0, { $0.parameters }) } ?? []

        var seen: Set<String> = []
        let parameters = ((declaration?.parameters ?? []) + passthroughParameters).filter { parameter in
            guard case .argument(let key, _, _, _) = parameter else { return false }
            return !passthroughKeys.contains(key) && seen.insert(key).inserted
        }

        let settingItems = settings(parameters, config: config)

        let loader = ItemParams(
            ref: harness,
            key: "harness",
            name: "Harness",
            image: "gearshape",
            tint: Style.Foreground.secondary,
            trailingKind: .picker,
            value: harness?.descriptor.name ?? "",
            description: harness?.descriptor.name ?? "None",
            items: Runtime.shared.all(as: Harness.self)
                .map { $0.0 }
                .sorted {
                    $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending
                }
                .map { ref in
                    ItemParams(
                        ref: ref,
                        name: ref.descriptor.name,
                        image: Iconography.dotSymbol,
                        tint: Iconography.accent(for: ref),
                        value: ref.descriptor.name,
                        active: ref == harness
                    )
                }
        )

        func commandPicker(_ parameter: Parameter) -> ItemParams? {
            guard let key = passthroughKey(parameter) else { return nil }
            let required = if case .argument(_, _, let required, _) = parameter { required } else { true }

            let selected = config[key]?.references.first
            let icon = selected.map { Iconography.icon(for: $0) }

            // Leave out the harness's own runner and any other passthrough command, so Exec can't be handed Exec.
            let choices = Runtime.shared.all(as: Command.self)
                .map { $0.0 }
                .filter { ref in
                    guard declaration?.commands.contains(ref) != true else { return false }
                    let forwards = Command.with(ref, { $0.parameters.contains { passthroughKey($0) != nil } }) ?? false
                    return !forwards
                }
                .sorted {
                    $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending
                }
                .map { ref in
                    let icon = Iconography.icon(for: ref)
                    return ItemParams(
                        ref: ref,
                        key: key,
                        name: ref.descriptor.name,
                        image: icon.symbol,
                        tint: Style.Foreground.secondary,
                        description: ref.descriptor.description,
                        active: ref == selected
                    )
                }

            let fallback: [ItemParams] = required ? [] : [
                .init(
                    key: key,
                    name: "Default",
                    image: "circle.dashed",
                    tint: Style.Foreground.secondary,
                    active: selected == nil
                )
            ]

            return .init(
                ref: selected,
                key: key,
                name: "Command",
                image: icon?.symbol ?? "switch.2",
                tint: Style.Foreground.secondary,
                trailingKind: .load,
                description: selected?.descriptor.name ?? (required ? "Required" : "Default"),
                items: fallback + choices
            )
        }

        let commandItems = passthrough.compactMap(commandPicker)

        var sections: [SectionParams] = [
            .init(
                id: "harness",
                name: "Harness",
                header: false,
                tint: Style.Foreground.secondary,
                items: [loader] + commandItems
            )
        ]

        if !settingItems.isEmpty {
            sections.append(
                .init(id: "harness-settings", name: "Settings", header: false, tint: Style.Foreground.secondary, items: settingItems)
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

    static func settings(_ parameters: [Parameter], config: [String: Value]) -> [ItemParams] {
        func setting(_ parameter: Parameter) -> ItemParams? {
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
                        tint: Style.Foreground.secondary,
                        description: ref.descriptor.description,
                        active: ref == selectedRef
                    )
                }

                return .init(
                    ref: selectedRef,
                    key: key,
                    name: label(key),
                    image: icon?.symbol ?? Argument.symbol(key),
                    tint: Style.Foreground.secondary,
                    trailingKind: .load,
                    description: selectedRef?.descriptor.name ?? "",
                    items: [
                        .init(
                            key: key,
                            name: "Default",
                            image: "circle.dashed",
                            tint: Style.Foreground.secondary,
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
                    image: Argument.symbol(key),
                    tint: Style.Foreground.secondary,
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
                        image: Argument.symbol(key),
                        tint: Style.Foreground.secondary,
                        trailingKind: .toggle,
                        active: active
                    )
                case .date:
                    return .init(
                        key: key,
                        name: label(key),
                        image: Argument.symbol(key),
                        tint: Style.Foreground.secondary,
                        trailingKind: Argument.clock(key) ? .time : .date,
                        value: selectedValue,
                        active: configured != nil
                    )
                case .when:
                    let when: When? = if case .when(let value)? = configured { value } else { nil }
                    return .init(
                        key: key,
                        name: "Date",
                        image: Argument.symbol(key),
                        tint: Style.Foreground.secondary,
                        trailingKind: .moment,
                        value: when.map { Value.formatter.string(from: $0.date) },
                        active: when != nil
                    )

                case .string where Argument.directory(key):
                    let chosen = selectedValue.isEmpty
                    ? (defaultValue.map(leaf)?.rendered.last ?? "")
                    : selectedValue
                    return .init(
                        key: key,
                        name: label(key),
                        image: Argument.symbol(key),
                        tint: Style.Foreground.secondary,
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
                        image: Argument.symbol(key),
                        tint: Style.Foreground.secondary,
                        trailingKind: .field,
                        value: selectedValue
                    )
                case .sequence, .range, .collection, .reference:
                    return nil
            }
        }

        func repetition(_ key: String) -> ItemParams {
            let repeats: When.Repeat = if case .when(let value)? = config[key] { value.repeats } else { .never }
            return .init(
                key: key,
                name: "Repeat",
                image: Argument.symbol("repeat"),
                tint: Style.Foreground.secondary,
                trailingKind: .picker,
                value: repeats.rawValue,
                description: label(repeats.rawValue),
                items: When.Repeat.allCases.map { .init(key: key, name: label($0.rawValue), value: $0.rawValue) }
            )
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

        return parameters.compactMap(setting).flatMap { item in
            item.trailingKind == .moment ? [item, repetition(item.key ?? "")] : [item]
        }
    }
}
