import SwiftUI
import ScintRuntime
import ScintComponents


struct FilesGroup: Mapper {
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
                case .heading(let id, _, let text), .paragraph(let id, let text), .code(let id, _, let text):
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
                case .metadata:
                    return .init(
                        ref: origin,
                        origin: origin,
                        name: "Metadata",
                        image: icon.symbol,
                        tint: Style.Foreground.secondary
                    )
                case .task(let id, let title, _):
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
                    items: Document.with(document, { value in value.blocks.map { item(for: $0, origin: document) } }) ?? []
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

        guard let space = model.session.focus.ref else { return .init() }

        return .init(
            onSelect: { item in
                guard let ref = item.ref, !item.active else { return }
                Space.with(space, { $0 })?.add(ref)
            },
            onAction: { item in
                if let ref = item.ref, ref.type is Command.Type || ref.type is Artifact.Type {
                    Space.with(space, { $0 })?.remove(ref)
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
            guard let handler = Artifact.with(ref, { $0.handle }) else { return false }
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
        guard let space = model.session.focus.ref else { return .init() }

        return .init(
            focused: { item in
                guard let ref = item.ref else { return false }
                return model.session.focus.ref == ref
            },
            onSelect: { item in
                guard let ref = item.ref, !item.active else { return }
                Space.with(space, { $0 })?.add(ref)
            },
            onAction: { item in
                if let ref = item.ref, ref.type is Command.Type || ref.type is Artifact.Type {
                    Space.with(space, { $0 })?.remove(ref)
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

struct SettingsGroup: Mapper {
    static func document(_ model: any Model) -> Reference? {
        switch model.session.focus {
            case .structure(let space): Space.with(space, { $0.input })
            case .content(let ref) where ref.type is ScintRuntime.Document.Type: ref
            default: nil
        }
    }

    static func controls(_ model: any Model) -> Controls {
        guard let ref = document(model) else { return .init() }

        func configure(_ value: Value?, for item: ItemParams) {
            guard let key = item.key, let command = item.origin else { return }
            Document.update(ref) { $0.metadata(value, key, for: command) }
        }

        return .init(
            onToggle: { item in
                switch item.trailingKind {
                    case .date: configure(item.active ? nil : .date(.now), for: item)
                    case .time: configure(item.active ? nil : .date(Calendar.current.date(bySetting: .minute, value: 0, of: .now.addingTimeInterval(3600)) ?? .now), for: item)
                    default: configure(.property(.bool(!item.active)), for: item)
                }
            },
            onChange: { item, selection in configure(selection.value.map { .property(.string($0)) }, for: item) },
            onValueChange: { item, value in configure(value.isEmpty ? nil : .property(.string(value)), for: item) },
            onSelect: { item in configure(item.ref.map(Value.reference), for: item) }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        guard let ref = document(model), let document = Document.with(ref, { $0 }), let harness = document.harness
        else { return .init() }

        func all<T: Resolvable>(_ type: T.Type) -> [Reference] { Runtime.shared.all(as: type).map { $0.0 } }

        func item(_ input: (name: String, schema: Schema), of command: Reference) -> ItemParams? {
            let value = document.values(command)[input.name]
            let resting = value ?? input.schema.fallback

            let choices = input.schema.choices.compactMap(\.rendered.last).map {
                ItemParams(key: input.name, origin: command, name: Argument.label($0), value: $0)
            }

            let library: (Reference) -> [ItemParams] = { expected in
                [ItemParams(key: input.name, origin: command, name: "Default", image: "circle.dashed", tint: Style.Foreground.secondary, active: value == nil)]
                + (expected.type.map { all($0) } ?? [])
                    .sorted { $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending }
                    .map { ItemParams(ref: $0, key: input.name, origin: command, name: $0.descriptor.name, active: value?.references.first == $0) }
            }

            let trailing: (kind: ItemParams.TrailingKind, items: [ItemParams], active: Bool)

            switch input.schema.bare {
                case .bool: trailing = (.toggle, [], resting == .property(true))
                case .integer, .decimal, .string: trailing = (.field, [], true)
                case .date: trailing = (Argument.clock(input.name) ? .time : .date, [], value != nil)
                case .options: trailing = (.picker, [ItemParams(name: "Default")] + choices, true)
                case .range: trailing = (.range, choices, true)
                case .reference(let expected): trailing = (.load, library(expected), true)
                case .command(let inner):
                    guard case .reference(let expected) = inner.bare else { return nil }
                    trailing = (.load, library(expected), true)
                default: return nil
            }

            return .init(
                key: input.name,
                origin: command,
                name: Argument.label(input.name),
                image: value?.references.first.map { Iconography.icon(for: $0).symbol } ?? Argument.symbol(input.name),
                tint: Style.Foreground.secondary,
                trailingKind: trailing.kind,
                value: resting?.rendered.last ?? "",
                description: value?.references.first?.descriptor.name ?? value.map { Argument.label($0.title) } ?? "Default",
                active: trailing.active,
                items: trailing.items
            )
        }

        var items: [ItemParams] {
            [Harness.Signature.start, .update, .stop]
                .compactMap { document.command($0, of: harness) }
                .flatMap { command in
                    (Command.with(command, { $0.parameters.inputs(document.values(command)) }) ?? [])
                        .filter { !$0.schema.required }
                        .compactMap { item($0, of: command) }
                }
                .reduce(into: [ItemParams]()) { items, item in
                    if !items.contains(where: { $0.key == item.key }) { items.append(item) }
                }
        }

        return .init(
            ref: document.origin,
            layout: .group,
            header: false,
            sections: items.isEmpty ? [] : [
                .init(
                    id: "harness-settings",
                    name: "Settings",
                    header: false,
                    tint: Style.Foreground.secondary,
                    items: items
                )
            ]
        )
    }
}

struct HarnessGroup: Mapper {
    static func controls(_ model: any Model) -> Controls {
        guard case .structure(let space) = model.session.focus else { return .init() }

        func load(_ intent: Intent) {
            Space.update(space) { $0.intent = intent }
        }

        func configure(_ value: Value?, for key: String) {
            guard let harness = Space.with(space, { $0.harness }) ?? nil, let input = Space.with(space, { $0.input }) else { return }
            Document.update(input) { $0.metadata(value, key, for: harness) }
        }

        return .init(
            onChange: { item, selection in
                guard item.key == "intent", let intent = selection.value.flatMap(Intent.init(rawValue:)) else { return }
                load(intent)
            },
            onSelect: { item in
                if item.key == "intent", let intent = item.value.flatMap(Intent.init(rawValue:)), !item.active { return load(intent) }
                guard let key = item.key else { return }
                configure(item.ref.map(Value.reference), for: key)
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        guard case .structure(let space) = model.session.focus else { return .init() }

        let harness = Space.with(space, { $0.harness }) ?? nil
        let intent = Space.with(space, { $0.intent }) ?? .none
        let signatures = harness.flatMap { Harness.with($0, { $0.signatures }) } ?? [:]
        let config: [String: Value] = harness.flatMap { harness in Space.with(space, { $0.input }).flatMap { Document.with($0, { $0.values(harness) }) } } ?? [:]

        let commands = Runtime.shared.all(as: Command.self)
            .map { $0.0 }
            .filter { $0.descriptor.tags.contains("provider") }
            .sorted { $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending }

        let slots = [Harness.Signature.start, .update, .stop]
            .compactMap { signatures[$0]?.inputs.first }
            .reduce(into: [(name: String, schema: Schema)]()) { slots, slot in
                if !slots.contains(where: { $0.name == slot.name }) { slots.append(slot) }
            }

        func slot(_ input: (name: String, schema: Schema)) -> ItemParams {
            let selected = config[input.name]?.references.first
            return .init(
                ref: selected,
                key: input.name,
                name: Argument.label(input.name),
                image: selected.map { Iconography.icon(for: $0).symbol } ?? "switch.2",
                tint: Style.Foreground.secondary,
                trailingKind: .load,
                description: selected?.descriptor.name ?? (input.schema.required ? "Required" : "Default"),
                items: (input.schema.required ? [] : [.init(key: input.name, name: "Default", image: "circle.dashed", tint: Style.Foreground.secondary, active: selected == nil)])
                    + commands.map { ref in
                        ItemParams(
                            ref: ref,
                            key: input.name,
                            name: ref.descriptor.name,
                            image: Iconography.icon(for: ref).symbol,
                            tint: Style.Foreground.secondary,
                            description: ref.descriptor.description,
                            active: ref == selected
                        )
                    }
            )
        }

        let loader = ItemParams(
            ref: harness,
            key: "intent",
            name: "Intent",
            image: "gearshape",
            tint: Style.Foreground.secondary,
            trailingKind: .picker,
            value: intent.rawValue,
            description: intent.rawValue.capitalized,
            items: Intent.allCases.map { option in
                ItemParams(
                    key: "intent",
                    name: option.rawValue.capitalized,
                    image: Iconography.dotSymbol,
                    tint: Iconography.icon(for: option).tint,
                    value: option.rawValue,
                    active: option == intent
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
                    tint: Style.Foreground.secondary,
                    items: [loader] + slots.map(slot)
                )
            ]
        )
    }
}
