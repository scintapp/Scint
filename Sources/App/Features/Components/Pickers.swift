import Foundation
import SwiftUI
import AgencyRuntime


struct LayoutPicker: View {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        @Bindable var detail = agency.studio.detail

        Picker("Layout", selection: $detail.layout) {
            Group {
                Image(systemName: "square.grid.2x2").tag(Layout.grid)
                Image(systemName: "list.bullet").tag(Layout.table)
            }
        }
        .pickerStyle(.segmented)
        .buttonStyle(.automatic)
        .buttonSizing(.automatic)
        .labelsHidden()
    }
}

