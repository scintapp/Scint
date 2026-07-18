import AgencyRuntime
import SwiftUI


@main
struct Agency: App {
    @Environment(\.openWindow) private var openWindow
    @State private var agency: AgencyModel?
    @State private var callback: URL?

    func load() async {
        guard agency == nil else { return }
        do { try await Runtime.shared.load() }
        catch { print(error) }
        let model = AgencyModel(Runtime.shared.workspaces)
        await model.load()
        if let callback { let _ = model.handle(callback); self.callback = nil }
        let ref = Sheet.new(model.editor.session.workspace, name: "Untitled")
        model.editor.open(ref)
        agency = model
    }

    var body: some Scene {
        Window("Studio", id: "studio") {
            if let agency {
                Studio()
                    .environment(agency)
                    .environment(agency.studio)
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
                Composer()
                    .environment(agency)
                    .environment(agency.composer)
                    .onAppear(perform: { ShortcutManager.shared.register(agency: agency) } )
                    .background(Design.Background.console)
                    .focusable(false)
            }
            else { ProgressView().task { await load() } }
        }

        Window("Editor", id: "editor") {
            if let agency {
                Editor()
                    .environment(agency)
                    .environment(agency.editor)
                    .onAppear(perform: { ShortcutManager.shared.register(agency: agency) } )
                    .focusable(false)
            } else { ProgressView().task { await load() } }
        }

        Window("Library", id: "library") {
            if let agency {
                Library()
                    .environment(agency)
                    .environment(agency.library)
                    .onAppear(perform: { ShortcutManager.shared.register(agency: agency) } )
                    .focusable(false)
            } else { ProgressView().task { await load() } }
        }
    }
}
