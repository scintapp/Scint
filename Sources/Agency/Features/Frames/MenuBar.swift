import AgencyRuntime
import SwiftUI
import KeyboardShortcuts


struct MenuBar: View {
    @Environment(AgencyModel.self) var agency
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button { agency.toggleSearch() } label: { HStack { Image(systemName: "magnifyingglass"); Text("Search") } }
        Divider()
        Button { openWindow(id: "studio") } label: { HStack { Image(systemName: "app"); Text("Studio") } }
        Button { openWindow(id: "activities") } label: { HStack { Image(systemName: "checkmark.app"); Text("Activities") } }
        Button { openWindow(id: "library") } label: { HStack { Image(systemName: "text.rectangle"); Text("Library") } }
        Divider()
        Button { openWindow(id: "settings") } label: { HStack { Image(systemName: "gear"); Text("Settings...") } }
    }
}
