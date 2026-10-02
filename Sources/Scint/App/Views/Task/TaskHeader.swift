import SwiftUI
import ScintRuntime
import ScintComponents


struct TaskHeader: View {
    var ref: Reference
    var onCompose: () -> Void
    var onCancel: () -> Void

    var task: Block? { Document.with(ref, { $0.blocks.first }) ?? nil }
    var ready: Bool { if case .task(_, _, _, _?)? = task { true } else { false } }
    var repeating: Bool { if case .task(_, _, _, let when?)? = task { when.repeats != .never } else { false } }

    var scheduled: Bool {
        guard
            case .task(_, _, false, _)? = task,
            let origin = Document.with(ref, { $0.origin }),
            let transcript = Runtime.shared.context().first(where: { $0.space == origin })?.transcript,
            let entries = Transcript.with(transcript, { $0.entries }),
            let start = entries.lastIndex(where: { if case .signal(_, .start(let input), _) = $0 { input == ref } else { false } })
                else { return false }

        let branch = entries[start...].lazy.compactMap { entry -> Reference? in if case .transcript(let branch, _, _) = entry { branch } else { nil } }.first
        return !entries[start...].contains { entry in
            switch entry {
                case .signal(_, .cancel, _): true
                case .signal(_, .complete(let ended), _), .signal(_, .fail(let ended), _): ended == branch
                case .signal(_, .update(let input), _): input == ref && !repeating
                default: false
            }
        }
    }

    var completed: Binding<Bool> {
        Binding(
            get: { if case .task(_, _, let done, _)? = task { done } else { false } },
            set: { complete in
                guard case .task(let id, let text, _, let when)? = task else { return }
                Document.update(ref) { $0.update(.task(id, text, complete, when), at: 0) }
            }
        )
    }

    var name: Binding<String> {
        Binding(
            get: { if case .task(_, let text, _, _)? = task { text } else { "" } },
            set: { text in
                guard case .task(let id, _, let done, let when)? = task else { return }
                Document.update(ref) { $0.update(.task(id, text, done, when), at: 0) }
            }
        )
    }

    var body: some View {
        if case .task(_, _, let done, _)? = task {
            HStack(alignment: .center) {
                Button {  } label: { TaskCompletionIndicator(completed: done, size: 24) }
                    .buttonStyle(.plain)
                    .padding(.leading, 6)

                TextField("Task", text: name)
                    .textFieldStyle(.plain)
                    .font(Typography.heading(1))

                Spacer()

                if scheduled {
                    Button("Cancel", action: onCancel)
                        .buttonStyle(.glass)
                } else if ready {
                    Button("Schedule", action: onCompose)
                        .buttonStyle(.glassProminent)
                } else {
                    Button("Schedule", action: onCompose)
                        .buttonStyle(.glass)
                        .disabled(true)
                }
            }
        }
    }
}
