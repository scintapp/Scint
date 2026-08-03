import SwiftUI


@main
struct Scint: App {
    @Environment(\.openWindow) private var openWindow
    @State private var Scint: ScintModel?
    @State private var callback: URL?
    @State private var loading = false

    func load() async {
        guard Scint == nil, !loading else { return }
        loading = true
        defer { loading = false }
        do { try await Runtime.shared.load() }
        catch { print(error) }
        let model = ScintModel(Runtime.shared.workspaces)
        await model.load()
        if let callback { let _ = model.handle(callback); self.callback = nil }
        Scint = model
    }

    var body: some Scene {
        Window("Scint Studio", id: "studio") {
            if let Scint {
                Studio()
                    .environment(Scint)
                    .environment(Scint.studio)
                    .onOpenURL { _ = Scint.handle($0) }
                    .onAppear(perform: { ShortcutManager.shared.register(Scint: Scint) } )
                    .background(Design.Background.console)
                    .focusable(false)
            }
            else {
                ProgressView()
                    .task { await load() }
                    .onOpenURL { callback = $0 }
            }
        }

        MenuBarExtra("Scint", systemImage: "point.3.connected.trianglepath.dotted") {
            if let Scint { ServerMenu(Scint: Scint) }
            else { Text("Scint is loading…") }
        }
    }
}
