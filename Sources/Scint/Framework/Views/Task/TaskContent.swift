import SwiftUI
import ScintRuntime
import ScintComponents


struct TaskContent: Surface {
    var host: any Host
    var model: any Model

    var ref: Reference? { model.session.opened.document }
    var task: Block? { ref.flatMap { Document.with($0, { $0.blocks.first }) ?? nil } }
    var ready: Bool { if case .task(_, _, _, _?)? = task { true } else { false } }
    var completed: Bool? { if case .task(_, _, let done, _)? = task { done } else { nil } }

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

                    TaskSetup(host: host, model: model)

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
