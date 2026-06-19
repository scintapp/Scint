import AgencyRuntime
import SwiftUI


struct Pathfinder: View {
    @Environment(AgencyModel.self) var agency
    var refs: [Reference] { agency.session.navigation.path(for: agency.session.selected, in: agency.session.workspace) }

    var body: some View {
        HStack(alignment: .center) {
            ForEach(Array(refs.enumerated()), id: \.element) { index, ref in
                Button { agency.select(ref) } label: {
                    Group { Iconography.icon(for: ref) }
                        .font(.system(size: 13, weight: .light))
                    Text(ref.descriptor.name)
                    if index < refs.count - 1 {
                        Image(systemName: "chevron.compact.forward").font(.system(size: 15, weight: .light))
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
