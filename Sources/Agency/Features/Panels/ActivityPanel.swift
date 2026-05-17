import AgencyRuntime
import SwiftUI


struct DetailsRowData: Identifiable {
    let context: Composition
    var id: Reference { context.boundary }
}

struct ActivityPanel: View {
    @Environment(AgencyModel.self) var agency

    var rows: [DetailsRowData] {
        Runtime.shared.context()
            .filter { $0.service.type is Service.Type || Journal.with($0.journal, { !$0.entries.isEmpty }) == true }
            .sorted { Boundary.with($0.boundary, { $0.name }) ?? "" < Boundary.with($1.boundary, { $0.name }) ?? "" }
            .map(DetailsRowData.init)
    }

    static let columns: [TableColumn] = [
        .init(title: "Process", width: 320),
        .init(title: "Journal"),
        .init(title: "State", width: 80)
    ]

    var body: some View {
        TableLayout(
            columns: Self.columns,
            sections: rows.isEmpty ? [] : [TableSectionData(id: "processes", title: "Processes", detail: "\(rows.count) tracked", rows: rows)]
        ) { row in
            DetailsTableRow(
                context: row.context,
                columns: Self.columns,
                selected: agency.session.selected(row.context.boundary),
                onSelect: { agency.select(row.context.boundary) }
            )
        }
    }
}

//struct ConsolePanel: View {
//    @Environment(AgencyModel.self) var agency
//
//    var body: some View {
//        ActivityPanel()
//            .frame(maxWidth: .infinity, maxHeight: .infinity)
//            .background(Design.Background.console)
//    }
//}
//
//struct EditPanel: View {
//    @Environment(AgencyModel.self) var agency
//
//    var body: some View {
//        if let sheet = agency.session.sheet {
//            Editor(ref: sheet, mode: .document)
//                .frame(maxWidth: 720, maxHeight: .infinity)
//                .id(sheet)
//        }
//    }
//}
//
//struct ViewPanel: View {
//    @Environment(AgencyModel.self) var agency
//
//    var body: some View {
//        ScrollView {
//            Color.clear.frame(height: 12)
//            Constructor.build(
//                agency.studio.content,
//                BoundaryMapper.params(agency),
//                BoundaryMapper.closures(agency)
//            )
//        }
//    }
//}
//
//struct DetailPanel: View {
//    @Environment(AgencyModel.self) var agency
//
//    var body: some View {
//        ScrollView {
//            Color.clear.frame(height: 12)
//            Constructor.build(
//                agency.studio.content,
//                DetailMapper.params(agency),
//                DetailMapper.closures(agency)
//            )
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//    }
//}
//
//struct ContentPanel: View {
//    @Environment(AgencyModel.self) var agency
//
//    var body: some View {
//        @Bindable var console = agency.studio.console
//        @Bindable var content = agency.studio.content
//
//        VerticalSplit($console.presented, position: $console.position) {
//            HorizontalSplit($content.presented, position: $content.position) {
//                switch content.mode {
//                case .edit:
//                    EditPanel()
//                        .frame(maxWidth: .infinity, maxHeight: .infinity)
//                        .padding(.horizontal, 12)
//
//                case .view:
//                    ViewPanel()
//                        .frame(maxWidth: .infinity, maxHeight: .infinity)
//                        .padding(.horizontal, 12)
//                }
//            } trailing: {
//                DetailPanel()
//                    .frame(maxWidth: 280, maxHeight: .infinity)
//                    .padding(.trailing, 8)
//            }
//            .ignoresSafeArea()
//            .frame(maxWidth: .infinity, maxHeight: .infinity)
//            .background(Design.Background.content)
//            .scrollRouteEffectStyle(.soft, for: .top)
//        } bottom: {
//            ConsoleToolbar(presented: $console.presented).padding(.bottom, -8)
//            ConsolePanel()
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//    }
//}
//
//struct ActivityPanel: View {
//    @Environment(AgencyModel.self) var agency
//
//    private var rows: [SearchResult] {
//        Runtime.shared.search("!service", limit: 50).all
//    }
//
//    var body: some View {
//        ScrollView {
//            LazyVStack(alignment: .leading, spacing: 2) {
//                if rows.isEmpty {
//                    ContentUnavailableView("No Active Processes", systemImage: "arrow.2.squarepath")
//                        .frame(maxWidth: .infinity)
//                        .padding(.vertical, 32)
//                } else {
//                    ForEach(rows) { row in
//                        PanelRow(
//                            name: row.name,
//                            image: Design.Component.icon(for: row.ref),
//                            description: row.description.isEmpty ? nil : row.description,
//                            isSelected: agency.session.selected(row.ref),
//                            onTap: { agency.select(row.ref) }
//                        )
//                    }
//                }
//            }
//            .padding(8)
//        }
//    }
//}
