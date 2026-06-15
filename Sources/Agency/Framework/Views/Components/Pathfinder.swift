import AgencyRuntime
import SwiftUI


struct Pathfinder: View {
    @Environment(AgencyModel.self) var agency
    var refs: [Reference] { agency.session.path }

    var body: some View {
        HStack(alignment: .center) {
            ForEach(Array(refs.enumerated()), id: \.element) { index, ref in
                Button { agency.select(ref) } label: {
                    Group {
                        Image(systemName: Design.Component.icon(for: ref))
                            .frame(maxWidth: 10)
                            .font(.system(size: 16))
                        Text(Runtime.shared.get(ref).name)
                            .font(.system(size: 11, weight: .light))
                    }
                    .frame(height: 30, alignment: .center)
                    .foregroundStyle(.primary.opacity(0.9))

                    if index < refs.count - 1 {
                        Image(systemName: "chevron.compact.forward")
                            .font(.system(size: 16, weight: .light))
                            .foregroundStyle(.primary.opacity(0.7))
                            .frame(maxWidth: 4)
                    }
                }
                .padding(.horizontal, 2)
                .buttonStyle(.plain)
            }
        }
    }
}
