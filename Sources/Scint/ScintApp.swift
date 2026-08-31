import SwiftUI
import OSLog


@main
struct Scint: App {
    @Environment(\.openWindow) private var openWindow
    @State private var scint: ScintModel?
    @State private var loading = false
    @State private var pending: URL?
    static let logger = Logger(subsystem: "com.kaechle.scint", category: "App")

    var body: some Scene {
        Window("Studio", id: "studio") {
            if let scint {
                Studio()
                    .environment(scint)
                    .environment(scint.studio)
                    .onAppear(perform: { ShortcutManager.shared.register(scint: scint) } )
                    .focusable(false)
                    .onOpenURL { ReferenceRouter.handle($0) }
            } else {
                ProgressView()
                    .task { await load() }
                    .onOpenURL { pending = $0 }
            }
        }

        Window("Assistant", id: "assistant") {
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

        Window("Editor", id: "editor") {
            if let scint {
                Editor()
                    .environment(scint)
                    .environment(scint.editor)
                    .onAppear(perform: { ShortcutManager.shared.register(scint: scint) } )
                    .focusable(false)
            } else {
                ProgressView()
                    .task { await load() }
            }
        }

        MenuBarExtra(content: {
            if let scint {
                Host()
                    .environment(scint)
                    .environment(scint.host)
                    .onAppear(perform: { ShortcutManager.shared.register(scint: scint) } )
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
            if let pending { ReferenceRouter.handle(pending) }
            pending = nil
        } catch {
            Self.logger.error("Runtime load failed: \(String(describing: error), privacy: .public)")
        }
    }
}
