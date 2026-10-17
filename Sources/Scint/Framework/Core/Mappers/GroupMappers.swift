import SwiftUI
import ScintRuntime
import ScintComponents


extension Arg {
    static func label(_ text: String) -> String {
        text.trimmingCharacters(in: CharacterSet(charactersIn: "-=")).reduce(into: "") { label, character in
            if character == "-" || character == "_" { label.append(" ") }
            else {
                if character.isUppercase, !label.isEmpty { label.append(" ") }
                label.append(character)
            }
        }.capitalized
    }

    static func clock(_ key: String) -> Bool { key.lowercased().contains("time") }

    static func title(_ key: String) -> String {
        label(key).lowercased().split(separator: " ").reversed().lazy.compactMap { word -> String? in
            switch true {
                case word.hasPrefix("effort"): "Effort"
                case word.hasPrefix("sandbox"), word.hasPrefix("permission"): "Sandbox"
                case word.hasPrefix("model"): "Model"
                default: nil
            }
        }.first ?? label(key)
    }

    static func symbol(_ key: String) -> String {
        label(key).lowercased().split(separator: " ").reversed().lazy.compactMap { word -> String? in
            switch true {
                case word.hasPrefix("dir"), word.hasPrefix("folder"), word.hasPrefix("path"): "folder"
                case word.hasPrefix("timeout"), word.hasPrefix("interval"), word.hasPrefix("latency"): "timer"
                case word.hasPrefix("time"): "clock"
                case word.hasPrefix("model"): "cpu"
                case word.hasPrefix("effort"): "lightbulb.max"
                case word.hasPrefix("sandbox"), word.hasPrefix("permission"): "lock.shield"
                case word.hasPrefix("command"), word == "action": "switch.2"
                case word.hasPrefix("target"), word.hasPrefix("space"): "target"
                case word.hasPrefix("schedule"), word.hasPrefix("date"), word == "at", word == "when": "calendar"
                case word.hasPrefix("repeat"), word.hasPrefix("every"): "repeat"
                case word.hasPrefix("url"), word.hasPrefix("endpoint"): "link"
                case word.hasPrefix("event"): "bolt"
                case word.hasPrefix("label"), word.hasPrefix("name"): "tag"
                case word.hasPrefix("check"), word.hasPrefix("query"): "magnifyingglass"
                default: nil
            }
        }.first ?? "slider.horizontal.3"
    }
}

