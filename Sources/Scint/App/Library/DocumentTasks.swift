import SwiftUI
import ScintRuntime
import ScintComponents


struct TaskItem: View {
    var panel: any Panel
    var model: any Model
    var ref: Reference
    var task: ScintRuntime.Document.Block

    var body: some View {
        if case .task(_, let text, let completed) = task {
            Button { toggle(task.id) } label: {
                HStack(alignment: .top, spacing: Style.Spacing.icon) {
                    TaskCompletionIndicator(completed: completed)
                        .padding(.top, 1)
                    Text(text)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(completed ? Style.Foreground.secondary : Style.Foreground.primary)
                        .strikethrough(completed, color: Style.Foreground.tertiary)
                        .lineSpacing(Typography.Prose.lineSpacing)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: .zero)
                }
                .padding(.vertical, Style.Spacing.detail + 1)
                .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(text)
            .accessibilityValue(completed ? "Completed" : "Incomplete")
            .accessibilityHint(completed ? "Marks this task incomplete" : "Marks this task completed")
        }
    }

    private func toggle(_ id: AnyHashable) {
        Document.update(ref) { document in
            guard let index = document.blocks.firstIndex(where: { $0.id == id }),
                  case .task(let id, let text, let completed) = document.blocks[index]
                    else { return }
            document.update(.task(id, text, !completed), at: index)
        }
    }
}

struct TasksHeader: View {
    var completed: Int
    var showsCompleted: Bool
    var onToggleCompleted: () -> Void
    var onClearCompleted: () -> Void

    var body: some View {
        VStack(spacing: Style.Spacing.label) {
            HStack(spacing: Style.Spacing.detail + 1) {
                Text("\(completed) Completed")
                    .foregroundStyle(Style.Foreground.secondary)

                Text("•")
                    .foregroundStyle(Style.Foreground.secondary)

                Button("Clear", action: onClearCompleted)
                    .buttonStyle(.plain)
                    .foregroundStyle(completed > 0 ? Style.Tint.task.bright : Style.Foreground.secondary)
                    .disabled(completed == 0)

                Spacer(minLength: Style.Spacing.label)

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

struct TasksSection: Surface {
    @State private var expanded = true

    var panel: any Panel
    var model: any Model
    var ref: Reference
    var showsCompleted: Bool

    var allTasks: [ScintRuntime.Document.Block] {
        Document.with(ref) { document in
            document.blocks.filter { if case .task = $0 { true } else { false } }
        } ?? []
    }

    var tasks: [ScintRuntime.Document.Block] {
        guard !showsCompleted else { return allTasks }
        return allTasks.filter { if case .task(_, _, false) = $0 { true } else { false } }
    }

    var body: some View {
        if !allTasks.isEmpty {
            VStack(alignment: .leading, spacing: Style.Spacing.label) {
                HStack(spacing: Style.Spacing.label) {
                    Button { model.open(ref) } label: {
                        Text(ref.descriptor.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Style.Foreground.primary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.smooth(duration: 0.18)) { expanded.toggle() }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Style.Foreground.secondary)
                            .rotationEffect(.degrees(expanded ? .zero : -90))
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(expanded ? "Collapse tasks" : "Expand tasks")
                }

                if expanded {
                    VStack(alignment: .leading, spacing: Style.Spacing.detail) {
                        ForEach(tasks) { task in
                            TaskItem(panel: panel, model: model, ref: ref, task: task)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
}

struct DocumentTasks: Surface {
    @State private var showsCompleted = true
    @State private var confirmsClear = false

    var panel: any Panel
    var model: any Model

    var origin: Reference? { model.session.opened.document ?? model.session.space }

    var refs: [Reference] {
        if let document = model.session.opened.document { return [document] }
        guard let origin else { return [] }
        return Space.with(origin, { $0.documents })
        ?? []
    }

    var tasks: [ScintRuntime.Document.Block] {
        refs.flatMap { document in
            Document.with(document) { document in
                document.blocks.filter { if case .task = $0 { true } else { false } }
            } ?? []
        }
    }

    var completed: Int {
        tasks.filter { if case .task(_, _, true) = $0 { true } else { false } }.count
    }

    var visibleTasks: [ScintRuntime.Document.Block] {
        guard !showsCompleted else { return tasks }
        return tasks.filter { if case .task(_, _, false) = $0 { true } else { false } }
    }

    var visibleDocuments: [Reference] {
        guard !showsCompleted else { return refs }
        return refs.filter { document in
            Document.with(document) { value in
                value.blocks.contains { if case .task(_, _, false) = $0 { true } else { false } }
            } == true
        }
    }

    var hide: Void {
        for ref in refs {
            Document.update(ref) { value in
                let completed = value.blocks.indices.filter { index in
                    if case .task(_, _, true) = value.blocks[index] { true } else { false }
                }
                for index in completed.reversed() { value.delete(at: index) }
            }
        }
    }

    var body: some View {
        ScrollView {
            ZStack(alignment: .top) {
                LazyVStack(alignment: .leading, spacing: Style.Spacing.entry) {
                    ForEach(refs) { ref in
                        TasksSection(
                            panel: panel,
                            model: model,
                            ref: ref,
                            showsCompleted: showsCompleted
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal, Style.Spacing.page)
                .padding(.top, Style.Spacing.inset)
                .padding(.bottom, Style.Spacing.page)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .confirmationDialog("Clear completed tasks?", isPresented: $confirmsClear, titleVisibility: .visible) {
                Button("Clear \(completed) Completed \(completed == 1 ? "Task" : "Tasks")", role: .destructive) {
                    hide
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This removes completed tasks from their documents.")
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .vertical)
    }
}
