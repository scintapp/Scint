import SwiftUI
import ScintRuntime
import ScintComponents


struct TaskContent: Surface {
    var host: any Host
    var model: any Model

    var ref: Reference? { model.session.selection.opened.document }
    var task: (id: UUID, text: String, done: Bool)? { ref.flatMap { Document.with($0, { TaskHeader.task($0) }) ?? nil } }
    var ready: Bool { ref.flatMap { Document.with($0, { TaskHeader.schedule($0).moment }) ?? nil } != nil }
    var completed: Bool? { task?.done }

    var body: some View {
        ScrollView {
            if let ref {
                VStack(alignment: .leading, spacing: Style.Spacing.section) {
                    TaskHeader(ref: ref, onCompose: {
                        Space.update(model.session.tasks, { $0.input(ref) })
                        let _ = model.compose(model.session.tasks)
                    }, onCancel: { let _ = model.cancel(ref) })

                    Divider()

                    HStack {
                        TaskDate(ref: ref, placeholder: "Date", symbol: "calendar", components: [.date])
                        TaskDate(ref: ref, placeholder: "Time", symbol: "clock", components: [.hourAndMinute])
                        TaskRepeat(ref: ref)
                        Spacer()
                        TaskTarget(ref: ref, scope: model.session.spaces)
                        TaskAction(ref: ref)
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
