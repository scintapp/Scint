import SwiftUI


struct Host: View {
    @Environment(ScintModel.self) var scint
    @Environment(HostModel.self) var server
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(scint.host.running ? "Server Running" : "Server Stopped")
        if let message = scint.host.message, !message.isEmpty { Text(message) }
        Divider()
        if scint.host.running { Button("Stop Scint Server") { Task { await scint.host.unload() } } }
        else { Button("Start Scint Server") { Task { await scint.host.load() } } }
        Button("Copy Server Address") { NSPasteboard.general.setString(ContextServer.url.absoluteString, forType: .string) }
        Divider()
        Button("Scint Studio") { openWindow(id: "studio") }
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
            .toolbar(removing: .title)
    }
}

struct Studio: View {
    @Environment(ScintModel.self) var scint
    @Environment(StudioModel.self) var studio

    var body: some View {
        let presented = studio.inspector.state.bindable.presented
        let content: some View = studio.content.surface(studio)
        let inspector: some View = studio.inspector.surface(studio)
        let navigator: some View = studio.navigator.surface(studio)

        NavigationSplitView(sidebar: { navigator }, detail: { content })
            .environment(scint)
            .environment(studio)
            .background(Style.Background.page)
            .inspector(isPresented: presented) { inspector }
            .toolbar(removing: .title)
    }
}
