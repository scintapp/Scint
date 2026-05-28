import Foundation
import SwiftUI
import AgencyRuntime


struct LayoutPicker: View {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        @Bindable var content = agency.studio.content

        if agency.studio.content.model != .sheet {
            Picker("Layout", selection: $content.layout) {
                Group {
                    Image(systemName: "square.grid.2x2")
                        .tag(Layout.grid)

                    Image(systemName: "list.bullet")
                        .tag(Layout.table)
                }
            }
            .buttonSizing(.automatic)
            .buttonStyle(.automatic)
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }
}

struct InspectorPicker: View {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        @Bindable var inspector = agency.studio.inspector
        Picker("Layout", selection: $inspector.context) {
            Group {
                Image(systemName: "list.bullet")
                    .tag(Inspector.Context.processing)
                Image(systemName: "sidebar.squares.trailing")
                    .tag(Inspector.Context.authoring)

            }
            .buttonSizing(.automatic)
            .buttonStyle(.automatic)
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }
}
