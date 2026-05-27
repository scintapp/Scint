import Foundation
import SwiftUI
import AgencyRuntime


struct LayoutPicker: View {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        @Bindable var content = agency.studio.content

        if agency.studio.content.model != .sheet {
            Picker("Layout", selection: $content.layout) {
                Image(systemName: "square.grid.2x2")
                    .tag(Layout.grid)
                Image(systemName: "list.bullet")
                    .tag(Layout.table)
            }
            .glassEffect(.regular.tint(.black.opacity(0.05)))
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }
}

struct InspectorPicker: View {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        @Bindable var content = agency.studio.content

        ControlGroup {
            ComposerToggle()
            InspectorToggle()
        }
    }
}
