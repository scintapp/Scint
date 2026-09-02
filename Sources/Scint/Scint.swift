import SwiftUI


struct Assistant: View {
    @Environment(ScintModel.self) var scint
    @Environment(AssistantModel.self) var assistant

    var body: some View {
        assistant.content.surface(assistant)
            .environment(scint)
            .environment(assistant)
            .scrollEdgeEffectHidden()
            .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
    }
}

struct Editor: View {
    @Environment(ScintModel.self) var scint
    @Environment(EditorModel.self) var editor

    var body: some View {
        let content = editor.content.surface(editor)
        let navigator = editor.navigator.surface(editor)

        NavigationSplitView(sidebar: { navigator }, detail: { content })
            .environment(scint)
            .environment(editor)
            .scrollEdgeEffectHidden()
            .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
    }
}

struct Studio: View {
    @Environment(ScintModel.self) var scint
    @Environment(StudioModel.self) var studio

    var body: some View {
        let content: some View = studio.content.surface(studio)
        let inspector: some View = studio.inspector.surface(studio)
        let navigator: some View = studio.navigator.surface(studio)
        let presented = studio.inspector.state.bindable.presented

        NavigationSplitView {
            navigator
        } detail: {
            content.frame(maxWidth: .infinity)
                .background(Style.Background.panel)
        }
        .environment(scint)
        .environment(studio)
        .toolbar(removing: .title)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .inspector(isPresented: presented) {
            inspector.inspectorColumnWidth(ideal: 340)
        }
    }
}
