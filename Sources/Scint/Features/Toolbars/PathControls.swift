import SwiftUI


struct PathButton: View {
    var model: any Model
    var ref: Reference
    var last: Bool

    var body: some View {
        Button { model.select(ref) } label: {
            HStack {
                Iconography
                    .icon(for: ref, size: 11)
                Text(ref.descriptor.name)
                    .font(.system(size: 12))
                if !last {
                    Image(systemName: "chevron.compact.forward")
                        .frame(maxWidth: 4)
                        .foregroundStyle(Design.Foreground.tertiary)
                        .font(.system(size: 13, weight: .light))
                        .opacity(0.8)
                }
            }
        }
    }
}

struct PathBar: View {
    let model: any Model

    var refs: [Reference] {
        model.session.navigation.path(for: model.session.selected, in: model.session.workspace)
            .filter { $0.type != Material.self }
    }

    var body: some View {
        HStack(alignment: .center) {
            ForEach(Array(refs.enumerated()), id: \.element) { index, ref in
                PathButton(model: model, ref: ref, last: refs.last == ref)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: 30, alignment: .leading)
        .padding(.horizontal, 8)
    }
}

struct PathControls: View {
    @State var hovered: Bool = false
    let model: any Model
    var space: Reference? { model.session.selected.space }
    var workspace: Reference { model.session.workspace }
    var context: Composition? { model.session.origin.context }
    var active: Bool { context?.state == .active }

    var refs: [Reference] {
        model.session.navigation.path(for: model.session.selected, in: workspace)
            .filter { $0.type != Workspace.self }
            .filter { $0.type != Material.self }
    }

    var body: some View {
        HStack {
            PathButton(model: model, ref: workspace, last: refs.isEmpty)

            if hovered {
                ForEach(Array(refs.enumerated().dropLast(1)), id: \.element) { index, ref in
                    PathButton(model: model, ref: ref, last: refs.last == ref)
                }
            }

            if let space {
                PathButton(model: model, ref: space, last: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 30, alignment: .leading)
        .onHover { _ in hovered.toggle() }
    }
}
