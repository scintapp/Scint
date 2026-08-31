import Foundation
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

@Observable @MainActor final class HostModel {
    let server: ContextServer = .init()
    var message: String? = ""
    var running: Bool = false

    func load() async {
        guard !running else { return }
        do {
            try await server.start()
            running = true
            message = nil
        } catch {
            message = String(describing: error)
        }
    }

    func unload() async {
        await server.stop()
        running = false
    }
}
