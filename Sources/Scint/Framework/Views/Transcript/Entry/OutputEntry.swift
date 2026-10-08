import SwiftUI
import ScintComponents


struct OutputEntry: View {
    var content: String

    var body: some View {
        TextBlock(content: content)
    }
}
