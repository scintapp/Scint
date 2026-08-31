import SwiftUI


struct TaskCompletionIndicator: View {
    var completed: Bool

    var body: some View {
        Image(systemName: completed ? "largecircle.fill.circle" : "circle")
            .symbolRenderingMode(.hierarchical)
            .font(.system(size: 17, weight: .regular))
            .foregroundStyle(completed ? Style.Tint.task : Style.Foreground.faint)
            .frame(width: 18, height: 18)
            .accessibilityHidden(true)
    }
}

struct TaskItem: View {
    var material: Reference
    var task: Material.Block

    var body: some View {
        if case .task(_, let text, let completed) = task {
            Button { toggle(task.id) } label: {
                HStack(alignment: .top, spacing: Style.Spacing.lg) {
                    TaskCompletionIndicator(completed: completed)
                        .padding(.top, 1)
                    Text(text)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(completed ? Style.Foreground.faint : Style.Foreground.base)
                        .strikethrough(completed, color: Style.Foreground.disabled)
                        .lineSpacing(Style.Spacing.xs)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: .zero)
                }
                .padding(.vertical, Style.Spacing.sm + 1)
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
        Material.update(material) { material in
            guard let index = material.blocks.firstIndex(where: { $0.id == id }),
                  case .task(let id, let text, let completed) = material.blocks[index]
                    else { return }
            material.update(.task(id, text, !completed), at: index)
        }
    }
}

struct TasksHeader: View {
    var completed: Int
    var showsCompleted: Bool
    var onToggleCompleted: () -> Void
    var onClearCompleted: () -> Void

    var body: some View {
        VStack(spacing: Style.Spacing.md) {
            HStack(spacing: Style.Spacing.sm + 1) {
                Text("\(completed) Completed")
                    .foregroundStyle(Style.Foreground.muted)

                Text("•")
                    .foregroundStyle(Style.Foreground.faint)

                Button("Clear", action: onClearCompleted)
                    .buttonStyle(.plain)
                    .foregroundStyle(completed > 0 ? Style.Tint.task : Style.Foreground.faint)
                    .disabled(completed == 0)

                Spacer(minLength: Style.Spacing.md)

                Button(showsCompleted ? "Hide" : "Show", action: onToggleCompleted)
                    .buttonStyle(.plain)
                    .foregroundStyle(Style.Tint.task)
            }
            .font(.system(size: 13, weight: .regular))

            Rectangle()
                .fill(Style.Border.group)
                .frame(height: 0.5)
        }
    }
}

struct TasksSection: View {
    @State private var expanded = true

    var model: any Model
    var material: Reference
    var showsCompleted: Bool

    var allTasks: [Material.Block] {
        Material.with(material) { material in
            material.blocks.filter { if case .task = $0 { true } else { false } }
        } ?? []
    }

    var tasks: [Material.Block] {
        guard !showsCompleted else { return allTasks }
        return allTasks.filter { if case .task(_, _, false) = $0 { true } else { false } }
    }

    var body: some View {
        if !allTasks.isEmpty {
            VStack(alignment: .leading, spacing: Style.Spacing.md) {
                HStack(spacing: Style.Spacing.md) {
                    Button { model.open(material) } label: {
                        Text(material.descriptor.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Style.Foreground.base)
                            .lineLimit(Style.Limit.singleLine)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.smooth(duration: 0.18)) { expanded.toggle() }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Style.Foreground.subtle)
                            .rotationEffect(.degrees(expanded ? .zero : -90))
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(expanded ? "Collapse tasks" : "Expand tasks")
                }

                if expanded {
                    VStack(alignment: .leading, spacing: Style.Spacing.xs) {
                        ForEach(tasks) { task in
                            TaskItem(material: material, task: task)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
}

struct TasksSurface: Surface {
    @State private var showsCompleted = true
    @State private var confirmsClear = false

    var panel: any Panel
    var model: any Model

    var origin: Reference { model.session.origin }

    var materials: [Reference] {
        Space.with(origin, { $0.materials })
        ?? Workspace.with(origin, { $0.materials })
        ?? []
    }

    var tasks: [Material.Block] {
        materials.flatMap { material in
            Material.with(material) { material in
                material.blocks.filter { if case .task = $0 { true } else { false } }
            } ?? []
        }
    }

    var completed: Int {
        tasks.filter { if case .task(_, _, true) = $0 { true } else { false } }.count
    }

    var visibleTasks: [Material.Block] {
        guard !showsCompleted else { return tasks }
        return tasks.filter { if case .task(_, _, false) = $0 { true } else { false } }
    }

    var visibleMaterials: [Reference] {
        guard !showsCompleted else { return materials }
        return materials.filter { material in
            Material.with(material) { value in
                value.blocks.contains { if case .task(_, _, false) = $0 { true } else { false } }
            } == true
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            
            TasksHeader(
                completed: completed,
                showsCompleted: showsCompleted,
                onToggleCompleted: { withAnimation(.smooth(duration: 0.18)) { showsCompleted.toggle() } },
                onClearCompleted: { confirmsClear = true }
            )
            .padding(.horizontal, Style.Spacing.xl)
            .padding(.top, Style.Spacing.lg)

            LazyVStack(alignment: .leading, spacing: Style.Spacing.xxl) {
                Color.clear.frame(height: Style.Spacing.xxl)
                ForEach(visibleMaterials) { material in
                    TasksSection(
                        model: model,
                        material: material,
                        showsCompleted: showsCompleted
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, Style.Spacing.xl)
            .padding(.top, Style.Spacing.lg)
            .padding(.bottom, Style.Spacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .confirmationDialog("Clear completed tasks?", isPresented: $confirmsClear, titleVisibility: .visible) {
            Button("Clear \(completed) Completed \(completed == 1 ? "Task" : "Tasks")", role: .destructive) {
                clear()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes completed tasks from their materials.")
        }
    }

    private func clear() {
        for material in materials {
            Material.update(material) { value in
                let completed = value.blocks.indices.filter { index in
                    if case .task(_, _, true) = value.blocks[index] { true } else { false }
                }
                for index in completed.reversed() { value.delete(at: index) }
            }
        }
    }
}
