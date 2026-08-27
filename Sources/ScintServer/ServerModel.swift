import Foundation
import SwiftUI


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

