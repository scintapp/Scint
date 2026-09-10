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
