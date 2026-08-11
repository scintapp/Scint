import SwiftUI


@main
struct Scint: App {
    @Environment(\.openWindow) private var openWindow
    @State private var scint: ScintModel?
    @State private var loading = false

    var body: some Scene {
        Window("Studio", id: "studio") {
            if let scint {
                ScintStudio()
                    .environment(scint)
                    .environment(scint.studio)
                    .background(Design.Background.console)
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
                    .background(Design.Background.console)
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
            print(error)
        }
    }
}
