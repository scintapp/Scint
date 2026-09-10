import SwiftUI


struct Assistant: View {
    @Environment(ScintModel.self) var model

    var body: some View {
        let assistant = model.assistant
        assistant.content.surface(assistant)
            .environment(model)
            .environment(assistant)
            .toolbar(removing: .title)
    }
}

struct Editor: View {
    @Environment(ScintModel.self) var model

    var body: some View {
        let content = model.editor.content.surface(model.editor)
        let navigator = model.editor.navigator.surface(model.editor)

        NavigationSplitView(sidebar: { navigator }, detail: { content })
            .environment(model)
            .environment(model.editor)
            .scrollEdgeEffectHidden()
            .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
    }
}

struct Studio: View {
    @Environment(ScintModel.self) var model

    var body: some View {
        let studio = model.studio
        let content: some View = studio.content.surface(studio)
        let inspector: some View = studio.inspector.surface(studio)
        let navigator: some View = studio.navigator.surface(studio)
        let presented = studio.inspector.bindable.presented

        NavigationSplitView {
            navigator
        } detail: {
            ZStack(alignment: .top) {
                content.frame(maxWidth: .infinity)
                    .background(Style.Background.base)
                Rectangle()
                    .fill(Style.Border.base)
                    .frame(height: 0.75, alignment: .top)
            }
        }
        .environment(model)
        .environment(studio)
        .toolbar(removing: .title)
        .inspector(isPresented: presented) {
            inspector.inspectorColumnWidth(ideal: 340)
        }
    }
}
