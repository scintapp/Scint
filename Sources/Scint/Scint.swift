import SwiftUI
import OSLog


@main
struct Scint: App {
    @Environment(\.openWindow) private var openWindow
    @State private var scint: ScintModel?
    @State private var loading = false
    private static let logger = Logger(subsystem: "com.kaechle.scint", category: "App")

    var body: some Scene {
        Window("Studio", id: "studio") {
            if let scint {
                Studio()
                    .environment(scint)
                    .environment(scint.studio)
                    .background(Style.Background.console)
                    .onAppear(perform: { ShortcutManager.shared.register(scint: scint) } )
                    .focusable(false)
            } else {
                ProgressView()
                    .task { await load() }
            }
        }

        Window("Editor", id: "editor") {
            if let scint {
                Editor()
                    .environment(scint)
                    .environment(scint.editor)
                    .background(Style.Background.console)
                    .focusable(false)
            }
            else {
                ProgressView()
                    .task { await load() }
            }
        }

        MenuBarExtra(content: {
            if let scint {
                ScintMenu()
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
            let model = ScintModel()
            await model.load()
            scint = model
        } catch {
            Self.logger.error("Runtime load failed: \(String(describing: error), privacy: .public)")
        }
    }
}
