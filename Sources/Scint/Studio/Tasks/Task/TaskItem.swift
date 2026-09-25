import SwiftUI
import ScintRuntime
import ScintComponents


struct TaskItem: View {
    var ref: Reference
    var onOpen: () -> Void
    var onStart: () -> Void
    var onStop: () -> Void

    @State private var scheduling = false

    var body: some View {
        if case let (text, completed, when)? = Sheet.with(ref, { ($0.text, $0.done, $0.when) }) {
            HStack(alignment: .top, spacing: Style.Spacing.icon) {
                Button {
                    Sheet.update(ref) { $0.done.toggle() }
                    if completed { onStart() }
                    else { onStop() }
                } label: {
                    TaskCompletionIndicator(completed: completed)
                        .padding(.top, 1)
                }
                .buttonStyle(.plain)

                Button { onOpen() } label: {
                    HStack(alignment: .top, spacing: Style.Spacing.icon) {
                        Text(text)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(completed ? Style.Foreground.secondary : Style.Foreground.primary)
                            .strikethrough(completed, color: Style.Foreground.tertiary)
                            .lineSpacing(Typography.Prose.lineSpacing)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: .zero)
                        if let when {
                            Text(when.moment, format: .dateTime.month(.abbreviated).day().hour().minute())
                                .font(Typography.detail)
                                .foregroundStyle(Style.Foreground.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4 + 1)
            .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
            .accessibilityLabel(text)
            .accessibilityValue(completed ? "Completed" : "Incomplete")
            .contextMenu {
                Button("Schedule…") { scheduling = true }
                if when != nil {
                    Button("Clear Schedule") {
                        Sheet.update(ref) { $0.when = nil }
                        onStop()
                    }
                }
            }
            .popover(isPresented: $scheduling) {
                VStack(alignment: .leading, spacing: Style.Spacing.label) {
                    let moment = Binding(
                        get: { when?.moment ?? .now },
                        set: { moment in
                            Sheet.update(ref) { $0.when = When(moment, repeats: $0.when?.repeats ?? .never) }
                            onStart()
                        }
                    )

                    DatePicker("", selection: moment, displayedComponents: [.date])
                        .datePickerStyle(.graphical)
                        .labelsHidden()

                    DatePicker("", selection: moment, displayedComponents: [.hourAndMinute])
                        .datePickerStyle(.stepperField)
                        .labelsHidden()
                }
                .padding(Style.Spacing.tile)
            }
        }
    }
}
