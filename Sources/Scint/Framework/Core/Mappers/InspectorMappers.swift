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

        func source(for item: ItemParams) -> Controls {
            if item.ref?.type is Command.Type { return commands }
            return harness
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
        guard let root = space.context?.transcript, let entries = Transcript.with(root, { $0.entries })
        else { return .init(ref: space, name: "Context", layout: .group, header: true, described: false) }

        let branches = entries.compactMap { entry -> (ref: Reference, intent: Intent, started: Date)? in
            if case .transcript(let ref, let intent, let started) = entry { (ref, intent, started) } else { nil }
        }

        let ended = entries.reduce(into: [Reference: (date: Date, failed: Bool)]()) { ended, entry in
            switch entry {
                case .signal(_, .complete(let ref), let date): ended[ref] = (date, false)
                case .signal(_, .fail(let ref), let date): ended[ref] = (date, true)
                default: break
            }
        }

        func tokens(_ refs: [Reference]) -> Int {
            refs.flatMap { Transcript.with($0, { $0.records }) ?? [] }.reduce(0) { $0 + $1.value.rendered.joined(separator: "\n").utf8.count } / 4
        }

        let total = tokens([root] + branches.map(\.ref))

        func tab(_ intent: Intent?) -> SectionParams {
            let id = intent?.rawValue ?? ""
            let name = intent?.forms.label ?? "Messages"
            let runs = intent == nil ? branches : branches.filter { $0.intent == intent }
            let refs = intent == nil ? [root] : runs.map(\.ref)
            let records = refs.flatMap { Transcript.with($0, { $0.records }) ?? [] }
            let used = tokens(refs)
            let updated = refs.compactMap { Transcript.with($0, { $0.entries.last?.created }) ?? nil }.max() ?? root.descriptor.updated
            let created = refs.map(\.descriptor.created).min() ?? root.descriptor.created
            let time = runs.reduce(0) { $0 + (ended[$1.ref]?.date ?? .now).timeIntervalSince($1.started) }
            let failed = runs.filter { ended[$0.ref]?.failed == true }.count
            let complete = runs.filter { ended[$0.ref]?.failed == false }.count

            return .init(
                id: id,
                name: name,
                header: intent != nil,
                image: "app",
                tint: intent.map { Iconography.icon(for: $0).tint },
                sections: [
                    .init(id: "\(name.lowercased())-metrics", name: name, layout: .table, items: [
                        ItemParams(key: "updated", name: "Updated", image: "clock", value: updated.formatted(.relative(presentation: .named))),
                        ItemParams(key: "age", name: "Age", image: "calendar", value: Duration.seconds(Date.now.timeIntervalSince(created)).formatted(.units(allowed: [.days, .hours, .minutes, .seconds], width: .wide, maximumUnitCount: 1))),
                        ItemParams(key: "tokens", name: "Tokens", image: "number", value: "≈ \(used.formatted(.number.notation(.compactName)))"),
                        ItemParams(key: "share", name: "Share", image: "chart.pie", value: (Double(used) / Double(max(total, 1))).formatted(.percent.precision(.fractionLength(0)))),
                        ItemParams(key: "entries", name: "Entries", image: "list.bullet", value: records.count.formatted()),
                        ItemParams(key: "tools", name: "Tool Calls", image: "wrench.and.screwdriver", value: records.filter { $0.fields["type"] == .string("method") }.count.formatted()),
                        ItemParams(key: "runs", name: "Runs", image: "square.stack", value: runs.count.formatted(), description: runs.isEmpty ? "" : "\(complete) complete · \(failed) failed"),
                        ItemParams(key: "time", name: "Run Time", image: "stopwatch", value: Duration.seconds(time).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 2)))
                    ])
                ]
            )
        }

        return .init(
            ref: space,
            name: "Context",
            layout: .group,
            header: true,
            described: false,
            tabbed: true,
            sections: [tab(nil)] + Intent.allCases.filter { intent in branches.contains { $0.intent == intent } }.map { tab($0) }
        )
    }
}

struct ProjectSettings: Mapper {
    static func controls(_ model: any Model) -> Controls {
        let harness = HarnessGroup.controls(model)
        let settings = SettingsGroup.controls(model)
        let commands = CommandsGroup.controls(model)
        let files = FilesGroup.controls(model)

        func source(for item: ItemParams) -> Controls {
            if let key = item.key {
                if key == "add-files" { return files }
                if item.origin?.type is Command.Type { return settings }
                return harness
            }
            if item.ref?.type is Command.Type { return commands }
            if item.ref?.type is Interface.Type { return harness }
            return files
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
            sections: HarnessGroup.parameters(model).sections + SettingsGroup.parameters(model).sections + CommandsGroup.parameters(model).sections + FilesGroup.parameters(model).sections
        )
    }
}

