import SwiftUI


struct Editor: View {
    @Environment(ScintModel.self) var scint
    @Environment(EditorModel.self) var model

    var body: some View {
        NavigationSplitView {
            model.navigator.surface(model)
        } detail: {
            model.editor.surface(model)
        }
        .environment(scint)
        .toolbar(removing: .title)
    }
}

struct Studio: View {
    @Environment(ScintModel.self) var scint
    @Environment(StudioModel.self) var model

    var body: some View {
        let inspectorPresented = model.assistant.bindable.presented

        NavigationSplitView {
            ZStack(alignment: .trailing) {
                model.navigator.surface(model)

                Rectangle()
                    .fill(Style.Border.divider)
                    .ignoresSafeArea()
                    .frame(maxWidth: 1, maxHeight: .infinity, alignment: .trailing)
            }
        } detail: {
            model.canvas.surface(model)

        }
        .inspector(isPresented: inspectorPresented) {
            model.assistant.surface(model)
                .environment(scint)
                .inspectorColumnWidth(min: 240, ideal: 320, max: 480)
                .ignoresSafeArea(.all, edges: .top)
        }
        .environment(scint)
        .toolbar(removing: .title)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
    }
}
