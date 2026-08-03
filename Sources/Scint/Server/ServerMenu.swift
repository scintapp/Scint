import AppKitimport SwiftUI


struct ServerMenu: View {
    @Environment(\.openWindow) private var openWindow
    @Bindable var Scint: ScintModel

    var body: some View {
        Text(Scint.server.running ? "MCP Server Running" : "MCP Server Stopped")
        if let message = Scint.server.message, !message.isEmpty { Text(message) }

        Divider()

        if Scint.server.running { Button("Stop Server") { Task { await Scint.server.stop() } } }
        else { Button("Start Server") { Task { await Scint.server.start() } } }

        Button("Copy MCP URL") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(Server.url.absoluteString, forType: .string)
        }

        Divider()

        Button("Open Scint") { openWindow(id: "studio") }
    }
}
