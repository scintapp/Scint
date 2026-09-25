import SwiftUI
import ScintRuntime
import ScintComponents


struct TaskHeader: View {
    var ref: Reference
    var onStart: () -> Void
    var onStop: () -> Void

    var body: some View {
        if case let (text, done)? = Sheet.with(ref, { ($0.text, $0.done) }) {
            HStack(alignment: .center, spacing: Style.Spacing.icon) {
                Button {
                    Sheet.update(ref) { $0.done.toggle() }
                    if done { onStart() }
                    else { onStop() }
                } label: {
                    TaskCompletionIndicator(completed: done)
                }
                .buttonStyle(.plain)

                TextField("Task", text: Binding(
                    get: { text },
                    set: { text in Sheet.update(ref) { $0.text = text } }
                ))
                .textFieldStyle(.plain)
                .font(Typography.heading(1))
            }
        }
    }
}
