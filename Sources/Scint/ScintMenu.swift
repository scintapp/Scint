import AppKit
import SwiftUI


struct ScintStatus: View {
    @Environment(ScintModel.self) var scint
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(scint.server.running ? "MCP Server Running" : "MCP Server Stopped")
        if let message = scint.server.message, !message.isEmpty { Text(message) }

        Divider()

        if scint.server.running { Button("Stop Server") { Task { await scint.server.stop() } } }
        else { Button("Start Server") { Task { await scint.server.start() } } }

        Button("Copy MCP URL") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(Server.url.absoluteString, forType: .string)
        }

        Divider()

        Button("Palette") { openWindow(id: "palette") }
        Button("Studio") { openWindow(id: "studio") }
    }
}
