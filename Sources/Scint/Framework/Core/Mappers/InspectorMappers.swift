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
        let interface = HarnessGroup.controls(model)
        let commands = CommandsGroup.controls(model)

        func source(for item: ItemParams) -> Controls {
            if item.ref?.type is Command.Type { return commands }
            return interface
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

        let ended = entries.reduce(into: [Reference: [(date: Date, failed: Bool)]]()) { ended, entry in
            switch entry {
                case .signal(_, .complete(let ref), let date): ended[ref, default: []].append((date, false))
                case .signal(_, .fail(let ref), let date): ended[ref, default: []].append((date, true))
                default: break
            }
        }

        let runs = branches.flatMap { branch -> [(intent: Intent, start: Date, end: (date: Date, failed: Bool)?)] in
            let invoked: [Date] = Transcript.with(branch.ref, { $0.entries.compactMap { entry -> Date? in if case .invocation(_, let date) = entry { date } else { nil } } }) ?? []
            let starts: [Date] = invoked.isEmpty ? [branch.started] : invoked
            let stops = ended[branch.ref] ?? []
            return starts.enumerated().map { index, start -> (intent: Intent, start: Date, end: (date: Date, failed: Bool)?) in
                (branch.intent, start, index < stops.count ? stops[index] : nil)
            }
        }

        let messages = entries.compactMap { entry -> (message: Message, intent: Intent?, created: Date)? in
            guard case .message(let message, let created) = entry else { return nil }
            return (message, runs.last { $0.start <= created && created <= ($0.end?.date ?? .now) }?.intent, created)
        }

        let intents = Intent.allCases.filter { intent in runs.contains { $0.intent == intent } }

        func tokens(_ messages: [(message: Message, intent: Intent?, created: Date)]) -> Int {
            messages.reduce(0) { $0 + $1.message.value.rendered.joined(separator: "\n").utf8.count } / 4
        }

        func compact(_ count: Int) -> String { count.formatted(.number.notation(.compactName).precision(.fractionLength(0...1))).lowercased() }

        let total = tokens(messages)
        let shared = tokens(messages.filter { $0.intent == nil })
        let work = intents.map { intent in (intent: intent, tokens: tokens(messages.filter { $0.intent == intent })) }

        let overview = ItemParams(
            key: "stored",
            name: "Stored context",
            image: "cylinder.split.1x2",
            trailingKind: .meter,
            value: "≈ \(compact(total))",
            items: [
                ItemParams(key: "shared", name: "Messages", items: [
                    ItemParams(key: "segment", name: "Shared", tint: Style.Foreground.secondary, count: shared, value: "shared")
                ]),
                ItemParams(key: "work", name: "Work", items: work.map { part in
                    ItemParams(key: "segment", name: part.intent.forms.label, tint: Iconography.icon(for: part.intent).tint, count: part.tokens, value: part.intent.rawValue)
                })
            ]
        )

        let nested = Intent.allCases.filter { $0 != .none }.map { intent in
            let count = runs.filter { $0.intent == intent }.count
            return ItemParams(
                key: intent.rawValue,
                name: intent.forms.label,
                image: Iconography.icon(for: intent).symbol,
                tint: count == 0 ? Style.Foreground.subtle : Iconography.icon(for: intent).tint,
                value: compact(tokens(messages.filter { $0.intent == intent })),
                description: "\(count) \(count == 1 ? "run" : "runs")"
            )
        }

        let time = runs.reduce(0.0) { $0 + ($1.end?.date ?? Date.now).timeIntervalSince($1.start) }
        let failed = runs.filter { $0.end?.failed == true }.count
        let complete = runs.filter { $0.end?.failed == false }.count
        let updated = messages.last?.created ?? root.descriptor.updated

        return .init(
            ref: space,
            name: "Context",
            layout: .group,
            header: true,
            described: false,
            sections: [
                SectionParams(id: "overview", name: "Overview", disclosable: true, items: [overview]),
                .init(id: "branches", name: "Branches", disclosable: true, items: nested),
                .init(id: "properties", name: "Properties", disclosable: true, items: [
                    ItemParams(key: "tokens", name: "Stored tokens", image: "number", value: "≈ \(compact(total))"),
                    ItemParams(key: "entries", name: "Entries", image: "list.bullet", value: messages.count.formatted())
                ]),
                .init(id: "activity", name: "Activity", disclosable: true, items: [
                    ItemParams(key: "tools", name: "Tool calls", image: "wrench.and.screwdriver", value: messages.filter { $0.message.fields["type"] == Property.string("method") }.count.formatted()),
                    ItemParams(key: "runs", name: "Runs", image: "square.stack", value: runs.count.formatted(), description: runs.isEmpty ? "" : "\(complete) complete · \(failed) failed"),
                    ItemParams(key: "time", name: "Run time", image: "stopwatch", value: Duration.seconds(time).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 2))),
                    ItemParams(key: "updated", name: "Updated", image: "clock", value: updated.formatted(.relative(presentation: .named))),
                    ItemParams(key: "age", name: "Age", image: "calendar", value: Duration.seconds(Date.now.timeIntervalSince(root.descriptor.created)).formatted(.units(allowed: [.days, .hours, .minutes, .seconds], width: .wide, maximumUnitCount: 1)))
                ]),
                .init(id: "manage", name: "Manage", disclosable: true, items: [
                    ItemParams(key: "reset", name: "Reset shared context...", image: "arrow.counterclockwise", trailingKind: .button),
                    ItemParams(key: "new", name: "New transcript...", image: "plus.bubble", trailingKind: .button)
                ])
            ].filter { !$0.items.isEmpty }
        )
    }
}

