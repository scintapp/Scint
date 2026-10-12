import SwiftUI
import ScintRuntime
import ScintComponents


struct TaskHeader: View {
    var ref: Reference
    var onCompose: () -> Void
    var onCancel: () -> Void

    static func task(_ document: ScintRuntime.Document) -> (id: UUID, text: String, done: Bool)? {
        if case .task(let id, let text, let done)? = document.blocks.dropFirst().first { (id, text, done) } else { nil }
    }

    static func schedule(_ document: ScintRuntime.Document) -> (moment: Date?, repeats: When.Repeat) {
        let harness = Space.with(document.origin, { $0.harness }) ?? nil
        let values = harness.flatMap { document.command(.start, of: $0) }.map(document.values) ?? [:]
        let moment: Date? = switch values["date"] {
            case .date(let date)?: date
            case .property(.string(let text))?: Value.formatter.date(from: text)
            default: nil
        }
        let repeats: When.Repeat = if case .property(.string(let raw))? = values["repeat"] { When.Repeat(rawValue: raw) ?? .never } else { .never }
        return (moment, repeats)
    }

    static func schedule(_ document: inout ScintRuntime.Document, _ moment: Date, repeats: When.Repeat) {
        guard let harness = Space.with(document.origin, { $0.harness }) ?? nil, let command = document.command(.start, of: harness) else { return }
        document.metadata(.date(moment), "date", for: command)
        document.metadata(.date(moment), "time", for: command)
        document.metadata(.property(.string(repeats.rawValue)), "repeat", for: command)
    }

    var task: (id: UUID, text: String, done: Bool)? { Document.with(ref, { Self.task($0) }) ?? nil }
    var schedule: (moment: Date?, repeats: When.Repeat)? { Document.with(ref, { Self.schedule($0) }) }
    var ready: Bool { schedule?.moment != nil }
    var repeating: Bool { (schedule?.repeats ?? .never) != .never }

    var scheduled: Bool {
        guard
            task?.done == false,
            let origin = Document.with(ref, { $0.origin }),
            let transcript = Runtime.shared.resolve().first(where: { $0.origin == origin })?.transcript,
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
            get: { task?.done ?? false },
            set: { complete in
                guard let task else { return }
                Document.update(ref) { $0.update(.task(task.id, task.text, complete), at: 1) }
            }
        )
    }

    var name: Binding<String> {
        Binding(
            get: { task?.text ?? "" },
            set: { text in
                guard let task else { return }
                Document.update(ref) { $0.update(.task(task.id, text, task.done), at: 1) }
            }
        )
    }

    var body: some View {
        if let done = task?.done {
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
