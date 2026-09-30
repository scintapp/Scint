import SwiftUI
import ScintRuntime
import ScintComponents


struct TasksNew: View {
    var model: any Model

    var body: some View {
        IconButton(systemImage: "plus") {
            let task = Document.new(model.session.tasks, name: "New Task")
            Document.update(task) { document in
                document.delete(at: 0)
                document.insert([.task(UUID(), "New Task", false, nil), .data(UUID(), .collection([:]))], at: 0)
            }
            model.session.open(task)
        }
        .help("New Task")
    }
}

struct TasksHeader: Surface {
    var panel: any Panel
    var model: any Model

    @Binding var scope: TasksContent.Scope

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            TasksNew(model: model)
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            Text("Tasks")
                .font(Typography.pageTitle)
            Spacer()
            SegmentedTabs(selection: $scope, options: TasksContent.Scope.allCases, title: \.label)
            IconButton(systemImage: "ellipsis") { }
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
        }
        .frame(maxWidth: .infinity, maxHeight: 40, alignment: .center)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}


