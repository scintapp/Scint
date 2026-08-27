import SwiftUI


struct TaskItem: View {
    var material: Reference
    var task: Material.Block

    var body: some View {
        if case .task(_, let text, let completed) = task {
            Button { toggle(task.id) } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: completed ? "largecircle.fill.circle" : "circle")
                        .font(.system(size: 13))
                        .foregroundStyle(completed ? Style.Tint.task : Style.Foreground.faint)

                    Text(text)
                        .font(Typography.row)
                        .foregroundStyle(completed ? Style.Foreground.faint : Style.Foreground.base)
                        .strikethrough(completed, color: Style.Foreground.disabled)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
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
    var body: some View { EmptyView() }
}

struct TasksSection: View {
    var material: Reference
    var model: any Model

    var tasks: [Material.Block] {
        Material.with(material) { material in
            material.blocks.filter { if case .task = $0 { true } else { false } }
        } ?? []
    }

    var body: some View {
        if !tasks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Button { model.open(material) } label: {
                    Text(material.descriptor.name)
                        .font(Typography.cardTitle)
                        .foregroundStyle(Style.Foreground.base)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                ForEach(tasks) { task in
                    TaskItem(material: material, task: task)
                }
            }
        }
    }
}

struct TasksSurface: Surface {
    var panel: any Panel
    var model: any Model

    var origin: Reference { model.session.origin }
    var materials: [Reference] { Space.with(origin, { $0.materials }) ?? [] }
    var tasks: [Material.Block] {
        materials.flatMap { material in
            Material.with(material) { material in
                material.blocks.filter { if case .task = $0 { true } else { false } }
            } ?? []
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                if tasks.isEmpty {
                    Text("No tasks in this space.")
                        .font(Typography.row)
                        .foregroundStyle(Style.Foreground.disabled)
                } else {
                    ForEach(materials) { material in
                        TasksSection(material: material, model: model)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding([.horizontal, .top], 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .scrollEdgeEffectStyle(.hard, for: .top)
    }
}
