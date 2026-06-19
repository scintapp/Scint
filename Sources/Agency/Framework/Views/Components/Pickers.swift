import Foundation
import SwiftUI
import AgencyRuntime


struct LayoutPicker: View {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        @Bindable var content = agency.studio.content

        Picker("Layout", selection: $content.layout) {
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

struct ModalityPicker: View {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        @Bindable var content = agency.studio.content

        Picker("Modality", selection: $content.model) {
            Group {
                Image(systemName: "square.3.stack.3d").tag(Content.Model.browser)
                Image(systemName: "circle.grid.2x2.topleft.checkmark.filled").tag(Content.Model.composer)
                Image(systemName: "doc.append").tag(Content.Model.writer)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}



//struct InspectorPicker: View {
//    @Environment(AgencyModel.self) var agency
//
//    var body: some View {
//        @Bindable var inspector = agency.studio.inspector
//        Picker("Layout", selection: $inspector.context) {
//            Group {
//                Image(systemName: "list.bullet")
//                    .tag(Inspector.Context.processing)
//                Image(systemName: "sidebar.squares.trailing")
//                    .tag(Inspector.Context.authoring)
//
//            }
//            .buttonSizing(.automatic)
//            .buttonStyle(.automatic)
//            .pickerStyle(.segmented)
//            .labelsHidden()
//        }
//    }
//}

