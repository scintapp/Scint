import SwiftUI
import ScintRuntime
import ScintComponents


struct TasksContent: Surface {
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
