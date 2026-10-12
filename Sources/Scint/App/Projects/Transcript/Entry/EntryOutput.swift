import SwiftUI
import ScintComponents


struct EntryOutput: View {
    var content: String

    var body: some View {
        TextBlock(content: content)
    }
}
