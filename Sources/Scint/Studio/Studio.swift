import SwiftUI
import ScintComponents


struct Studio: View {
    @Environment(ScintModel.self) var scint
    @Environment(StudioModel.self) var model

    var body: some View {
        NavigationSplitView {
            model.navigator.surface(model)
        } detail: {
            model.content.surface(model)
        }
        .inspector(isPresented: model.inspector.bindable.presented) {
            model.inspector.surface(model)
                .inspectorColumnWidth(min: 240, ideal: 320, max: 480)
                .ignoresSafeArea(.all, edges: .top)
        }
        .environment(scint)
        .environment(scint.app)
        .environment(scint.app.studio)
        .toolbar(removing: .title)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .toolbarBackgroundVisibility(.hidden, for: .automatic)
        .scrollEdgeEffectHidden(for: .bottom)
    }
}
