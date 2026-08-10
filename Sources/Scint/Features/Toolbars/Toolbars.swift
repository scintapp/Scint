import SwiftUI


struct ActionsBar: View {
    let model: any Model

    var body: some View {
        HStack {
            Spacer()
            Button { } label: {
                Image(systemName: "plus")
                    .frame(height: 30, alignment: .center)
                    .foregroundStyle(Design.Foreground.secondary)
                    .font(.system(size: 13))
            }
            .frame(height: 30, alignment: .center)
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: 30, alignment: .leading)
        .padding(.horizontal, 12)
    }
}

struct WorkspaceControls: View {
    let model: any Model

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading) {
                Text(model.session.workspace.descriptor.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Design.Foreground.primary)
                Text("3 Active Spaces")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Design.Foreground.tertiary)
            }
            .frame(height: 30, alignment: .center)
        }
        .padding(.leading, 6)
    }
}

struct NavigationControls: View {
    let model: any Model

    var body: some View {
        ControlGroup {
            Button {
                if let selection = model.session.back() {
                    if let content = selection.content, content.type is Scene.Type { model.focus(content) }
                    else if let structure = selection.structure { model.focus(structure) }
                }
            } label: { Image(systemName: "chevron.backward") }
                .disabled(!model.session.navigation.canGoBack)
            Button {
                if let selection = model.session.forward() {
                    if let content = selection.content, content.type is Scene.Type { model.focus(content) }
                    else if let structure = selection.structure { model.focus(structure) }
                }
            } label: { Image(systemName: "chevron.forward") }
                .disabled(!model.session.navigation.canGoForward)
        }
        .controlGroupStyle(.navigation)
    }
}

struct EditorBar: View {
    var model: any Model
    var ref: Reference { model.session.scene ?? model.session.origin }

    var words: String { "\(metrics.words) \(metrics.words == 1 ? "Word" : "Words")" }
    var tasks: String { "\(metrics.completedTasks) of \(metrics.totalTasks) \(metrics.totalTasks == 1 ? "Task" : "Tasks")" }
    var metrics: (words: Int, completedTasks: Int, totalTasks: Int) {
        Scene.with(ref) { scene in
            let words = scene.rendered.split(whereSeparator: { $0.isWhitespace }).count
            let tasks = scene.blocks.compactMap { block -> Bool? in
                guard case .task(_, _, let completed) = block else { return nil }
                return completed }
            return (words, tasks.filter { $0 }.count, tasks.count)
        } ?? (0, 0, 0)
    }

    var body: some View {
        HStack(spacing: 15) {
            Text(words)
            Text(tasks)
        }
        .frame(alignment: .center)
        .foregroundStyle(Design.Foreground.secondary)
        .font(.callout)
    }
}

struct OutlineControls: View {
    @State var hovered: Bool = false
    let model: any Model
    let icons: Bool

    var refs: [Reference] {
        model.session.navigation.path(for: model.session.selected, in: model.session.workspace)
            .filter { $0.type != Scene.self }
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

struct ContextControls: View {
    let model: any Model
    var origin: Reference { model.session.origin }
    var context: Composition? { origin.context }
    var active: Bool { context?.state == .active }

    var body: some View {
        HStack(alignment: .center) {
            Button { } label: {
                Iconography
                    .icon(for: origin, size: 12)
                    .frame(maxWidth: 30, maxHeight: 30, alignment: .center)
            }

            Color.clear.frame(width: 30, height: 30)

            Button { } label: {
                Text(origin.descriptor.name)
                    .frame(minWidth: 96)
                    .font(.system(size: 13))
            }


            Button { } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 12))
                    .frame(maxWidth: 30, maxHeight: 30, alignment: .center)
            }

            Button { } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 12))
                    .frame(maxWidth: 30, maxHeight: 30, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 30)
    }
}