struct FilesGroup: Mapper {
    static func controls(_ model: any Model) -> Controls {
        guard let space = model.session.focus.ref else { return .init() }

        return .init(
            onAction: { item in
                if let ref = item.ref, ref.type is Command.Type || ref.type is Artifact.Type {
                    Space.update(space) { $0.remove(ref) }
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
                    Space.update(space) { $0.add(artifact) }
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

        func item(_ ref: Reference) -> ItemParams {
            let icon = Iconography.icon(for: ref)
            return .init(
                ref: ref,
                name: ref.descriptor.name,
                image: icon.symbol,
                tint: Style.Foreground.secondary,
                trailingKind: .remove,
                description: ref.descriptor.description
            )
        }

        let loaded = Space.with(space, { $0.artifacts }) ?? []

        return .init(
            ref: space,
            layout: .group,
            header: false,
            sections: [
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
                    ] + sorted(loaded.filter(file)).map(item)
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
                Space.update(space) { $0.add(ref) }
            },
            onAction: { item in
                if let ref = item.ref, ref.type is Command.Type || ref.type is Artifact.Type {
                    Space.update(space) { $0.remove(ref) }
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
                    Space.update(space) { $0.add(artifact) }
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
            Document.update(ref) { $0.header.argument(value, key, for: command) }
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
        guard let ref = document(model), let document = Document.with(ref, { $0 }), let interface = Space.with(document.origin, { $0.interface })
        else { return .init() }

        func all<T: Resolvable>(_ type: T.Type) -> [Reference] { Runtime.shared.all(as: type).map { $0.0 } }

        func item(_ arg: Arg) -> ItemParams? {
            let spec: (name: String, fallback: Value?, kind: ItemParams.TrailingKind, choices: [String])? = switch arg {
                case .flag(let name, let enabled): (name, .property(.bool(enabled)), .toggle, [])
                case .text(let name, let value, false): (name, value.map { .property(.string($0)) }, .field, [])
                case .date(let name, let value, false): (name, value.map { .date($0) }, Arg.clock(name) ? .time : .date, [])
                case .options(let name, let choices, let value): (name, value.map { .property(.string($0)) }, .picker, choices)
                case .range(let name, let choices, let value): (name, value.map { .property(.string($0)) }, .range, choices)
                default: nil
            }

            guard let spec else { return nil }
            let value = document.values(interface)[spec.name]
            let resting = value ?? spec.fallback
            let choices = spec.choices.map { ItemParams(key: spec.name, origin: interface, name: Arg.label($0), value: $0) }

            let active = switch spec.kind {
                case .toggle: resting == .property(true)
                case .date, .time: value != nil
                default: true
            }

            return .init(
                key: spec.name,
                origin: interface,
                name: Arg.title(spec.name),
                image: value?.references.first.map { Iconography.icon(for: $0).symbol } ?? Arg.symbol(spec.name),
                tint: Style.Foreground.secondary,
                trailingKind: spec.kind,
                value: resting?.rendered.last ?? "",
                description: value?.references.first?.descriptor.name ?? value.map { Arg.label($0.title) } ?? "Default",
                active: active,
                items: choices
            )
        }

        let values = document.values(interface)
        let intent: Intent? = if case .property(.string(let raw))? = values["intent"] { Intent(rawValue: raw) } else { document.origin.context?.intent }
        let command = values["command"]?.references.first ?? intent.flatMap { intent in Interface.with(interface, { intent.method(of: $0)?.command }) ?? nil }

        var items: [ItemParams] { (command.flatMap { Command.with($0, { $0.arguments }) } ?? []).compactMap(item) }

        return .init(
            ref: document.origin,
            layout: .group,
            header: false,
            sections: items.isEmpty ? [] : [
                .init(
                    id: "interface-settings",
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

        func configure(_ value: Value?, for key: String) {
            guard let interface = Space.with(space, { $0.interface }), let input = Space.with(space, { $0.input }) else { return }
            Document.update(input) { $0.header.argument(value, key, for: interface) }
        }

        return .init(
            onChange: { item, selection in
                guard item.key == "intent" else { return }
                configure(selection.value.map { .property(.string($0)) }, for: "intent")
            },
            onSelect: { item in
                guard item.key == "command" else { return }
                configure(item.ref.map(Value.reference), for: "command")
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        guard case .structure(let space) = model.session.focus else { return .init() }

        let interface = Space.with(space, { $0.interface })
        let config: [String: Value] = interface.flatMap { interface in Space.with(space, { $0.input }).flatMap { Document.with($0, { $0.values(interface) }) } } ?? [:]
        let provider = config["command"]?.references.first
        let intent: Intent? = if case .property(.string(let raw))? = config["intent"] { Intent(rawValue: raw) } else { nil }

        let providers = Runtime.shared.all(as: Command.self)
            .map { $0.0 }
            .filter { $0.descriptor.tags.contains("provider") }
            .sorted { $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending }

        let mode = ItemParams(
            key: "intent",
            name: "Intent",
            image: "gearshape",
            tint: Style.Foreground.secondary,
            trailingKind: .picker,
            value: intent?.rawValue,
            description: intent?.forms.label ?? "Automatic",
            items: [ItemParams(key: "intent", name: "Automatic", image: Iconography.dotSymbol, tint: Style.Foreground.secondary, active: intent == nil)]
                + Intent.allCases.filter { $0 != .none }.map { option in
                    ItemParams(
                        key: "intent",
                        name: option.forms.label,
                        image: Iconography.dotSymbol,
                        tint: Iconography.icon(for: option).tint,
                        value: option.rawValue,
                        active: option == intent
                    )
                }
        )

        let source = ItemParams(
            ref: provider,
            key: "command",
            name: "Provider",
            image: provider.map { Iconography.icon(for: $0).symbol } ?? "switch.2",
            tint: Style.Foreground.secondary,
            trailingKind: .load,
            description: provider?.descriptor.name ?? "Default",
            items: providers.map { ref in
                ItemParams(
                    ref: ref,
                    key: "command",
                    name: ref.descriptor.name,
                    image: Iconography.icon(for: ref).symbol,
                    tint: Style.Foreground.secondary,
                    description: ref.descriptor.description,
                    active: ref == provider
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
                    id: "interface",
                    name: "Interface",
                    header: false,
                    tint: Style.Foreground.secondary,
                    items: [mode, source]
                )
            ]
        )
    }
}
