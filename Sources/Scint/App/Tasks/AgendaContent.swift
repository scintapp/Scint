import SwiftUI
import ScintRuntime
import ScintComponents


struct AgendaContent: Surface {
    var host: any Host
    var model: any Model

    @State private var scope: Scope = .today
    @State private var presentation: Presentation = .grid

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

    enum Presentation: CaseIterable {
        case list, grid

        var image: String {
            switch self {
                case .list: "checklist.checked"
                case .grid: "circle.grid.2x2.topleft.checkmark.filled"
            }
        }
    }

    var tasks: [Reference] {
        guard let tasks = Space.with(model.session.agenda, { $0 })?.documents
        else { return [] }
        return tasks
    }

    var body: some View {
        if let _ = model.session.opened.document { TaskContent(host: host, model: model) }
        else {
            Group {
                switch presentation {
                    case .grid: AgendaGrid(host: host, model: model)
                    case .list: AgendaList(host: host, model: model, scope: $scope)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .background(Style.Background.canvas)
            .scrollEdgeEffectStyle(.hard, for: .vertical)
            .safeAreaBar(edge: .top) {
                AgendaHeader(
                    host: host,
                    model: model,
                    scope: $scope,
                    presentation: $presentation
                )
            }
        }
    }
}