struct DocumentOutline: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init(
            onToggle: { item in
                guard let ref = item.ref, let entry = item.entryId else { return }
                Document.update(ref) { document in
                    guard let index = document.blocks.firstIndex(where: { $0.id == AnyHashable(entry) }),
                          case .task(let id, let text, let done) = document.blocks[index]
                    else { return }
                    document.update(.task(id, text, !done), at: index)
                }
            },
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
                let space = model.session.spaces
                return .init(ref: space, name: space.descriptor.name)
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        guard let doc = model.session.selection.content, let document = Document.with(doc, { $0 })
        else { return .init() }

        let headings = document.blocks.compactMap { block -> (level: Int, id: UUID, text: String)? in
            if case .heading(let id, let level, let text) = block { (level, id, text) } else { nil }
        }

        func outline(_ headings: ArraySlice<(level: Int, id: UUID, text: String)>) -> [ItemParams] {
            guard let heading = headings.first else { return [] }
            let rest = headings.dropFirst()
            let end = rest.firstIndex { $0.level <= heading.level } ?? rest.endIndex
            return [ItemParams(ref: doc, entryId: heading.id, name: heading.text, items: outline(rest[..<end]))] + outline(rest[end...])
        }

        let checklist = document.blocks.compactMap { block -> ItemParams? in
            if case .task(let id, let text, let done) = block { ItemParams(ref: doc, entryId: id, name: text, trailingKind: .toggle, active: done) } else { nil }
        }

        let objects = document.blocks.compactMap { block -> ItemParams? in
            if case .code(let id, let language, let text) = block {
                let line = text.split(separator: "\n").first.map(String.init) ?? ""
                return ItemParams(ref: doc, entryId: id, name: language.isEmpty ? line : "\(language) · \(line)", image: "chevron.left.forwardslash.chevron.right", tint: Style.Foreground.secondary, description: "Code")
            }
            guard let ref = EditorIO.reference(block) else { return nil }
            let icon = Iconography.icon(for: ref)
            let kind = Artifact.with(ref, { String("\($0.handle)".prefix { $0 != "(" }).capitalized }) ?? ref.type.map { "\($0)" } ?? "Reference"
            return ItemParams(ref: doc, entryId: block.id as? UUID, name: ref.descriptor.name, image: icon.symbol, tint: icon.tint, description: kind)
        }

        return .init(
            ref: doc,
            layout: .group,
            header: true,
            described: false,
            sections: [
                .init(id: "contents", name: "Contents", layout: .list, items: outline(headings[...])),
                .init(id: "checklist", name: "Checklist", description: "\(checklist.filter(\.active).count) of \(checklist.count) complete", layout: .list, items: checklist),
                .init(id: "objects", name: "Objects", items: objects)
            ]
            .filter { !$0.items.isEmpty }
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
                let space = model.session.spaces
                return .init(ref: space, name: space.descriptor.name)
            },
            itemPalette: { item in
                item.path == nil ? item.ref.map { ActionProvider.items(for: $0, in: model) } ?? [] : []
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
                        Document.update(task) { TaskHeader.schedule(&$0, moment, repeats: TaskHeader.schedule($0).repeats) }
                }
            },
            onSelect: { item in
                switch item.key {
                    case "space":
                        Document.update(task) { document in
                            guard case .metadata(_, let values)? = document.blocks.first else { return }
                            document.update(.metadata(item.ref ?? document.origin, values), at: 0)
                        }
                    case "repeat":
                        Document.update(task) { TaskHeader.schedule(&$0, TaskHeader.schedule($0).moment ?? .now, repeats: item.value.flatMap(When.Repeat.init(rawValue:)) ?? .never) }
                    case let slot?:
                        Document.update(task) { document in
                            guard let harness = Space.with(document.origin, { $0.interface }) ?? nil, let ref = item.ref else { return }
                            document.header.argument(.reference(ref), slot, for: harness)
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
        guard let task = model.session.document, let document = Document.with(task, { $0 }), document.header.content == .task
        else { return .init() }

        let harness = Space.with(document.origin, { $0.interface }) ?? nil
        let command = harness.flatMap { document.command("start", of: $0) }
        let slot = harness.flatMap {
            harness in Interface
                .with(harness, { $0.method("start")?.name }) ?? nil
        }
        let space: Reference? = if case .metadata(let space, _)? = document.blocks.first, space != document.origin { space } else { nil }
        let schedule = TaskHeader.schedule(document)
        let moment = schedule.moment.map(Value.formatter.string(from:))

        var spaces: [Reference] {
            var spaces: [Reference] = []
            Runtime.shared.walk(from: model.session.spaces) { _, ref, _ in if ref != model.session.spaces { spaces.append(ref) } }
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
            case model.session.spaces: return ProjectOutline.controls(model)
            case model.session.tasks: return TaskOutline.controls(model)
            default: return Controls()
        }
    }

    static func parameters(_ model: any Model) -> Params {
        switch model.session.selection.root {
            case model.session.inbox: return InboxOutline.parameters(model)
            case model.session.library: return DocumentOutline.parameters(model)
            case model.session.spaces: return ProjectOutline.parameters(model)
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
            case model.session.spaces: return ProjectSettings.controls(model)
            case model.session.tasks: return TaskSettings.controls(model)
            default: return Controls()
        }
    }

    static func parameters(_ model: any Model) -> Params {
        switch model.session.selection.root {
            case model.session.inbox: return InboxSettings.parameters(model)
            case model.session.library: return DocumentSettings.parameters(model)
            case model.session.spaces: return ProjectSettings.parameters(model)
            case model.session.tasks: return TaskSettings.parameters(model)
            default: return Params()
        }
    }
}
