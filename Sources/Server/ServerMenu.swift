import AppKit
import SwiftUI


struct ServerMenu: View {
    @Environment(\.openWindow) private var openWindow
    @Bindable var agency: AgencyModel

    var body: some View {
        Text(agency.server.running ? "MCP Server Running" : "MCP Server Stopped")
        if let message = agency.server.message, !message.isEmpty { Text(message) }

        Divider()

        if agency.server.running { Button("Stop Server") { Task { await agency.server.stop() } } }
        else { Button("Start Server") { Task { await agency.server.start() } } }

        Button("Copy MCP URL") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(Server.url.absoluteString, forType: .string)
        }

        Divider()

        Button("Open Agency") { openWindow(id: "studio") }
    }
}
