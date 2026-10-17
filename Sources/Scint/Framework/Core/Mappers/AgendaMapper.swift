import SwiftUI
import ScintRuntime
import ScintComponents


struct AgendaMapper: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init(
            onToggle: { item in
                guard let ref = item.ref else { return }
                Document.update(ref) { document in
                    guard let task = TaskHeader.task(document) else { return }
                    document.update(.task(task.id, task.text, !task.done), at: 1)
                }
            },
            selected: { item in item.ref.map { model.session.selection.selected($0) } ?? false },
            onSelect: { item in if let ref = item.ref { model.select(ref) } },
            onAction: { item in if let ref = item.ref { model.open(ref) } },
            wrapLink: { view, item, _ in
                guard let ref = item.ref else { return view }
                return AnyView(view.contextMenu { ContextMenu(ref: ref, model: model) })
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let days = (0..<5).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
        let tasks = (Space.with(model.session.agenda, { $0 })?.documents ?? [])
            .compactMap { Document.with($0, { $0 }) }
            .filter { $0.header.content == .task && TaskHeader.task($0) != nil }

        func when(_ document: ScintRuntime.Document) -> When? {
            let schedule = TaskHeader.schedule(document)
            return schedule.moment.map { When($0, repeats: schedule.repeats) }
        }

        func next(_ document: ScintRuntime.Document, from start: Date) -> Date? {
            when(document)?.next(after: start.addingTimeInterval(-1)).flatMap { $0 >= start ? $0 : nil }
        }

        func item(_ document: ScintRuntime.Document, at date: Date?) -> ItemParams {
            let task = TaskHeader.task(document)
            let body = Array(document.blocks.dropFirst(2))
            let summary: String = if case .paragraph(_, let text)? = body.first { text } else { "" }
            let space: Reference? = if case .metadata(let space, _)? = document.blocks.first, space != document.origin { space } else { nil }
            let command = (Space.with(document.origin, { $0.interface }) ?? nil).flatMap { document.command("start", of: $0) }
            let notes = (summary.isEmpty ? body : Array(body.dropFirst())).compactMap { block -> ItemParams? in
                switch block {
                    case .paragraph(let id, let text): ItemParams(ref: document.ref, entryId: id, name: text)
                    case .heading(let id, let level, let text): ItemParams(ref: document.ref, entryId: id, name: String(repeating: "#", count: level) + " " + text)
                    case .task(let id, let text, let done): ItemParams(ref: document.ref, entryId: id, name: "- [\(done ? "x" : " ")] \(text)")
                    case .code(let id, let language, let text): ItemParams(ref: document.ref, entryId: id, name: "```\(language)\n\(text)\n```")
                    default: nil
                }
            }

            return ItemParams(
                ref: document.ref,
                origin: space,
                name: task?.text ?? "",
                trailingKind: .toggle,
                value: date?.formatted(date: .omitted, time: .shortened),
                description: summary,
                active: task?.done ?? false,
                items: notes + [space, command].compactMap { $0 }.map { ItemParams(ref: $0, name: $0.descriptor.name) }
            )
        }

        func ordered(_ rows: [(document: ScintRuntime.Document, date: Date)]) -> [(document: ScintRuntime.Document, date: Date)] {
            rows.sorted { ($0.date, $0.document.ref.id.uuidString) < ($1.date, $1.document.ref.id.uuidString) }
        }

        func dated(_ rows: [(document: ScintRuntime.Document, date: Date)]) -> [SectionParams] {
            ordered(rows).reduce(into: [SectionParams]()) { groups, row in
                let id = Value.formatter.string(from: calendar.startOfDay(for: row.date))
                let name = calendar.isDateInToday(row.date) ? "Today"
                    : calendar.isDateInTomorrow(row.date) ? "Tomorrow"
                    : row.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
                if groups.last?.id == AnyHashable(id) { groups[groups.count - 1].items.append(item(row.document, at: row.date)) }
                else { groups.append(.init(id: id, name: name, items: [item(row.document, at: row.date)])) }
            }
        }

        let unscheduled = SectionParams(
            id: "unscheduled",
            name: "Unscheduled",
            items: tasks
                .filter { when($0) == nil }
                .sorted { ($0.ref.descriptor.created, $0.ref.id.uuidString) < ($1.ref.descriptor.created, $1.ref.id.uuidString) }
                .map { item($0, at: nil) }
        )

        return .init(
            name: "Tasks",
            tabbed: true,
            sections: [
                .init(id: "today", name: "Today", sections: [
                    .init(id: "days", header: false, layout: .row, sections: days.map { day in
                        let interval = calendar.dateInterval(of: .day, for: day) ?? DateInterval(start: day, duration: 0)
                        let rows = ordered(tasks.compactMap { document in next(document, from: interval.start).flatMap { $0 < interval.end ? (document: document, date: $0) : nil } })

                        return .init(
                            id: Value.formatter.string(from: day),
                            name: day.formatted(.dateTime.day()),
                            description: day.formatted(.dateTime.weekday(.abbreviated)),
                            image: day == today ? "circle.fill" : "",
                            tint: Style.Tint.accent.bright,
                            layout: .table,
                            sections: [(id: "morning", name: "Morning", hours: 0..<12), (id: "afternoon", name: "Afternoon", hours: 12..<17), (id: "later", name: "Later", hours: 17..<24)]
                                .map { group in .init(id: group.id, name: group.name, items: rows.filter { group.hours.contains(calendar.component(.hour, from: $0.date)) }.map { item($0.document, at: $0.date) }) }
                                .filter { !$0.items.isEmpty }
                        )
                    })
                ]),
                .init(id: "upcoming", name: "Upcoming", sections: [
                    .init(id: "upcoming", layout: .table, sections: dated(tasks.compactMap { document in next(document, from: tomorrow).map { (document: document, date: $0) } }))
                ]),
                .init(id: "later", name: "Later", sections: [
                    .init(id: "later", layout: .table, sections: [unscheduled].filter { !$0.items.isEmpty })
                ]),
                .init(id: "all", name: "All Tasks", sections: [
                    .init(id: "all", layout: .table, sections: (dated(tasks.compactMap { document in when(document).map { (document: document, date: next(document, from: today) ?? $0.date) } }) + [unscheduled]).filter { !$0.items.isEmpty })
                ])
            ]
        )
    }
}
