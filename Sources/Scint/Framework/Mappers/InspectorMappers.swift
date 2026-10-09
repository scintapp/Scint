import SwiftUI
import ScintRuntime
import ScintComponents


struct InboxOutline: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init()
    }

    static func parameters(_ model: any Model) -> Params {
        .init()
    }
}

struct InboxSettings: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init()
    }

    static func parameters(_ model: any Model) -> Params {
        .init()
    }
}

struct ProjectOutline: Mapper {
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
            sections: FilesGroup.parameters(model).sections + ArtifactsGroup.parameters(model).sections
        )
    }
}

struct ProjectSettings: Mapper {
    static func controls(_ model: any Model) -> Controls {
        let harness = HarnessGroup.controls(model)
        let settings = SettingsGroup.controls(model)
        let commands = CommandsGroup.controls(model)
        let artifacts = ArtifactsGroup.controls(model)

        func source(for item: ItemParams) -> Controls {
            if let key = item.key {
                if key == "add-artifacts" || key == "add-files" { return artifacts }
                if item.origin?.type is Command.Type { return settings }
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
            sections: HarnessGroup.parameters(model).sections + SettingsGroup.parameters(model).sections + CommandsGroup.parameters(model).sections
        )
    }
}

struct DocumentOutline: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                if let entry = item.entryId { return model.session.selection.selected(ref, entry) }
                return model.session.selection.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                model.select(ref, entry: item.entryId)
            },
            sectionDropTarget: { section in
                let space = model.session.projects
                return .init(ref: space, name: space.descriptor.name)
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        guard let doc = model.session.selection.content, let body = Document.with(doc, { $0.body })
        else { return .init() }

        typealias Entry = (level: Int, ref: Reference, entry: UUID?, name: String, image: String)

        /// Headings by level, with the editor menu's icons. Tasks and references rank below every heading: they nest, and hold nothing.
        let entries = body.compactMap { block -> Entry? in
            switch block {
                case .heading(let id, let level, let text): (level, doc, id, text, level == 1 ? "textformat" : level == 2 ? "textformat.size" : "textformat.size.smaller")
                case .task(let id, let text, _): (.max, doc, id, text, "checkmark.app")
                default: block.reference.map { (.max, $0, nil, $0.descriptor.name, Iconography.icon(for: $0).symbol) }
            }
        }

        /// Each entry holds the ones after it that rank below it, up to the next at its level or above.
        func outline(_ entries: ArraySlice<Entry>) -> [ItemParams] {
            guard let entry = entries.first else { return [] }
            let rest = entries.dropFirst()
            let end = rest.firstIndex { $0.level <= entry.level } ?? rest.endIndex
            return [ItemParams(ref: entry.ref, entryId: entry.entry, name: entry.name, image: entry.image, items: outline(rest[..<end]))]
                + outline(rest[end...])
        }

        return .init(
            id: "outline",
            name: "Outline",
            header: false,
            sections: [
                .init(
                    id: "outline",
                    name: "Outline",
                    header: false,
                    items: outline(entries[...])
                ),
            ]
        )
    }
}

struct DocumentSettings: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                if ref.type is Transcript.Type { return model.session.transcript == ref }
                if let url = item.path { return model.session.selection.selected(ref, url) }
                return model.session.selection.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                model.select(ref)
            },
            sectionDropTarget: { section in
                let space = model.session.projects
                return .init(ref: space, name: space.descriptor.name)
            },
            itemPalette: { item in
                item.path == nil ? Action.itemItems(for: item) : []
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        guard let doc = model.session.selection.content, let blocks = Document.with(doc, { $0.blocks })
                else { return .init() }

        let blockItems = blocks.compactMap {
            switch $0 {
                case .artifact(let ref):
                    return ItemParams(ref: ref, name: ref.descriptor.name)
                case .heading(_, _, let content), .paragraph(_, let content):
                    return ItemParams(name: content)
                default:
                    return ItemParams(name: "")
            }
        }

        return .init(
            id: "outline",
            name: "Outline",
            header: false,
            sections: [
                .init(
                    id: "space",
                    name: "Workspace",
                    header: false,
                    items: blockItems
                ),
            ]
        )
    }
}

struct TaskOutline: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init()
    }

    static func parameters(_ model: any Model) -> Params {
        .init()
    }
}

