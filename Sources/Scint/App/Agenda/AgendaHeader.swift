import SwiftUI
import ScintRuntime
import ScintComponents


struct AgendaHeader: View {
    var model: any Model
    var modes: [SectionParams]
    var active: AnyHashable?
    var onSelect: (SectionParams) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            IconButton(systemImage: "plus") {
                model.session.open(ScintRuntime.Document.new(.init(name: "New Task", origin: model.session.agenda, content: .task)))
            }
            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)

            Text("Tasks")
                .font(Typography.pageTitle)

            Spacer()

            SegmentedTabs(
                selection: .init(get: { active ?? AnyHashable("") }, set: { id in if let mode = modes.first(where: { $0.id == id }) { onSelect(mode) } }),
                options: modes.map(\.id),
                title: { id in modes.first { $0.id == id }?.name ?? "" }
            )

            IconButton(systemImage: "ellipsis") { }
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
        }
        .frame(maxWidth: .infinity, maxHeight: 40, alignment: .center)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}
