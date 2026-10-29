import SwiftUI
import ScintRuntime
import ScintComponents


struct AgendaListRow: View {
    let ref: Reference
    let due: Date?
    let model: any Model

    @State private var hovered = false

    var task: (id: UUID, text: String, done: Bool)? { ScintRuntime.Document.with(ref, { TaskHeader.task($0) }) ?? nil }
    var selected: Bool { model.session.selection.selected(ref) }
    var space: Reference? { ScintRuntime.Document.with(ref, { document in (Space.with(document.origin, { $0.interface }) ?? nil).flatMap { document.values($0)["space"]?.references.first } }) ?? nil }

    var when: String? {
        due.map { due in
            Calendar.current.isDateInToday(due) ? due.formatted(date: .omitted, time: .shortened)
            : due.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Button {
                guard let task else { return }
                ScintRuntime.Document.update(ref) { $0.update(.task(task.id, task.text, !task.done), at: 0) }
            } label: {
                TaskCompletionIndicator(completed: task?.done ?? false, size: 18)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(task?.text ?? ref.descriptor.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Style.Foreground.primary)
                    .lineLimit(1)

                if !ref.descriptor.description.isEmpty {
                    Text(ref.descriptor.description)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Style.Foreground.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Group {
                if let space { Label(space.descriptor.name, systemImage: "folder") }
            }
            .frame(width: 150, alignment: .leading)

            Group {
                if let when { Text(when).monospacedDigit() }
            }
            .frame(width: 100, alignment: .trailing)
        }
        .font(.system(size: 12.5))
        .foregroundStyle(Style.Foreground.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(selected ? Style.Background.selection : hovered ? Style.Background.selection.opacity(0.5) : .clear))
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
    }
}

struct AgendaList: Surface {
    var host: any Host
    var model: any Model

    @Binding var scope: AgendaContent.Scope

    var tasks: [Reference] { Space.with(model.session.agenda, { $0 })?.documents ?? [] }

    var dated: [(ref: Reference, due: Date?)] {
        tasks
            .map { ref in
                let due: Date? = ScintRuntime.Document.with(ref, { document in
                    let schedule = TaskHeader.schedule(document)
                    return schedule.moment.map { moment in
                        let when = When(moment, repeats: schedule.repeats)
                        return when.next(after: Calendar.current.startOfDay(for: .now)) ?? when.date
                    }
                }) ?? nil
                return (ref: ref, due: due)
            }
            .sorted { ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture) }
    }

    var groups: [(name: String, tasks: [(ref: Reference, due: Date?)])] {
        let today = Calendar.current.startOfDay(for: .now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
        let week = Calendar.current.date(byAdding: .day, value: 7, to: today) ?? today
        let tasks = dated

        let all: [(name: String, tasks: [(ref: Reference, due: Date?)])] = [
            (name: "Today", tasks: tasks.filter { ($0.due ?? .distantFuture) < tomorrow }),
            (name: "Upcoming", tasks: tasks.filter { ($0.due ?? .distantFuture) >= tomorrow && ($0.due ?? .distantFuture) < week }),
            (name: "Later", tasks: tasks.filter { ($0.due ?? .distantFuture) >= week })
        ]

        let shown: [(name: String, tasks: [(ref: Reference, due: Date?)])] = switch scope {
            case .all: all
            case .today: all.filter { $0.name == "Today" }
            case .upcoming: all.filter { $0.name != "Today" }
            case .later: all
        }

        return shown.filter { !$0.tasks.isEmpty }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                ForEach(groups, id: \.name) { group in
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 10) {
                            Text(group.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Style.Foreground.primary)

                            Text("\(group.tasks.count)")
                                .font(.system(size: 12, weight: .medium))
                                .monospacedDigit()
                                .foregroundStyle(Style.Foreground.secondary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Style.Background.selection))
                        }
                        .padding(.horizontal, 4)
                        .padding(.bottom, 10)

                        ForEach(group.tasks, id: \.ref) { task in
                            Divider().opacity(0.5)

                            AgendaListRow(ref: task.ref, due: task.due, model: model)
                                .onTapGesture(count: 2) { model.open(task.ref) }
                                .simultaneousGesture(TapGesture().onEnded { model.select(task.ref) })
                                .contextMenu { ContextMenu(ref: task.ref, model: model) }
                                .onDrag { ReferenceTransfer.provider(for: task.ref) ?? NSItemProvider() }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .scrollIndicators(.hidden)
            .contentShape(Rectangle())
            .padding(.horizontal, Style.Spacing.entry)
            .padding(.top, Style.Spacing.section)
        }
    }
}




//struct AgendaList: Surface {
//    var host: any Host
//    var model: any Model
//
//    @State private var scope: Scope = .inbox
//
//    enum Scope: String, CaseIterable {
//        case inbox, today, upcoming
//
//        var label: String {
//            switch self {
//                case .inbox: "Inbox"
//                case .today: "Today"
//                case .upcoming: "Upcoming"
//            }
//        }
//    }
//
//    var tasks: [Reference] { Space.with(model.session.agenda, { $0 })?.documents ?? [] }
//
//    var dated: [(ref: Reference, due: Date?)] {
//        tasks
//            .map { ref in
//                let due: Date? = ScintRuntime.Document.with(ref, { document in
//                    let schedule = TaskHeader.schedule(document)
//                    return schedule.moment.map { moment in
//                        let when = When(moment, repeats: schedule.repeats)
//                        return when.next(after: Calendar.current.startOfDay(for: .now)) ?? when.date
//                    }
//                }) ?? nil
//                return (ref: ref, due: due)
//            }
//            .sorted { ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture) }
//    }
//
//    var groups: [(name: String, tasks: [(ref: Reference, due: Date?)])] {
//        let today = Calendar.current.startOfDay(for: .now)
//        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
//        let week = Calendar.current.date(byAdding: .day, value: 7, to: today) ?? today
//        let tasks = dated
//
//        let all: [(name: String, tasks: [(ref: Reference, due: Date?)])] = [
//            (name: "Today", tasks: tasks.filter { ($0.due ?? .distantFuture) < tomorrow }),
//            (name: "Upcoming", tasks: tasks.filter { ($0.due ?? .distantFuture) >= tomorrow && ($0.due ?? .distantFuture) < week }),
//            (name: "Later", tasks: tasks.filter { ($0.due ?? .distantFuture) >= week })
//        ]
//
//        let shown: [(name: String, tasks: [(ref: Reference, due: Date?)])] = switch scope {
//            case .inbox: all
//            case .today: all.filter { $0.name == "Today" }
//            case .upcoming: all.filter { $0.name != "Today" }
//        }
//
//        return shown.filter { !$0.tasks.isEmpty }
//    }
//
//    var body: some View {
//        if let _ = model.session.opened.document {
//            TaskContent(host: host, model: model)
//        } else {
//            ScrollView {
//                VStack(alignment: .leading, spacing: 28) {
//                    ForEach(groups, id: \.name) { group in
//                        VStack(alignment: .leading, spacing: 0) {
//                            HStack(spacing: 10) {
//                                Text(group.name)
//                                    .font(.system(size: 15, weight: .semibold))
//                                    .foregroundStyle(Style.Foreground.primary)
//
//                                Text("\(group.tasks.count)")
//                                    .font(.system(size: 12, weight: .medium))
//                                    .monospacedDigit()
//                                    .foregroundStyle(Style.Foreground.secondary)
//                                    .padding(.horizontal, 7)
//                                    .padding(.vertical, 3)
//                                    .background(Capsule().fill(Style.Background.selection))
//                            }
//                            .padding(.horizontal, 4)
//                            .padding(.bottom, 10)
//
//                            ForEach(group.tasks, id: \.ref) { task in
//                                Divider().opacity(0.5)
//
//                                AgendaListRow(ref: task.ref, due: task.due, model: model)
//                                    .onTapGesture(count: 2) { model.open(task.ref) }
//                                    .simultaneousGesture(TapGesture().onEnded { model.select(task.ref) })
//                                    .contextMenu { ContextMenu(ref: task.ref, model: model) }
//                                    .onDrag { ReferenceTransfer.provider(for: task.ref) ?? NSItemProvider() }
//                            }
//                        }
//                    }
//                }
//                .frame(maxWidth: .infinity, alignment: .topLeading)
//                .scrollIndicators(.hidden)
//                .contentShape(Rectangle())
//                .padding(.horizontal, Style.Spacing.entry)
//                .padding(.top, Style.Spacing.section)
//            }
//            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
//            .background(Style.Background.canvas)
//            .scrollEdgeEffectStyle(.hard, for: .vertical)
//            .safeAreaBar(edge: .top) { AgendaHeader(model: model, scope: $scope) }
//        }
//    }
//}
