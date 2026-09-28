import SwiftUI
import ScintRuntime
import ScintComponents


struct TasksNew: View {
    var model: any Model

    var body: some View {
        IconButton(systemImage: "plus") {
            let reserved = Set(Runtime.shared.all(as: Harness.self).flatMap { $0.1.commands })
            func forwards(_ parameter: Parameter) -> Bool {
                switch parameter {
                    case .argument(_, .reference(let ref), _, _): ref.type is Command.Type
                    case .command, .callback: true
                    default: false
                }
            }
            guard let command = Runtime.shared.all(as: Command.self)
                .filter({ !reserved.contains($0.0) && !$0.1.parameters.contains(where: forwards) })
                .map({ $0.0 }).min(by: { $0.descriptor.name < $1.descriptor.name })
                    else { return }

            let sheet = Document.new(model.session.tasks, name: "New Task")
            let material = Document.new(model.session.tasks, name: "Instructions")
            Document.update(material) { $0.delete(at: 0) }
            Document.update(sheet) { document in
                document.delete(at: 0)
                document.insert([.task(UUID(), "New Task", false, nil), .command(command), .document(material), .data(UUID(), .collection([:]))], at: 0)
            }
            model.session.open(sheet)
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
