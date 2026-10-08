import SwiftUI
import ScintComponents


struct AppView: View {
    @Environment(AppModel.self) var app
    @Environment(ScintModel.self) var scint

    var body: some View {
        NavigationSplitView {
            app.navigator.surface(app)
        } detail: {
            app.content.surface(app)
        }
        .inspector(isPresented: app.inspector.bindable.presented) {
            app.inspector.surface(app)
                .inspectorColumnWidth(min: 240, ideal: 320, max: 480)
                .ignoresSafeArea(.all, edges: .top)
        }
        .environment(scint)
        .environment(scint.app)
        .toolbar(removing: .title)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .toolbarBackgroundVisibility(.hidden, for: .automatic)
        .scrollEdgeEffectHidden(for: .bottom)
    }
}

