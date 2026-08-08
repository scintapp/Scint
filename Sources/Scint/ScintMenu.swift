import AppKit
import SwiftUI


struct ScintMenu: View {
    @Environment(ScintModel.self) var scint
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(scint.server.running ? "Scint Server Running" : "Scint Server Stopped")
        if let message = scint.server.message, !message.isEmpty { Text(message) }

        Divider()

        if scint.server.running { Button("Stop Scint Server") { Task { await scint.server.stop() } } }
        else { Button("Start Scint Server") { Task { await scint.server.start() } } }

        Button("Copy Server Address") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(Server.url.absoluteString, forType: .string)
        }

        Divider()

        Button("Scint Studio") { openWindow(id: "studio") }
    }
}
