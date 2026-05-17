import AgencyRuntime
import SwiftUI


@main
struct Agency: App {
    @State private var agency: AgencyModel?

    var body: some Scene {
        Window("Agency", id: "browser") {
            if let agency {
                Browser()
                    .environment(agency)
                    .onAppear(perform: { ShortcutManager.shared.register(agency: agency) } )
                    .focusable(false)

            } else {
                ProgressView()
                    .task {
                        guard agency == nil else { return }
                        do { try await Runtime.shared.load() } catch { print(error) }
                        let model = AgencyModel(Runtime.shared.space)
                        await model.load()
                        agency = model
                    }
            }
        }

        Window("Agency", id: "activities") {
            if let agency {
                Activities()
                    .environment(agency)
                    .focusable(false)
            } else { ProgressView() }
        }

        Window("Agency", id: "library") {
            if let agency {
                Library()
                    .environment(agency)
                    .focusable(false)
            } else { ProgressView() }
        }

        Window("Agency", id: "settings") {
            if let agency {
                Settings().build(agency)
            } else { ProgressView() }
        }

        MenuBarExtra {
            if let agency {
                MenuBar()
                    .environment(agency)
                    .focusable(false)

            } else { ProgressView() }
        } label : { Image(systemName: "rectangle.3.offgrid") }

    }
}
