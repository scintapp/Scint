import OSLog
import ServiceManagement
import SwiftUI
import ScintRuntime
import ScintComponents


@main
struct Scint: App {
    @Environment(\.openWindow) private var openWindow
    @State private var scint: ScintModel?
    @State private var loading = false
    @State private var pending: URL?
    @State private var host = HTTPTransport()
    static let logger = Logger(subsystem: "com.kaechle.model", category: "App")
    let agent = SMAppService.agent(plistName: "com.kaechle.scintd.plist")

    var body: some Scene {
        Window("Studio", id: "studio") {
            if let scint {
                Studio()
                    .environment(scint)
                    .environment(scint.app.studio)
                    .focusable(false)
                    .onAppear { ShortcutManager.shared.register(model: scint) }
            } else {
                ProgressView()
                    .task { await load() }
            }
        }

        MenuBarExtra(content: {
            if let scint {
                Host()
                    .environment(scint)
                    .focusable(false)
            } else {
                Text("Scint is loading…")
            }
        }, label: { Iconography.Glyph() })
    }

    func load() async {
        guard scint == nil, !loading else { return }
        loading = true
        defer { loading = false }
        register()
        await runtime()
        await serve()
    }

    func register() {
        if agent.status != .enabled {
            do { try agent.register() }
            catch { Self.logger.error("Service registration failed: \(String(describing: error), privacy: .public)") }
        }
    }

    func runtime() async {
        do {
            try await Runtime.shared.load()
            let data = await AppData()
            let model = ScintModel(data)
            await model.load()
            scint = model
            await serve()
            if let pending { CallbackRouter.handle(pending) }
            pending = nil
        } catch {
            Self.logger.error("Runtime load failed: \(String(describing: error), privacy: .public)")
        }
    }

    func serve() async {
        do { try await MCPServer().serve(host)
        } catch {
            Self.logger.error("MCP server failed to start: \(String(describing: error), privacy: .public)")
        }
    }
}
