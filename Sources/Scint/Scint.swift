import SwiftUI


@main
struct Scint: App {
    @Environment(\.openWindow) private var openWindow
    @State private var scint: ScintModel?
//    @State private var callback: URL?
    @State private var loading = false

    func load() async {
        guard scint == nil, !loading else { return }
        loading = true
        defer { loading = false }
        do { try await Runtime.shared.load() }
        catch { print(error) }
        let model = ScintModel(Runtime.shared.workspaces)
        await model.load()
//        if let callback { let _ = model.handle(callback); self.callback = nil }
        scint = model
    }

    var body: some Scene {
        Window("Scint Studio", id: "studio") {
            if let scint {
                ScintStudio()
                    .environment(scint)
                    .environment(scint.studio)
//                    .onOpenURL { _ = scint.handle($0) }
                    .onAppear(perform: { ShortcutManager.shared.register(scint: scint) } )
                    .background(Design.Background.console)
                    .focusable(false)
            }
            else {
                ProgressView()
                    .task { await load() }
//                    .onOpenURL { callback = $0 }
            }
        }

        MenuBarExtra(content: {
            if let scint {
                ScintStatus()
                    .environment(scint)
                    .focusable(false)
            } else {
                Text("Scint is loading…")
            }
        }, label: { Iconography.Glyph() })
    }
}
