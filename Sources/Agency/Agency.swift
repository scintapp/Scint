import AgencyRuntime
import SwiftUI


@main
struct Agency: App {
    @Environment(\.openWindow) private var openWindow
    @State private var agency: AgencyModel?

    var body: some Scene {
        
        Window("Agency", id: "studio") {
            if let agency {
                Studio()
                    .environment(agency)
                    .background(Design.Background.console)
                    .focusable(false)
                    .onAppear(perform: { ShortcutManager.shared.register(agency: agency) } )

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

        Window("Agency", id: "relay") {
            if let agency {
                Relay()
                    .environment(agency)
                    .focusable(false)
            } else { ProgressView() }
        }

        MenuBarExtra {
            if let agency {
                Button { agency.toggleAperture() } label: { HStack { Image(systemName: "magnifyingglass"); Text("Search") } }
                Divider()
                Button { openWindow(id: "relay") } label: { HStack { Image(systemName: "checkmark.app"); Text("Relay") } }
        //        Button { openWindow(id: "browser") } label: { HStack { Image(systemName: "safari"); Text("Browser") } }
        //        Button { openWindow(id: "library") } label: { HStack { Image(systemName: "text.rectangle"); Text("Library") } }
                Button { openWindow(id: "studio") } label: { HStack { Image(systemName: "app"); Text("Studio") } }
        //        Divider()
        //        Button { openWindow(id: "settings") } label: { HStack { Image(systemName: "gear"); Text("Settings...") } }
            } else { ProgressView() }
        } label : { Image(systemName: "rectangle.3.offgrid") }
    }
}


//        Window("Agency", id: "browser") {
//            if let agency {
//                Browser()
//                    .environment(agency)
//                    .focusable(false)
//            } else { ProgressView() }
//        }


//        Window("Agency", id: "library") {
//            if let agency {
//                Library()
//                    .environment(agency)
//                    .focusable(false)
//            } else { ProgressView() }
//        }

//        Window("Agency", id: "settings") {
//            if let agency {
//                Settings().build(agency)
//            } else { ProgressView() }
//        }
