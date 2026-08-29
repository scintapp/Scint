import SwiftUI
import OSLog


@main
struct Scint: App {
    @Environment(\.openWindow) private var openWindow
    @State private var scint: ScintModel?
    @State private var loading = false
    static let logger = Logger(subsystem: "com.kaechle.scint", category: "App")

    var body: some Scene {
        Window("Scint", id: "assistant") {
            if let scint {
                Assistant()
                    .environment(scint)
                    .environment(scint.assistant)
                    .onAppear(perform: { ShortcutManager.shared.register(scint: scint) } )
                    .focusable(false)
            } else {
                ProgressView()
                    .task { await load() }
            }
        }

        Window("Scint", id: "editor") {
            if let scint {
                Editor()
                    .environment(scint)
                    .environment(scint.editor)
                    .focusable(false)
            }
            else {
                ProgressView()
                    .task { await load() }
            }
        }

        MenuBarExtra(content: {
            if let scint {
                Host()
                    .environment(scint)
                    .environment(scint.studio)
                    .environment(scint.editor)
                    .environment(scint.host)
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
            let model = ScintModel()
            await model.load()
            scint = model
        } catch {
            Self.logger.error("Runtime load failed: \(String(describing: error), privacy: .public)")
        }
    }
}
