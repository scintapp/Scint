import SwiftUI
import ScintRuntime
import ScintComponents


struct TasksContent: Surface {
    var host: any Host
    var model: any Model

    @State private var scope: Scope = .today

    enum Scope: String, CaseIterable {
        case today, upcoming, later, all

        var label: String {
            switch self {
                case .today: "Today"
                case .upcoming: "Upcoming"
                case .later: "Later"
                case .all: "All Tasks"
            }
        }
    }

    var tasks: [Reference] {
        guard let tasks = Space.with(model.session.tasks, { $0 })?.documents
        else { return [] }
        return tasks
    }

    var body: some View {
        if let task = model.session.opened.document, (Document.with(task, { $0 })?.task != nil) {
            DocumentContent(host: host, model: model)
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 230, maximum: 240), spacing: 20)], alignment: .leading, spacing: 20) {
                    ForEach(tasks) { task in
                        TasksCard(ref: task, model: model, hovered: false)
                            .onTapGesture(count: 2) { model.open(task) }
                            .onTapGesture { model.select(task) }
                            .contextMenu { ContextMenu(ref: task, model: model) }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .scrollIndicators(.hidden)
                .contentShape(Rectangle())
                .padding(.horizontal, Style.Spacing.entry)
                .padding(.top, Style.Spacing.section)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .background(Style.Background.canvas)
            .scrollEdgeEffectStyle(.hard, for: .vertical)
            .safeAreaBar(edge: .top) { TasksHeader(host: host, model: model, scope: $scope) }
        }
    }
}
