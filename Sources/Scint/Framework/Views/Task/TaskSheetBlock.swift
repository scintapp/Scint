import SwiftUI
import ScintRuntime
import ScintComponents


struct TaskSheetBlock: View {
    let block: Block
    var isSelected = false
    var scale: CGFloat? = 1.0

    var body: some View {
        switch block {
            case .task(_, let content, let completed):
                HStack(alignment: .center) {
                    TaskCompletionIndicator(completed: completed, size: 20)
                        .padding(.leading, 6)

                    Text(content)
                        .font(Typography.heading(1))
                        .foregroundStyle(Style.Foreground.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

            case .document(let ref):
                let blocks = Document.with(ref) { $0.blocks }?.prefix(6)
                if let blocks {
                    ForEach(blocks) { block in DocumentBlock(block: block, isSelected: false, scale: scale) }
                }

            case .command(let ref):
                Card(ref: ref, style: .group, isSelected: isSelected)
                    .scaleEffect(scale ?? 1.0)

            default:
                EmptyView()
        }
    }
}
