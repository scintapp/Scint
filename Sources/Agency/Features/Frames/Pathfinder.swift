import Foundation
import SwiftUI
import AgencyRuntime


struct Breadcrumbs: View {
    @Environment(AgencyModel.self) var agency

    var refs: [Reference] { agency.session.path }

    func segment(_ ref: Reference) -> some View {
        HStack(spacing: 6) {
            Image(systemName: Design.Component.icon(for: ref))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.primary.opacity(0.8))
            Text(Runtime.shared.get(ref).name)
                .font(.system(size: 11, weight: .light))
                .foregroundStyle(.primary.opacity(0.9))
        }
        .frame(maxHeight: 30, alignment: .center)
    }

    var body: some View {
        HStack(spacing: 4) {
            Group {
                ForEach(Array(refs.enumerated()), id: \.element.id) { index, ref in
                    Button { agency.select(ref) } label: {
                        segment(ref)
                    }

                    if index < refs.count - 1 {
                        Image(systemName: "chevron.compact.forward")
                            .font(.system(size: 17, weight: .light))
                            .foregroundStyle(.primary.opacity(0.9))
                            .padding(.trailing, 2)
                    }
                }
            }
            .frame(maxHeight: 30, alignment: .center)
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
            QuickActions()
        }
        .frame(maxWidth: .infinity, maxHeight: 30, alignment: .center)
        .padding(.bottom, 6)
    }
}
