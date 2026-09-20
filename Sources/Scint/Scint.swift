import OSLog
import SwiftUI
import ScintRuntime
import ScintComponents


@main
struct ScintApp: App {
    @Environment(\.openWindow) private var openWindow
    @State private var scint: ScintModel?
    @State private var loading = false
    @State private var pending: URL?
    @State private var host = HTTPTransport()
    static let logger = Logger(subsystem: "com.kaechle.model", category: "App")

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

        Window("Editor", id: "editor") {
            if let scint {
                EditorWindow()
                    .environment(scint)
                    .environment(scint.app.editor)
                    .focusable(false)
            } else {
                ProgressView()
                    .task { await load() }
            }
        }

        Window("Block Editor", id: "blockedit") {
            if let scint, let ref = scint.app.studio.session.opened.document {
                ScintEdit(ref: ref)
                    .environment(scint)
                    .focusable(false)
            } else if scint != nil {
                ContentUnavailableView("No document open", systemImage: "doc.text")
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
        do {
            try await MCPServer(bridge: RuntimeBridge()).serve(host)
        } catch {
            Self.logger.error("MCP server failed to start: \(String(describing: error), privacy: .public)")
        }
    }
}
