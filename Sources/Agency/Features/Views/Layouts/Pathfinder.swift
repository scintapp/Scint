import Foundation
import SwiftUI
import AgencyRuntime


struct Breadcrumbs: View {
    @Environment(AgencyModel.self) var agency

    var refs: [Reference] { agency.session.path }

    func segment(_ ref: Reference) -> some View {
        return HStack(spacing: 6) {
            Image(systemName: Design.Component.icon(for: ref))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary.opacity(0.9))

            Text(Runtime.shared.get(ref).name)
                .font(.system(size: 12, weight: .light))
                .foregroundStyle(.primary.opacity(0.9))
        }
        .frame(maxHeight: 28, alignment: .center)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            Group {
                ForEach(Array(refs.enumerated()), id: \.element) { index, ref in
                    Button { agency.select(ref) } label: {
                        segment(ref)
                    }

                    if index < refs.count - 1 {
                        Image(systemName: "chevron.compact.forward")
                            .font(.system(size: 16, weight: .light))
                            .foregroundStyle(.primary.opacity(0.7))
                            .padding(.leading, 1)
                            .padding(.trailing, 2)
                    }
                }
            }
            .frame(maxHeight: 28, alignment: .center)
            .buttonStyle(.plain)
        }
    }
}

struct Pathfinder: View {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        @Bindable var content = agency.studio.content

        HStack(spacing: 0) {
            Breadcrumbs()
            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: 30, alignment: .center)
    }
}
