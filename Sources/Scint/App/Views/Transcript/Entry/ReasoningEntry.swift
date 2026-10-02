import SwiftUI
import ScintComponents


struct ReasoningEntry: View {
    var thoughts: [String]
    @State private var offset = 0

    var lines: [String] {
        thoughts
            .flatMap { $0.replacingOccurrences(of: "**", with: "").components(separatedBy: .newlines) }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        let lines = lines
        let index = max(0, lines.count - 1 - offset)

        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Iconography.Icon(symbol: "brain", tint: Style.Tint.neutral.bright, sizing: 12, selected: false)
                .frame(width: Style.Dimension.icon)

            Text(lines.indices.contains(index) ? lines[index] : "")
                .italic()
                .foregroundStyle(Style.Foreground.subtle)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(index)
                .transition(.opacity)

            if lines.count > 1 {
                HStack(spacing: 4) {
                    Button { offset += 1 } label: { Image(systemName: "chevron.left") }
                        .disabled(index == 0)
                    Text("\(index + 1)/\(lines.count)")
                        .monospacedDigit()
                    Button { offset -= 1 } label: { Image(systemName: "chevron.right") }
                        .disabled(offset == 0)
                }
                .buttonStyle(.borderless)
                .font(Typography.footnote)
                .foregroundStyle(Style.Foreground.subtle)
                .fixedSize()
            }
        }
        .font(Typography.detail)
        .animation(Style.Motion.disclosure, value: index)
    }
}
