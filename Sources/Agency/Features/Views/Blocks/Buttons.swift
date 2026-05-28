import Foundation
import SwiftUI
import AgencyRuntime


struct ComposeButton: View {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        PanelToggle(id: "compose", icon: "bubble.left.and.text.bubble.right") { EmptyView() }
    }
}

struct PathBar: View {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        @Bindable var content = agency.studio.content
        HStack(spacing: 0) { Breadcrumbs() }
            .frame(maxWidth: .infinity, maxHeight: 26, alignment: .center)
            .padding(.bottom, 6)
    }
}

struct RunButton: View {
    var body: some View {
        Button { } label: {
            Image(systemName: "arrowshape.up")
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
