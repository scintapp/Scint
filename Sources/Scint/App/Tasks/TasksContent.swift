import SwiftUI
import ScintRuntime
import ScintComponents


//struct TasksContent: Surface {
//    var panel: any Panel
//    var model: any Model
//
//    @State private var scope: Scope = .today
//
//    enum Scope: String, CaseIterable {
//        case today, upcoming, later, all
//
//        var label: String {
//            switch self {
//                case .today: "Today"
//                case .upcoming: "Upcoming"
//                case .later: "Later"
//                case .all: "All Tasks"
//            }
//        }
//    }
//
//    var body: some View {
//        ScrollView {
//            TasksList(panel: panel, model: model)
//        }
//        .background(Style.Background.canvas)
//        .scrollEdgeEffectStyle(.soft, for: .vertical)
//        .safeAreaBar(edge: .top) { TasksHeader(panel: panel, model: model, scope: $scope) }
//    }
//}


struct TasksContent: Surface {
    var panel: any Panel
    var model: any Model

    var tasks: Reference { model.session.tasks }

    var sheets: [Reference] {
        guard let docs = Space.with(tasks, { $0 })?.documents
        else { return [] }
        return docs.filter { if case .task? = Document.with($0, { $0.blocks.first }) ?? nil { true } else { false } }
    }

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

    var body: some View {
        if model.session.opened.document != nil { TaskContent(panel: panel, model: model) }
        else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 230, maximum: 240), spacing: 20)], alignment: .leading, spacing: 20) {
                    ForEach(sheets) { sheet in
                        TasksCard(ref: sheet, model: model, hovered: false)
                            .onTapGesture(count: 2) { model.open(sheet) }
                            .onTapGesture { model.select(sheet) }
                            .contextMenu { ContextActionMenu(ref: sheet, model: model) }
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
            .safeAreaBar(edge: .top) { TasksHeader(panel: panel, model: model, scope: $scope) }
        }
    }
}
