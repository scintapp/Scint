import SwiftUI
import ScintRuntime
import ScintComponents


struct TaskContent: Surface {
    var host: any Host
    var model: any Model

    var ref: Reference? { model.session.opened.document }
    var task: (id: UUID, text: String, done: Bool)? { ref.flatMap { Document.with($0, { $0.task }) ?? nil } }
    var ready: Bool { ref.flatMap { Document.with($0, { $0.schedule.moment }) ?? nil } != nil }
    var completed: Bool? { task?.done }

    var body: some View {
        ScrollView {
            if let ref {
                VStack(alignment: .leading, spacing: Style.Spacing.section) {
                    TaskHeader(ref: ref, onCompose: {
                        Space.update(model.session.tasks, { $0.inputs(ref) })
                        model.compose(model.session.tasks)
                    }, onCancel: { model.cancel(model.session.tasks) })

                    Divider()

                    HStack {
                        TaskTime(ref: ref)
                        TaskRepeat(ref: ref)
                        Spacer()
                        TaskSpace(ref: ref, scope: model.session.projects)
                        TaskCommand(ref: ref)
                    }

                    EditorDocument(ref: ref, autofocus: false)
                        .id(ref)
                }
                .frame(maxWidth: Typography.Prose.readableWidth, alignment: .leading)
                .padding(Style.Spacing.page)
                .frame(maxWidth: .infinity)
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .background(Style.Background.canvas)
    }
}
