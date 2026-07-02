import SwiftUI


@Observable @MainActor final class FolioModel {
    let sidebar = Navigator()
    let content = DetailContent()
    let detail = Detail()
    let inspector = Inspector()
    let palette = Palette()
}

struct Folio: Feature {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        @Bindable var outline = agency.folio.inspector

        NavigationSplitView {
            agency.folio.sidebar.view(agency)
                .environment(agency)
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 340)
        } content: {
            agency.folio.content.view(agency)
                .environment(agency)
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 340)
        } detail: {
            agency.folio.detail.view(agency)
                .environment(agency)
        }
        .inspector(isPresented: $outline.presented) {
            agency.folio.inspector.view(agency)
                .environment(agency)
                .inspectorColumnWidth(min: 240, ideal: 360, max: 480)
        }
        .toolbar(removing: .title)
        .toolbar(removing: .sidebarToggle)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
    }
}

