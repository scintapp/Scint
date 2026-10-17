import SwiftUI
import ScintRuntime
import ScintComponents


//struct TasksListRow: View {
//    var ref: Reference
//    var selected: Bool
//
//    @State var hovered: Bool = false
//
//    var blocks: [Block] { Document.with(ref, { $0.blocks }) ?? [] }
//    var name: String { if case .task(_, let text, _, _)? = blocks.first { text } else { "" } }
//    var done: Bool { if case .task(_, _, let done, _)? = blocks.first { done } else { false } }
//    var command: Reference? { blocks.lazy.compactMap { if case .command(let ref) = $0 { ref } else { nil } }.first }
//    var space: Reference? { blocks.lazy.compactMap { if case .data(_, .collection(let values)) = $0 { values["space"]?.references.first } else { nil } }.first }
//
//    var due: String? {
//        guard case .task(_, _, _, let when?)? = blocks.first else { return nil }
//        let date = when.next(after: Calendar.current.startOfDay(for: .now)) ?? when.date
//        let time = date.formatted(date: .omitted, time: .shortened)
//        if Calendar.current.isDateInToday(date) { return "Today, \(time)" }
//        if Calendar.current.isDateInTomorrow(date) { return "Tomorrow, \(time)" }
//        return "\(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())), \(time)"
//    }
//
//    var body: some View {
//        VStack {
//            HStack(alignment: .center, spacing: 12) {
//                Button {
//                    guard case .task(let id, let text, let done, let when)? = blocks.first else { return }
//                    Document.update(ref) { $0.update(.task(id, text, !done, when), at: 0) }
//                } label: {
//                    Image(systemName: done ? "checkmark.app" : "app")
//                        .frame(maxWidth: 20, maxHeight: 20, alignment: .center)
//                        .font(.system(size: 18))
//                }
//                .buttonStyle(.plain)
//
//                VStack(alignment: .leading) {
//                    Text(name)
//                        .frame(alignment: .leading)
//                        .font(.title3)
//                        .foregroundStyle(.primary)
//
//                    if let due {
//                        Text(due)
//                            .font(.body)
//                            .foregroundStyle(.secondary)
//                            .frame(alignment: .leading)
//                    }
//                }
//                .padding(.leading, 2)
//
//                Spacer()
//
//                if let command {
//                    Label(command.descriptor.name, systemImage: "switch.2")
//                        .font(.callout)
//                }
//                if let space {
//                    Label(space.descriptor.name, systemImage: "app")
//                        .font(.callout)
//                }
//            }
//            .padding(.top, 8)
//            .padding(.bottom, 8)
//            .padding(.horizontal, 12)
//        }
//        .background(Style.Shape.card.fill(selected ? Style.Background.selection : hovered ? Color.white.opacity(0.03) : .clear))
//        .contentShape(Style.Shape.card)
//        .onHover { hovered = $0 }
//        .padding(.top, 4)
//    }
//}
//
//struct TasksListSection: View {
//    var title: String
//    var tasks: [Reference]
//    var selected: Reference?
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 0) {
//            //            SectionHeader(title: title, count: tasks.count)
//            ForEach(tasks) { task in
//                TasksListRow(ref: task, selected: task == selected)
//            }
//        }
//        .padding(.horizontal, 24)
//    }
//}
//
//struct TasksList: Surface {
//    var host: any Host
//    var model: any Model
//
//    var tasks: [Reference] {
//        guard let tasks = Space.with(model.session.agenda, { $0.documents }) else { return [] }
//        return tasks.filter { if case .task(_, _, false, _)? = Document.with($0, { $0.blocks.first }) ?? nil { true } else { false } }
//    }
//
//    func date(_ ref: Reference) -> Date? {
//        guard case .task(_, _, _, let when?)? = Document.with(ref, { $0.blocks.first }) ?? nil else { return nil }
//        return when.next(after: Calendar.current.startOfDay(for: .now)) ?? when.date
//    }
//
//    func scope(_ ref: Reference) -> AgendaContent.Scope {
//        let today = Calendar.current.startOfDay(for: .now)
//        guard let date = self.date(ref),
//              let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today),
//              let week = Calendar.current.date(byAdding: .day, value: 7, to: today)
//                else { return .later }
//        return date < tomorrow ? .today : date < week ? .upcoming : .later
//    }
//
//    func tasks(_ scope: AgendaContent.Scope) -> [Reference] {
//        tasks.filter { self.scope($0) == scope }.sorted { (date($0) ?? .distantFuture) < (date($1) ?? .distantFuture) }
//    }
//
//    var body: some View {
//
//        VStack(spacing: 16) {
//            ForEach(AgendaContent.Scope.allCases, id: \.self) { scope in
//                TasksListSection(
//                    title: scope.label,
//                    tasks: tasks(scope),
//                    selected: model.session.selection.content
//                )
//            }
//        }
//        .padding(.top, 8)
//        .padding(.bottom, 24)
//    }
//}
