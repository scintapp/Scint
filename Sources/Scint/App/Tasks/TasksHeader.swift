import SwiftUI
import ScintRuntime
import ScintComponents


struct TasksHeader: Surface {
    var host: any Host
    var model: any Model

    @Binding var scope: TasksContent.Scope

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            IconButton(systemImage: "plus") {
                model.session.open(Document.new(from: .init(name: "New Task", origin: model.session.tasks, header: .task)))
            }
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


