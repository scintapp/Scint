import SwiftUI
import ScintRuntime
import ScintComponents


struct AgendaGrid: Surface {
    var host: any Host
    var model: any Model

    var tasks: [Reference] {
        guard let tasks = Space.with(model.session.agenda, { $0 })?.documents
        else { return [] }
        return tasks
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 230, maximum: 240), spacing: 20)], alignment: .leading, spacing: 20) {
                ForEach(tasks) { task in
                    AgendaCard(ref: task, model: model, hovered: false)
                        .onTapGesture { model.select(task) }
                        .onTapGesture(count: 2) { model.open(task) }
                        .contextMenu { ContextMenu(ref: task, model: model) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .scrollIndicators(.hidden)
            .contentShape(Rectangle())
            .padding(.horizontal, Style.Spacing.entry)
            .padding(.top, Style.Spacing.section)
        }
    }
}
