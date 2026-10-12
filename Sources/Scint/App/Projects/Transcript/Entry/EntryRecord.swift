import SwiftUI
import ScintRuntime
import ScintComponents


struct EntryRecord: View {
    var cards: [Reference]
    var content: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(cards) { ref in
                Card(ref: ref, style: .group)
            }
            if let content { TextBlock(content: content) }
        }
    }
}
