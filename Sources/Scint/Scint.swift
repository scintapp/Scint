import OSLog
import ServiceManagement
import SwiftUI
import ScintComponents
import ScintRuntime
import ScintServer


@main
struct Scint: App {
    @Environment(\.openWindow) private var openWindow
    @State private var ref: Reference = Space.sentinel()
    @State private var scint: ScintModel?
    @State private var loading = false
    @State private var pending: URL?
    @State private var host = NetworkTransport()
    static let logger = Logger(subsystem: "com.kaechle.model", category: "App")
    let agent = SMAppService.agent(plistName: "com.kaechle.scintd.plist")

    var body: some Scene {
        Window("Studio", id: "studio") {
            if let scint {
                AppView()
                    .environment(scint)
                    .environment(scint.app)
                    .onAppear { ShortcutProvider.shared.register(model: scint) }
                    .environment(\.openURL, scint.openURL)
                    .onOpenURL { scint.open($0) }
                    .focusable(false)
            } else {
                ProgressView()
                    .task { await load() }
                    .onOpenURL { pending = $0 }
            }
        }

        MenuBarExtra(content: {
            if let scint {
                ScintMenu()
                    .environment(scint)
                    .environment(\.openURL, scint.openURL)
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
            let data = DataModel(Runtime.shared.model)
            let model = ScintModel(data)
            await serve()
            model.open(pending)
            pending = nil
            self.scint = model
        } catch {
            Self.logger.error("Runtime load failed: \(String(describing: error), privacy: .public)")
        }
    }

    func serve() async {
        do { try await Server().serve(host)
        } catch {
            Self.logger.error("MCP server failed to start: \(String(describing: error), privacy: .public)")
        }
    }
}
