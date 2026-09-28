import SwiftUI
import ScintRuntime
import ScintComponents


struct TaskContent: Surface {
    var panel: any Panel
    var model: any Model

    var ref: Reference? { model.session.opened.document }
    var ready: Bool { ref.flatMap { Sheet.with($0, { $0.when }) ?? nil } != nil }
    var completed: Bool? { if let ref { Sheet.with(ref) { $0.done } }; return nil }

    var scheduled: Bool {
        guard let ref, case let (origin, done)? = Sheet.with(ref, { ($0.origin, $0.done) }), !done,
              let transcript = Runtime.shared.resolve(origin)?.transcript,
              let entries = Transcript.with(transcript, { $0.entries })
        else { return false }

        let events = entries.compactMap { entry -> Bool? in
            switch entry {
                case .event(.start(let value), _) where value.references.contains(ref): true
                case .event(.stop(let value), _) where value.references.contains(ref): false
                default: nil
            }
        }
        return events.last ?? false
    }

    var body: some View {
        ScrollView {
            if let ref, let material = Sheet.with(ref, { $0.material }) ?? nil {
                VStack(alignment: .leading, spacing: Style.Spacing.section) {
                    TaskHeader(ref: ref, onStart: { model.observe(ref) }, onStop: { model.stop(ref) })

                    Divider()

                    HStack {
                        TaskTime(ref: ref)
                        TaskRepeat(ref: ref)
                        Spacer()
                        TaskSpace(ref: ref, scope: model.session.projects)
                        TaskCommand(ref: ref)
                    }

                    TaskSetup(panel: panel, model: model)

                    BlockList(document: material, autofocus: false)
                        .id(material)
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
