import SwiftUI
import ScintComponents


struct Studio: View {
    @Environment(ScintModel.self) var scint
    @Environment(AppModel.self) var studio

    var body: some View {
        NavigationSplitView {
            studio.navigator.surface(studio)
        } detail: {
            studio.content.surface(studio)
        }
        .inspector(isPresented: studio.inspector.bindable.presented) {
            studio.inspector.surface(studio)
                .inspectorColumnWidth(min: 240, ideal: 320, max: 480)
                .ignoresSafeArea(.all, edges: .top)
        }
        .environment(scint)
        .environment(scint.studio)
        .toolbar(removing: .title)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .toolbarBackgroundVisibility(.hidden, for: .automatic)
        .scrollEdgeEffectHidden(for: .bottom)
    }
}
