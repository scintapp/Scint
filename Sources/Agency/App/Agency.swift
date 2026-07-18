import AgencyRuntime
import SwiftUI


@main
struct Agency: App {
    @Environment(\.openWindow) private var openWindow
    @State private var agency: AgencyModel?
    @State private var callback: URL?
    @State private var sheet: Reference?

    func load() async {
        guard agency == nil else { return }
        do { try await Runtime.shared.load() }
        catch { print(error) }
        let model = AgencyModel(Runtime.shared.workspace)
        await model.load()
        if let callback { let _ = model.handle(callback); self.callback = nil }
        let ref = Sheet.new(model.session.workspace, name: "Untitled")
        sheet = ref
        agency = model
    }

    var body: some Scene {
        Window("Agency", id: "agency") {
            if let agency {
                AgencyFrame()
                    .environment(agency)
                    .onAppear(perform: { ShortcutManager.shared.register(agency: agency) } )
                    .background(Design.Background.console)
                    .focusable(false)
            }
            else {
                ProgressView().task { await load() }
            }
        }

        Window("Composer", id: "composer") {
            if let agency {
                ComposerFrame()
                    .environment(agency)
                    .onAppear(perform: { ShortcutManager.shared.register(agency: agency) } )
                    .background(Design.Background.console)
                    .focusable(false)
            }
            else { ProgressView().task { await load() } }
        }

        Window("Editor", id: "editor") {
            if let agency, let sheet {
                EditorFrame(sheet: sheet)
                    .environment(agency)
                    .onAppear(perform: { ShortcutManager.shared.register(agency: agency) } )
                    .focusable(false)
            } else { ProgressView().task { await load() } }
        }
        .defaultSize(width: 1_180, height: 820)

        Window("Library", id: "library") {
            if let agency, let sheet {
                EditorFrame(sheet: sheet)
                    .environment(agency)
                    .onAppear(perform: { ShortcutManager.shared.register(agency: agency) } )
                    .focusable(false)
            } else { ProgressView().task { await load() } }
        }
        .defaultSize(width: 1_180, height: 820)


        Window("Studio", id: "studio") {
            if let agency {
                StudioFrame()
                    .environment(agency)
                    .onAppear(perform: { ShortcutManager.shared.register(agency: agency) } )
                    .background(Design.Background.console)
                    .focusable(false)
            }
            else {
                ProgressView().task { await load() }
            }
        }
    }
}
