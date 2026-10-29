import SwiftUI
import ScintRuntime
import ScintComponents


struct AgendaHeader: Surface {
    var host: any Host
    var model: any Model

    @Binding var scope: AgendaContent.Scope
    @Binding var presentation: AgendaContent.Presentation

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            IconButton(systemImage: "plus") {
                model.session.open(ScintRuntime.Document.new(model.session.agenda, title: "New Task"))
            }
            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)

            Text("Tasks")
                .font(Typography.pageTitle)

            Spacer()

            SegmentedTabs(selection: $scope, options: AgendaContent.Scope.allCases, title: \.label)

            SegmentedTabs(
                selection: $presentation,
                options: AgendaContent.Presentation.allCases,
                image: \.image
            )

            IconButton(systemImage: "ellipsis") { }
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
        }
        .frame(maxWidth: .infinity, maxHeight: 40, alignment: .center)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}


