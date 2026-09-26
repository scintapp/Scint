import SwiftUI
import ScintRuntime
import ScintComponents


struct TasksCompleted: View {
    var completed: Int
    var showsCompleted: Bool
    var onToggleCompleted: () -> Void
    var onClearCompleted: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4 + 1) {
                Text("\(completed) Completed")
                    .foregroundStyle(Style.Foreground.secondary)

                Button("Clear", action: onClearCompleted)
                    .buttonStyle(.plain)
                    .foregroundStyle(completed > 0 ? Style.Tint.task.bright : Style.Foreground.secondary)
                    .disabled(completed == 0)

                Spacer()

                Button(showsCompleted ? "Hide" : "Show", action: onToggleCompleted)
                    .buttonStyle(.plain)
                    .foregroundStyle(Style.Tint.task.bright)
            }
            .font(.system(size: 13, weight: .regular))

            Rectangle()
                .fill(Style.Border.hairline)
                .frame(height: 0.5)
        }
    }
}

struct TasksHeader: Surface {
    var panel: any Panel
    var model: any Model

    @Binding var scope: TasksContent.Scope

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            NewTaskButton(model: model)
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            Text("Tasks")
                .font(Typography.pageTitle)
            Spacer()
            SegmentedTabs(selection: $scope, options: TasksContent.Scope.allCases, title: \.label)
            IconButton(systemImage: "ellipsis") { }
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
        }
        .frame(maxWidth: .infinity, maxHeight: 40, alignment: .center)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}
