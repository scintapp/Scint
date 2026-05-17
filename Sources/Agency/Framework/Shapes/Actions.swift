import SwiftUI
import AgencyRuntime


struct QuickActions: View {
    @Environment(AgencyModel.self) var agency
    var boundary: Reference? { agency.session.boundary }
    var space: Reference? { agency.session.space }

    var body: some View {
        @Bindable var content = agency.studio.content

        HStack {
            Divider()
                .frame(height: 16)
                .padding(.horizontal, 6)

            Menu {
                if boundary != nil {
                    Button { } label: { Label("New Sheet", systemImage: "text.alignleft") }
                    Button { } label: { Label("New Boundary", systemImage: "app") }
                    Divider()
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(.secondary)
            }
            .menuIndicator(.hidden)
            .menuStyle(.borderlessButton)
        }
        .font(.system(size: 17, weight: .light))
        .controlSize(.extraLarge)
    }
}
