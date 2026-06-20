import AgencyRuntime
import SwiftUI


@main
struct Agency: App {
    @Environment(\.openWindow) private var openWindow
    @State private var agency: AgencyModel?

    var body: some Scene {
        Window("Folio", id: "folio") {
            if let agency {
                Folio()
                    .environment(agency)
                    .onAppear(perform: { ShortcutManager.shared.register(agency: agency) } )
                    .background(Design.Background.base)
                    .focusable(false)
            } else {
                ProgressView()
                    .task {
                        guard agency == nil else { return }
                        do { try await Runtime.shared.load() } catch { print(error) }
                        let model = AgencyModel(Runtime.shared.workspace)
                        await model.load()
                        agency = model
                    }
            }
        }

        Window("Studio", id: "studio") {
            if let agency {
                Studio()
                    .environment(agency)
                    .onAppear(perform: { ShortcutManager.shared.register(agency: agency) } )
                    .background(Design.Background.console)
                    .focusable(false)
            } else {
                ProgressView()
                    .task {
                        guard agency == nil else { return }
                        do { try await Runtime.shared.load() } catch { print(error) }
                        let model = AgencyModel(Runtime.shared.workspace)
                        await model.load()
                        agency = model
                    }
            }
        }
    }
}


