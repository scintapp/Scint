import AgencyRuntime
import SwiftUI


@main
struct Agency: App {
    @Environment(\.openWindow) private var openWindow
    @State private var agency: AgencyModel?
    @State private var callback: URL?
    @State private var loading = false

    func load() async {
        guard agency == nil, !loading else { return }
        loading = true
        defer { loading = false }
        do { try await Runtime.shared.load() }
        catch { print(error) }
        let model = AgencyModel(Runtime.shared.workspaces)
        await model.load()
        if let callback { let _ = model.handle(callback); self.callback = nil }
        agency = model
    }

    var body: some Scene {
        Window("Agency Studio", id: "studio") {
            if let agency {
                Studio()
                    .environment(agency)
                    .environment(agency.studio)
                    .onOpenURL { _ = agency.handle($0) }
                    .onAppear(perform: { ShortcutManager.shared.register(agency: agency) } )
                    .background(Design.Background.console)
                    .focusable(false)
            }
            else {
                ProgressView()
                    .task { await load() }
                    .onOpenURL { callback = $0 }
            }
        }

        MenuBarExtra("Agency", systemImage: "point.3.connected.trianglepath.dotted") {
            if let agency { ServerMenu(agency: agency) }
            else { Text("Agency is loading…") }
        }
    }
}
