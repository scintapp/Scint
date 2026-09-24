import SwiftUI
import ScintRuntime
import ScintComponents


struct TaskCompletionIndicator: View {
    var completed: Bool

    var body: some View {
        Iconography.Icon(
            symbol: completed ? "checkmark.app" : "app",
            tint: completed ? Style.Foreground.secondary : Style.Foreground.secondary,
            sizing: 18
        )
        .frame(width: 14, height: 14)
        .fontWeight(.light)
        .accessibilityHidden(true)
    }
}

struct TaskBlock: View {
    let content: String
    let completed: Bool
    let shape = Style.Shape.panel

    var body: some View {
        HStack(alignment: .top, spacing: Style.Spacing.icon) {
            TaskCompletionIndicator(completed: completed)
                .padding(.top, 4)

            Text(content)
                .font(Typography.body)
                .foregroundStyle(completed ? Style.Foreground.secondary : Style.Foreground.primary)
                .strikethrough(completed, color: Style.Foreground.secondary)
                .lineSpacing(Typography.Prose.lineSpacing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TaskItem: View {
    var panel: any Panel
    var model: any Model
    var ref: Reference
    var task: ScintRuntime.Document.Block
    @State private var scheduling = false

    var body: some View {
        if case .task(_, let text, let completed, let when) = task {
            HStack(alignment: .top, spacing: Style.Spacing.icon) {
                Button { TasksContent.update(ref, task: task.id) { .task($0, $1, !$2, $3) } } label: {
                    TaskCompletionIndicator(completed: completed)
                        .padding(.top, 1)
                }
                .buttonStyle(.plain)

                Button { model.open(ref) } label: {
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
                if when != nil { Button("Clear Schedule") { TasksContent.update(ref, task: task.id) { id, text, completed, _ in .task(id, text, completed, nil) } } }
            }
            .popover(isPresented: $scheduling) {
                VStack(alignment: .leading, spacing: Style.Spacing.label) {
                    let moment = Binding(
                        get: { when?.moment ?? .now },
                        set: { moment in TasksContent.update(ref, task: task.id) { .task($0, $1, $2, When(moment, repeats: $3?.repeats ?? .never)) } }
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
