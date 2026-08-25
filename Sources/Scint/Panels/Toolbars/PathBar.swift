import SwiftUI


struct PathButton: View {
    var model: any Model
    var ref: Reference
    var label: Bool = true
    var last: Bool = false

    var body: some View {
        Button { model.select(ref) } label: {
            HStack {
                Iconography.icon(for: ref, size: 11)

                if label { Text(ref.descriptor.name).font(.system(size: 12)) }

                if !last {
                    Image(systemName: "chevron.compact.forward")
                        .frame(maxWidth: 4)
                        .foregroundStyle(Style.Foreground.tertiary)
                        .font(.system(size: 13, weight: .light))
                        .opacity(0.8)
                }
            }
        }
        .buttonStyle(.plain)
        .background {  }
    }
}

struct PathBar: View {
    let model: any Model
    @State var hovered: Bool = false

    var refs: [Reference] {
        model.session.navigation.path(for: model.session.selected, in: model.session.workspace)
            .filter { $0.type != Workspace.self }
    }

    var body: some View {
        HStack {
            PathButton(model: model, ref: model.session.workspace, last: refs.isEmpty)

            ForEach(Array(refs.enumerated().dropLast(1)), id: \.element) { index, ref in
                PathButton(model: model, ref: ref, last: refs.last == ref)
            }

            if let space = model.session.selected.space {
                if model.session.selected.content != nil {
                    PathButton(model: model, ref: space)
                    PathButton(model: model, ref: space, last: true)
                } else {
                    PathButton(model: model, ref: space, last: true)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 30, alignment: .leading)
        .onHover { _ in hovered.toggle() }
    }
}
