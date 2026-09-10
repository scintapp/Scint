import SwiftUI
import OSLog


@main
struct Scint: App {
    @Environment(\.openWindow) private var openWindow
    @State private var model: ScintModel?
    @State private var loading = false
    @State private var pending: URL?
    static let logger = Logger(subsystem: "com.kaechle.model", category: "App")

    var body: some Scene {
        Window("Assistant", id: "assistant") {
            if let model {
                Assistant()
                    .environment(model)
                    .onAppear(perform: { ShortcutManager.shared.register(model: model) } )
                    .focusable(false)
            } else {
                ProgressView()
                    .task { await load() }
            }
        }

        Window("Editor", id: "editor") {
            if let model {
                Editor()
                    .environment(model)
                    .focusable(false)
            } else {
                ProgressView()
                    .task { await load() }
            }
        }

        Window("Studio", id: "studio") {
            if let model {
                Studio()
                    .environment(model)
                    .focusable(false)
            } else {
                ProgressView()
                    .task { await load() }
            }
        }

        MenuBarExtra(content: {
            if let model {
                Host()
                    .environment(model)
                    .environment(model.host)
                    .onAppear(perform: { ShortcutManager.shared.register(model: model) } )
                    .focusable(false)
            } else {
                Text("Scint is loading…")
            }
        }, label: { Iconography.Glyph() })
    }

    func load() async {
        guard model == nil, !loading else { return }
        loading = true
        defer { loading = false }
        do {
            try await Runtime.shared.load()
            let scint = ScintModel()
            await scint.load()
            model = scint
            if let pending { ReferenceRouter.handle(pending) }
            pending = nil
        } catch {
            Self.logger.error("Runtime load failed: \(String(describing: error), privacy: .public)")
        }
    }
}
