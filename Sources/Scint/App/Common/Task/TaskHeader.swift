import SwiftUI
import ScintRuntime
import ScintComponents


struct TaskScheduleButton: View {
    var ref: Reference
    var onStart: () -> Void
    var onStop: () -> Void

    var ready: Bool { Sheet.with(ref) { $0.when } != nil }

    var scheduled: Bool {
        guard
            case let (origin, done)? = Sheet.with(ref, { ($0.origin, $0.done) }), !done,
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
        ZStack {
            Button { onStart() } label: {
                Image(systemName: "calendar.badge.plus")
            }
            .buttonStyle(.soft)
            .controlSize(.small)
            .opacity(scheduled ? 0 : 1)
            .disabled(!ready)

            Button { onStop() } label: {
                Image(systemName: "calendar.badge.checkmark")
            }
            .buttonStyle(.soft)
            .controlSize(.small)
            .opacity(scheduled ? 1 : 0)
            .disabled(!scheduled)
        }
    }
}

struct TaskHeader: View {
    var ref: Reference
    var onStart: () -> Void
    var onStop: () -> Void


    var ready: Bool { Sheet.with(ref) { $0.ready } ?? false }
    var scheduled: Bool { Sheet.with(ref) { $0.scheduled } ?? false }

    var completed: Binding<Bool> {
        Binding(
            get: { Sheet.update(ref) { $0.done } ?? false },
            set: { complete in Sheet.update(ref) { $0.done = complete } }
        )
    }

    var name: Binding<String> {
        Binding(
            get: { Sheet.update(ref) { $0.name } ?? "" },
            set: { text in Sheet.update(ref) { $0.name = text } }
        )
    }

    var body: some View {
        if case let (_, done)? = Sheet.with(ref, { ($0.name, $0.done) }) {
            HStack(alignment: .center) {
                Button {  } label: { TaskCompletionIndicator(completed: done, size: 24) }
                    .buttonStyle(.plain)
                    .padding(.leading, 6)

                TextField("Task", text: name)
                    .textFieldStyle(.plain)
                    .font(Typography.heading(1))

                Spacer()

                ZStack {
                    IconButton(systemImage: "calendar.badge.plus", action: onStart)
                        .opacity(scheduled ? 0 : 1)
                        .disabled(!ready)

                    IconButton(systemImage: "calendar.badge.checkmark", action: onStop)
                        .opacity(scheduled ? 1 : 0)
                        .disabled(!scheduled)
                }
            }
        }
    }
}
