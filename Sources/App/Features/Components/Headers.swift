import AgencyRuntime
import SwiftUI


struct Breadcrumbs: View {
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

struct ContentHeader: View {
    @Environment(AgencyModel.self) var agency
    private var focused: Reference? { agency.session.selected.space }

    var body: some View {
        HStack(alignment: .center) {
            if let focused {
                Text(focused.descriptor.name)
                    .frame(height: 50, alignment: .center)
                    .font(.system(size: 14, weight: .medium))
            }
        }
        .ignoresSafeArea(.all, edges: .top)
        .frame(maxWidth: .infinity, maxHeight: 50, alignment: .leading)
        .padding(12)
    }
}

struct DetailHeader: View {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        HStack(alignment: .center) {
            Breadcrumbs()
                .frame(height: 50, alignment: .center)
        }
        .ignoresSafeArea(.all, edges: .top)
        .frame(maxWidth: .infinity, maxHeight: 50, alignment: .leading)
        .padding(12)
    }
}
