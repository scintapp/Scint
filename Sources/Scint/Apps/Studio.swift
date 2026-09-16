import SwiftUI


@Observable @MainActor final class StudioModel: Model {
    var content: ContentPanel
    var inspector: InspectorPanel
    var navigator: NavigatorPanel
    var session: Session

    init(_ session: Session) {
        self.content = .init()
        self.inspector = .init()
        self.navigator = .init()
        self.session = session
    }
}

struct Studio: View {
    @Environment(ScintModel.self) var scint
    @Environment(StudioModel.self) var model

    var body: some View {
        let inspectorPresented = model.inspector.bindable.presented

        NavigationSplitView {
            ZStack(alignment: .trailing) {
                model.navigator.surface(model)

                Rectangle()
                    .fill(Style.Border.divider)
                    .ignoresSafeArea()
                    .frame(maxWidth: 1, maxHeight: .infinity, alignment: .trailing)
            }
        } detail: {
            model.content.surface(model)
        }
        .inspector(isPresented: inspectorPresented) {
            model.inspector.surface(model)
                .inspectorColumnWidth(min: 240, ideal: 320, max: 480)
                .ignoresSafeArea(.all, edges: .top)
        }
        .environment(scint)
        .environment(scint.app)
        .environment(scint.app.studio)
        .toolbar(removing: .title)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
    }
}
