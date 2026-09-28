import SwiftUI
import ScintRuntime
import ScintComponents


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
