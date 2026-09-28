import SwiftUI
import ScintRuntime
import ScintComponents


struct TasksContentOld: Surface {
    var panel: any Panel
    var model: any Model

    @State private var confirmsClear = false
    @State private var scope: Scope = .today

    enum Scope: String, CaseIterable {
        case today, upcoming, later

        var label: String {
            switch self {
                case .today: "Today"
                case .upcoming: "Upcoming"
                case .later: "Later"
            }
        }
    }

    var tasks: [Reference] {
        guard let tasks = Space.with(model.session.tasks, { $0.documents }) else { return [] }
        return tasks
    }

    var visible: [Reference] {
        let today = Calendar.current.startOfDay(for: .now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? .distantFuture
        return tasks.filter { ref in
            guard case let (done, when)? = Sheet.with(ref, { ($0.done, $0.when) })
                    else { return false }
            let due = when.map { $0.next(after: today) ?? $0.date }
            switch scope {
                case .today: return !done && when == nil
                case .upcoming: return !done && due.map { $0 < tomorrow } == true
                case .later: return !done
            }
        }
    }

    var completed: [Reference] { tasks.filter { Sheet.with($0, { $0.done }) == true } }

    var body: some View {
        if let _ = model.session.opened.document { TaskSheet(panel: panel, model: model) }
        else {
            ScrollView {
                ZStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: Style.Spacing.entry) {
                        LazyVStack(alignment: .leading, spacing: Style.Spacing.entry) {
                            ForEach(visible) { ref in
                                TaskItem(ref: ref, onOpen: { model.open(ref) }, onStart: { model.observe(ref) }, onStop: { model.stop(ref) })
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.horizontal, Style.Spacing.page)
                        .padding(.top, 2)
                        .padding(.bottom, Style.Spacing.page)
                    }

                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .confirmationDialog("Clear completed tasks?", isPresented: $confirmsClear, titleVisibility: .visible) {
                        Button("Clear \(completed.count) Completed \(completed.count == 1 ? "Task" : "Tasks")", role: .destructive) {
                            for sheet in completed {
                                if let material = Sheet.with(sheet, { $0.material }) ?? nil { Space.with(model.session.tasks, { $0 })?.remove(material) }
                                Space.with(model.session.tasks, { $0 })?.remove(sheet)
                            }
                        }
                        Button("Cancel", role: .cancel) { }
                    } message: {
                        Text("This removes completed tasks from Tasks.")
                    }
                }
            }
            .background(Style.Background.canvas)
            .scrollEdgeEffectStyle(.soft, for: .vertical)
            .safeAreaBar(edge: .top) { TasksHeader(panel: panel, model: model, scope: $scope) }
        }
    }
}

struct TaskListRow: View {
    var ref: Reference

    @State var hovered: Bool = false

    var body: some View {
        VStack {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "app")
                    .frame(maxWidth: 20, maxHeight: 20, alignment: .center)
                    .font(.system(size: 18))

                VStack(alignment: .leading) {
                    Text("Review command runner states")
                        .frame(alignment: .leading)
                        .font(.title3)
                        .foregroundStyle(.primary)

                    Text("Today, 9:00 AM")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(alignment: .leading)
                }
                .padding(.leading, 2)

                Spacer()

                Label("Codex", systemImage: "switch.2")
                    .font(.callout)
                Label("Engineering", systemImage: "app")
                    .font(.callout)
            }
            .padding(.top, 8)
            .padding(.bottom, 8)
            .padding(.horizontal, 12)
        }
        .background(Style.Shape.card.fill(hovered ? Color.white.opacity(0.03) : .clear))
        .contentShape(Style.Shape.card)
        .onHover(perform: { _ in hovered.toggle() })
        .padding(.top, 4)
    }
}

struct TaskSection: View {
    var tasks: [Reference]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader()
            ForEach(tasks) { task in
                TaskListRow(ref: task)
            }
        }
        .padding(.horizontal, 24)
    }
}

struct TaskList: Surface {
    var panel: any Panel
    var model: any Model

    var tasks: [Reference] {
        guard let tasks = Space.with(model.session.tasks, { $0.documents }) else { return [] }
        return tasks
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(0..<3) { _ in
                        TaskSection()
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.background)
    }
}

struct TasksContent: Surface {
    var panel: any Panel
    var model: any Model

    var body: some View {
        TaskList(panel: panel, model: model)
    }
}
