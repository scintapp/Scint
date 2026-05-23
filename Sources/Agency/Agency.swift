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
                    .onAppear(perform: { ShortcutManager.shared.register(agency: agency) } )
                    .background(Design.Background.console)
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

        MenuBarExtra {
            if let agency {
                Button { agency.toggleSearch() } label: { HStack { Image(systemName: "magnifyingglass"); Text("Search") } }
                Divider()
        //        Button { openWindow(id: "activities") } label: { HStack { Image(systemName: "checkmark.app"); Text("Activities") } }
        //        Button { openWindow(id: "browser") } label: { HStack { Image(systemName: "safari"); Text("Browser") } }
        //        Button { openWindow(id: "library") } label: { HStack { Image(systemName: "text.rectangle"); Text("Library") } }
                Button { openWindow(id: "studio") } label: { HStack { Image(systemName: "app"); Text("Studio") } }
        //        Divider()
        //        Button { openWindow(id: "settings") } label: { HStack { Image(systemName: "gear"); Text("Settings...") } }
            } else { ProgressView() }
        } label : { Image(systemName: "rectangle.3.offgrid") }
    }
}



//        Window("Agency", id: "activities") {
//            if let agency {
//                Activities()
//                    .environment(agency)
//                    .focusable(false)
//            } else { ProgressView() }
//        }

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
