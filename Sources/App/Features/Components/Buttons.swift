import SwiftUI
import AgencyRuntime


struct RunButton: View {
    var body: some View {
        Button { } label: {
            Image(systemName: "arrowshape.up")
        }
    }
}

struct NewItemButton: View {
    @Environment(AgencyModel.self) var agency
    var space: Reference? { agency.session.selected.space }

    var body: some View {
        Button { } label: {
            Image(systemName: "plus")
        }
    }
}

struct OutlineButton: View {
    var body: some View {
        Button { } label: {
            Image(systemName: "list.bullet")
        }
    }
}

struct QuickActions: View {
    @Environment(AgencyModel.self) var agency
    var workspace: Reference { agency.session.workspace }
    var space: Reference? { agency.session.selected.space }

    var body: some View {
        HStack {
            Divider()
                .frame(height: 16)
                .padding(.horizontal, 6)
            Menu {
                if space != nil {
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