struct TaskSettings: Mapper {
    static func controls(_ model: any Model) -> Controls {
        guard let task = model.session.document else { return .init() }

        let settings = SettingsGroup.controls(model)
        let own = Controls(
            onValueChange: { item, value in
                switch item.key {
                    case "note":
                        Document.update(task) { $0.insert(.paragraph(UUID(), value), at: nil) }
                    default:
                        guard let moment = Value.formatter.date(from: value) else { return }
                        Document.update(task) { $0.schedule(moment, repeats: $0.schedule.repeats) }
                }
            },
            onSelect: { item in
                switch item.key {
                    case "space":
                        Document.update(task) { document in
                            guard let metadata = document.metadata else { return }
                            document.update(.metadata(item.ref ?? document.origin, metadata.values), at: 0)
                        }
                    case "repeat":
                        Document.update(task) { $0.schedule($0.schedule.moment ?? .now, repeats: item.value.flatMap(When.Repeat.init(rawValue:)) ?? .never) }
                    case let slot?:
                        Document.update(task) { document in
                            guard let harness = document.harness, let ref = item.ref else { return }
                            document.metadata(.reference(ref), slot, for: harness)
                        }
                    default:
                        break
                }
            }
        )

        func source(for item: ItemParams) -> Controls { item.origin?.type is Command.Type ? settings : own }

        return .init(
            onToggle: { item in source(for: item).onToggle?(item) },
            onChange: { item, selection in source(for: item).onChange?(item, selection) },
            onValueChange: { item, value in source(for: item).onValueChange?(item, value) },
            onSelect: { item in source(for: item).onSelect?(item) }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        guard let task = model.session.document, let document = Document.with(task, { $0 }), document.task != nil
        else { return .init() }

        let harness = document.harness
        let command = harness.flatMap { document.command(.update, of: $0) }
        let slot = harness.flatMap { harness in Harness.with(harness, { $0.signatures[.update]?.inputs.first?.name }) ?? nil }
        let space = document.metadata.flatMap { $0.space == document.origin ? nil : $0.space }
        let schedule = document.schedule
        let moment = schedule.moment.map(Value.formatter.string(from:))

        var spaces: [Reference] {
            var spaces: [Reference] = []
            Runtime.shared.walk(from: model.session.projects) { _, ref, _ in if ref != model.session.projects { spaces.append(ref) } }
            return spaces
        }

        let providers = Runtime.shared.all(as: Command.self)
            .map { $0.0 }
            .filter { $0.descriptor.tags.contains("provider") }
            .sorted { $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending }

        let place = ItemParams(
            ref: space,
            key: "space",
            name: "Space",
            image: "square.stack",
            trailingKind: .load,
            description: space?.descriptor.name ?? "",
            items: [ItemParams(key: "space", name: "None", image: "circle.dashed", tint: Style.Foreground.secondary, active: space == nil)]
                + spaces.map { ItemParams(ref: $0, key: "space", name: $0.descriptor.name, active: $0 == space) }
        )

        let date = ItemParams(
            key: "date",
            name: "Date",
            image: "calendar",
            trailingKind: .date,
            value: moment,
            description: schedule.moment.map { moment in
                Calendar.current.isDateInToday(moment) ? "Today"
                : Calendar.current.isDateInTomorrow(moment) ? "Tomorrow"
                : moment.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
            } ?? ""
        )

        let time = ItemParams(
            key: "time",
            name: "Time",
            trailingKind: .time,
            value: moment,
            description: schedule.moment?.formatted(date: .omitted, time: .shortened) ?? ""
        )

        let agent = slot.map { slot in
            ItemParams(
                ref: command,
                key: slot,
                name: Argument.label(slot),
                image: command.map { Iconography.icon(for: $0).symbol } ?? "switch.2",
                tint: Style.Foreground.secondary,
                trailingKind: .load,
                description: command?.descriptor.name ?? "Required",
                items: providers.map { ref in
                    ItemParams(
                        ref: ref,
                        key: slot,
                        name: ref.descriptor.name,
                        image: Iconography.icon(for: ref).symbol,
                        tint: Style.Foreground.secondary,
                        description: ref.descriptor.description,
                        active: ref == command
                    )
                }
            )
        }

        let parameters = SettingsGroup.parameters(model).sections.flatMap(\.items).filter { $0.origin == command }

        return .init(
            ref: task,
            layout: .group,
            header: true,
            sections: [
                .init(
                    id: "schedule",
                    name: "Schedule",
                    header: true,
                    layout: .grid,
                    items: [date, time]
                ),
                .init(
                    id: "space",
                    name: "Schedule",
                    layout: .table,
                    items: [place]
                ),
                .init(
                    id: "settings",
                    name: "Settings",
                    header: true,
                    tint: Style.Foreground.secondary,
                    items: (agent.map { [$0] } ?? []) + parameters
                ),
                .init(
                    id: "note",
                    name: "Notes",
                    header: true,
                    layout: .grid,
                    items: [ItemParams(key: "note", name: "Add a note...", trailingKind: .field)]
                )
            ]
        )
    }
}

struct InspectorOutline: Mapper {
    static func controls(_ model: any Model) -> Controls {
        switch model.session.selection.root {
            case model.session.inbox: return InboxOutline.controls(model)
            case model.session.library: return DocumentOutline.controls(model)
            case model.session.projects: return ProjectOutline.controls(model)
            case model.session.tasks: return TaskOutline.controls(model)
            default: return Controls()
        }
    }

    static func parameters(_ model: any Model) -> Params {
        switch model.session.selection.root {
            case model.session.inbox: return InboxOutline.parameters(model)
            case model.session.library: return DocumentOutline.parameters(model)
            case model.session.projects: return ProjectOutline.parameters(model)
            case model.session.tasks: return TaskOutline.parameters(model)
            default: return Params()
        }
    }
}

struct InspectorSettings: Mapper {
    static func controls(_ model: any Model) -> Controls {
        switch model.session.selection.root {
            case model.session.inbox: return InboxSettings.controls(model)
            case model.session.library: return DocumentSettings.controls(model)
            case model.session.projects: return ProjectSettings.controls(model)
            case model.session.tasks: return TaskSettings.controls(model)
            default: return Controls()
        }
    }

    static func parameters(_ model: any Model) -> Params {
        switch model.session.selection.root {
            case model.session.inbox: return InboxSettings.parameters(model)
            case model.session.library: return DocumentSettings.parameters(model)
            case model.session.projects: return ProjectSettings.parameters(model)
            case model.session.tasks: return TaskSettings.parameters(model)
            default: return Params()
        }
    }
}
