import SwiftUI


struct OutlineControls: View {
    @State var hovered: Bool = false
    let model: any Model
    let icons: Bool

    var refs: [Reference] {
        model.session.navigation.path(for: model.session.selected, in: model.session.workspace)
            .filter { $0.type != Material.self }
    }

    var body: some View {
        HStack(alignment: .center) {
            SwiftUI.Menu {
                ForEach(Array(refs.enumerated()), id: \.element) { index, ref in
                    Button { model.select(ref) } label: {
                        HStack {
                            if icons { Iconography.icon(for: ref, size: 13) }
                            Text(ref.descriptor.name).font(.system(size: 12))

                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "list.number")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(.quaternary, in: Circle())
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(.quaternary, in: Circle())
                }
                .font(.system(size: 12))
                .contentShape(.capsule)
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
    }
}

struct StatusBar: View {
    var model: any Model

    var ref: Reference { model.session.material ?? model.session.origin }

    var words: String { "\(metrics.words) \(metrics.words == 1 ? "Word" : "Words")" }
    var tasks: String { "\(metrics.completedTasks) of \(metrics.totalTasks) \(metrics.totalTasks == 1 ? "Task" : "Tasks")" }

    var metrics: (words: Int, completedTasks: Int, totalTasks: Int) {
        Material.with(ref) { material in
            let words = material.rendered.split(whereSeparator: { $0.isWhitespace }).count
            let tasks = material.blocks.compactMap { block -> Bool? in
                guard case .task(_, _, let completed) = block else { return nil }
                return completed }
            return (words, tasks.filter { $0 }.count, tasks.count)
        } ?? (0, 0, 0)
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(words)
            Text(tasks)
        }
        .frame(alignment: .center)
        .foregroundStyle(Style.Foreground.muted)
        .font(.callout)
    }
}

struct EditorBar: View {
    var model: any Model

    var ref: Reference { model.session.material ?? model.session.origin }

    var body: some View {
        HStack(spacing: 12) {

        }
        .foregroundStyle(Style.Foreground.muted)
        .font(.callout)
    }
}
