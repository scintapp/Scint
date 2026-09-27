import Foundation
import SwiftUI


struct Host: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Scint Studio") { openWindow(id: "studio") }
    }
}
