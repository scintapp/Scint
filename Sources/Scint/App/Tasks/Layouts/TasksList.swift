import SwiftUI
import ScintRuntime
import ScintComponents


struct TasksListRow: View {
    var ref: Reference
    var selected: Bool

    @State var hovered: Bool = false

    var name: String { Sheet.with(ref) { $0.name } ?? "" }
    var done: Bool { Sheet.with(ref) { $0.done } ?? false }
    var command: Reference? { Sheet.with(ref) { $0.command } ?? nil }
    var space: Reference? { Sheet.with(ref) { $0.arguments["space"]?.references.first } ?? nil }

    var due: String? {
        guard let when = Sheet.with(ref, { $0.when }) ?? nil else { return nil }
        let date = when.next(after: Calendar.current.startOfDay(for: .now)) ?? when.date
        let time = date.formatted(date: .omitted, time: .shortened)
        if Calendar.current.isDateInToday(date) { return "Today, \(time)" }
        if Calendar.current.isDateInTomorrow(date) { return "Tomorrow, \(time)" }
        return "\(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())), \(time)"
    }

    var body: some View {
        VStack {
            HStack(alignment: .center, spacing: 12) {
                Button { Sheet.update(ref) { $0.done = !done } } label: {
                    Image(systemName: done ? "checkmark.app" : "app")
                        .frame(maxWidth: 20, maxHeight: 20, alignment: .center)
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading) {
                    Text(name)
                        .frame(alignment: .leading)
                        .font(.title3)
                        .foregroundStyle(.primary)

                    if let due {
                        Text(due)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(alignment: .leading)
                    }
                }
                .padding(.leading, 2)

                Spacer()

                if let command {
                    Label(command.descriptor.name, systemImage: "switch.2")
                        .font(.callout)
                }
                if let space {
                    Label(space.descriptor.name, systemImage: "app")
                        .font(.callout)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 8)
            .padding(.horizontal, 12)
        }
        .background(Style.Shape.card.fill(selected ? Style.Background.selection : hovered ? Color.white.opacity(0.03) : .clear))
        .contentShape(Style.Shape.card)
        .onHover { hovered = $0 }
        .padding(.top, 4)
    }
}

struct TasksListSection: View {
    var title: String
    var tasks: [Reference]
    var selected: Reference?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            //            SectionHeader(title: title, count: tasks.count)
            ForEach(tasks) { task in
                TasksListRow(ref: task, selected: task == selected)
            }
        }
        .padding(.horizontal, 24)
    }
}

struct TasksList: Surface {
    var panel: any Panel
    var model: any Model

    var tasks: [Reference] {
        guard let tasks = Space.with(model.session.tasks, { $0.documents }) else { return [] }
        return tasks.filter { Sheet.with($0, { !$0.done }) == true }
    }

    func date(_ ref: Reference) -> Date? {
        guard let when = Sheet.with(ref, { $0.when }) ?? nil else { return nil }
        return when.next(after: Calendar.current.startOfDay(for: .now)) ?? when.date
    }

    func scope(_ ref: Reference) -> TasksContent.Scope {
        let today = Calendar.current.startOfDay(for: .now)
        guard let date = self.date(ref),
              let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today),
              let week = Calendar.current.date(byAdding: .day, value: 7, to: today)
                else { return .later }
        return date < tomorrow ? .today : date < week ? .upcoming : .later
    }

    func tasks(_ scope: TasksContent.Scope) -> [Reference] {
        tasks.filter { self.scope($0) == scope }.sorted { (date($0) ?? .distantFuture) < (date($1) ?? .distantFuture) }
    }

    var body: some View {

        VStack(spacing: 16) {
            ForEach(TasksContent.Scope.allCases, id: \.self) { scope in
                TasksListSection(
                    title: scope.label,
                    tasks: tasks(scope),
                    selected: model.session.selection.content
                )
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 24)
    }
}
