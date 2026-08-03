
import Foundationimport SwiftUI


@Observable @MainActor final class ServerModel {
    let server: Server
    var message: String? = ""
    var running: Bool = false

    init() {
        self.server = .init()
        self.message = nil
        self.running = false
    }

    func start() async {
        guard !running else { return }
        do {
            try await server.start()
            running = true
            message = nil
        } catch {
            message = String(describing: error)
        }
    }

    func stop() async {
        await server.stop()
        running = false
    }
}