struct ProjectSettings: Mapper {
    static func controls(_ model: any Model) -> Controls {
        let interface = HarnessGroup.controls(model)
        let settings = SettingsGroup.controls(model)
        let commands = CommandsGroup.controls(model)
        let files = FilesGroup.controls(model)

        func source(for item: ItemParams) -> Controls {
            if let key = item.key {
                if key == "add-files" { return files }
                if item.origin?.type is Interface.Type { return settings }
                return interface
            }
            if item.ref?.type is Command.Type { return commands }
            if item.ref?.type is Interface.Type { return interface }
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

struct AgendaOutline: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init()
    }

    static func parameters(_ model: any Model) -> Params {
        .init()
    }
}

struct AgendaSettings: Mapper {
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
                            guard let interface = Space.with(document.origin, { $0.interface }) ?? nil else { return }
                            document.header.argument(item.ref.map(Value.reference), "space", for: interface)
                        }
                    case "repeat":
                        Document.update(task) { TaskHeader.schedule(&$0, TaskHeader.schedule($0).moment ?? .now, repeats: item.value.flatMap(When.Repeat.init(rawValue:)) ?? .never) }
                    case "command":
                        Document.update(task) { document in
                            guard let interface = Space.with(document.origin, { $0.interface }) ?? nil else { return }
                            document.header.argument(item.ref.map(Value.reference), "command", for: interface)
                        }
                    default:
                        break
                }
            }
        )

        func source(for item: ItemParams) -> Controls { item.origin?.type is Interface.Type ? settings : own }

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

        let interface = Space.with(document.origin, { $0.interface }) ?? nil
        let command = interface.flatMap { document.values($0)["command"]?.references.first }
        let space = interface.flatMap { document.values($0)["space"]?.references.first }
        let schedule = TaskHeader.schedule(document)
        let moment = schedule.moment.map(Value.formatter.string(from:))

        var spaces: [Reference] {
            var spaces: [Reference] = []
            Runtime.shared.walk(from: model.session.spaces) { _, ref, _ in if ref != model.session.spaces { spaces.append(ref) } }
            return spaces
        }

        let commands = Runtime.shared.all(as: Command.self)
            .map { $0.0 }
            .sorted { $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending }

        let place = ItemParams(
            ref: space,
            key: "space",
            name: "Space",
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
            image: "clock",
            trailingKind: .time,
            value: moment,
            description: schedule.moment?.formatted(date: .omitted, time: .shortened) ?? ""
        )

        let repeats = ItemParams(
            key: "repeats",
            name: "Repeat",
            image: "repeat",
            trailingKind: .picker,
            active: schedule.repeats != .never,
            items: When.Repeat.allCases.map { option in
                ItemParams(key: "repeat", name: option.rawValue.capitalized, value: option.rawValue, active: option == schedule.repeats)
            },
            actionable: schedule.moment != nil
        )

        let agent = ItemParams(
                ref: command,
                key: "command",
                name: "Command",
                trailingKind: .load,
                description: command?.descriptor.name ?? "Required",
                items: commands.map { ref in
                    ItemParams(
                        ref: ref,
                        key: "command",
                        name: ref.descriptor.name,
                        description: ref.descriptor.description,
                        active: ref == command
                    )
                }
            )

        let parameters = SettingsGroup.parameters(model).sections.flatMap(\.items).filter { $0.origin == interface }

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
                    items: [date, time, repeats]
                ),
                .init(
                    id: "space",
                    name: "Space",
                    items: [place]
                ),
                .init(
                    id: "settings",
                    name: "Settings",
                    header: true,
                    tint: Style.Foreground.secondary,
                    items: [agent] + parameters
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
            case model.session.agenda: return AgendaOutline.controls(model)
            case model.session.library: return DocumentOutline.controls(model)
            case model.session.spaces: return ProjectOutline.controls(model)
            default: return Controls()
        }
    }

    static func parameters(_ model: any Model) -> Params {
        switch model.session.selection.root {
            case model.session.agenda: return AgendaOutline.parameters(model)
            case model.session.library: return DocumentOutline.parameters(model)
            case model.session.spaces: return ProjectOutline.parameters(model)
            default: return Params()
        }
    }
}

struct InspectorSettings: Mapper {
    static func controls(_ model: any Model) -> Controls {
        switch model.session.selection.root {
            case model.session.agenda: return AgendaSettings.controls(model)
            case model.session.library: return DocumentSettings.controls(model)
            case model.session.spaces: return ProjectSettings.controls(model)
            default: return Controls()
        }
    }

    static func parameters(_ model: any Model) -> Params {
        switch model.session.selection.root {
            case model.session.agenda: return AgendaSettings.parameters(model)
            case model.session.library: return DocumentSettings.parameters(model)
            case model.session.spaces: return ProjectSettings.parameters(model)
            default: return Params()
        }
    }
}
