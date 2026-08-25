import SwiftUI


struct TasksSurface: Surface {
    var panel: any Panel
    var model: any Model

    @State private var hidesCompleted = false

    private struct Group: Identifiable {
        let ref: Reference
        let tasks: [(index: Int, id: UUID, title: String, done: Bool)]
        var id: Reference { ref }
    }

    private var origin: Reference { model.session.origin }

    private var groups: [Group] {
        let materials = (Space.with(origin, { $0.materials }) ?? Workspace.with(origin, { $0.materials }) ?? [])
            .filter { !$0.descriptor.tags.contains("input") }

        return materials.compactMap { ref in
            let tasks = Material.with(ref) { material in
                material.blocks.enumerated().compactMap { index, block -> (Int, UUID, String, Bool)? in
                    guard case .task(let id, let title, let done) = block else { return nil }
                    return (index, id, title, done)
                }
            } ?? []
            guard !tasks.isEmpty else { return nil }
            return Group(ref: ref, tasks: tasks)
        }
    }

    private var total: Int { groups.reduce(0) { $0 + $1.tasks.count } }

    private var completed: Int { groups.reduce(0) { $0 + $1.tasks.filter(\.done).count } }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(model.session.origin.descriptor.name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Style.Foreground.primary)

                Spacer(minLength: 0)

                Text("\(total - completed)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Style.Foreground.tertiary)
            }

            HStack(spacing: 6) {
                Text("\(completed) Completed")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Style.Foreground.tertiary)

                Spacer(minLength: 0)

                Button(hidesCompleted ? "Show" : "Hide") { hidesCompleted.toggle() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Style.Foreground.accent)
            }

            Rectangle()
                .fill(Style.Border.card)
                .frame(height: 0.5)
        }
    }

    private func section(_ group: Group, _ tasks: [(index: Int, id: UUID, title: String, done: Bool)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { model.open(group.ref) } label: {
                Text(group.ref.descriptor.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Style.Foreground.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            ForEach(tasks, id: \.id) { task in
                Button { toggle(group.ref, at: task.index) } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: task.done ? "largecircle.fill.circle" : "circle")
                            .font(.system(size: 13))
                            .foregroundStyle(task.done ? Style.Tint.task : Style.Foreground.tertiary)

                        Text(task.title)
                            .font(.system(size: 12.5))
                            .foregroundStyle(task.done ? Style.Foreground.tertiary : Style.Foreground.primary)
                            .strikethrough(task.done, color: Style.Foreground.disabled)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggle(_ ref: Reference, at index: Int) {
        Material.update(ref) { material in
            guard index < material.blocks.count,
                  case .task(let id, let title, let done) = material.blocks[index]
            else { return }
            material.update(.task(id, title, !done), at: index)
        }
    }

    var body: some View {
        ScrollView {
            Color.clear.frame(height: 24)
            VStack(alignment: .leading, spacing: 18) {
                header

                if groups.isEmpty {
                    Text("No tasks in this space.")
                        .font(.system(size: 12))
                        .foregroundStyle(Style.Foreground.disabled)
                        .padding(.top, 4)
                } else {
                    ForEach(groups) { group in
                        let visible = hidesCompleted ? group.tasks.filter { !$0.done } : group.tasks
                        if !visible.isEmpty { section(group, visible) }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .scrollEdgeEffectStyle(.hard, for: .top)
    }
}
