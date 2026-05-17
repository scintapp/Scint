import Foundation
import SwiftUI
import AgencyRuntime


struct LayoutPicker: View {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        @Bindable var content = agency.studio.content

        Picker("Layout", selection: $content.model) {
            Image(systemName: "square.grid.2x2")
            Image(systemName: "list.bullet")
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .help("Show library items in a grid, list, or a table")
    }
}

struct ServicePicker: View {
    var body: some View {
        Button { } label: {
            HStack(alignment: .center, spacing: 4) {
                Text("Services")
                    .font(.system(size: 14, weight: .semibold))
                Text("Codex")
                    .font(.system(size: 14, weight: .light))
            }
            .frame(height: 36, alignment: .center)
            .padding(.horizontal, 4)
            .padding(.bottom, 2)
        }
    }
}
