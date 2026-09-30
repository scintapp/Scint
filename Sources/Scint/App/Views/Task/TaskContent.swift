import SwiftUI
import ScintRuntime
import ScintComponents


struct TaskContent: Surface {
    var panel: any Panel
    var model: any Model

    var ref: Reference? { model.session.opened.document }
    var task: Block? { ref.flatMap { Document.with($0, { $0.blocks.first }) ?? nil } }
    var ready: Bool { if case .task(_, _, _, _?)? = task { true } else { false } }
    var completed: Bool? { if case .task(_, _, let done, _)? = task { done } else { nil } }

    var scheduled: Bool {
        guard let ref, completed == false, let origin = Document.with(ref, { $0.origin }),
              let transcript = Runtime.shared.context().first(where: { $0.space == origin })?.transcript,
              let entries = Transcript.with(transcript, { $0.entries })
        else { return false }

        let events = entries.compactMap { entry -> Bool? in
            switch entry {
                case .event(.start(let input), _) where input == ref: true
                case .event(.cancel, _): false
                default: nil
            }
        }
        return events.last ?? false
    }

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

                    TaskSetup(panel: panel, model: model)

                    BlockList(document: ref, autofocus: false)
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
