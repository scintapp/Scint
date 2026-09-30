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
        if case .task(let id, let text, let completed, let when)? = Document.with(ref, { $0.blocks.first }) ?? nil {
            HStack(alignment: .top, spacing: Style.Spacing.icon) {
                Button {
                    Document.update(ref) { $0.update(.task(id, text, !completed, when), at: 0) }
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
                            .strikethrough(completed, color: Style.Foreground.subtle)
                            .lineSpacing(Typography.Prose.lineSpacing)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: .zero)
                        if let when {
                            Text(when.date, format: .dateTime.month(.abbreviated).day().hour().minute())
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
                        Document.update(ref) { $0.update(.task(id, text, completed, nil), at: 0) }
                        onStop()
                    }
                }
            }
            .popover(isPresented: $scheduling) {
                VStack(alignment: .leading, spacing: Style.Spacing.label) {
                    let moment = Binding(
                        get: { when?.date ?? .now },
                        set: { moment in
                            Document.update(ref) { $0.update(.task(id, text, completed, When(moment, repeats: when?.repeats ?? .never)), at: 0) }
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
