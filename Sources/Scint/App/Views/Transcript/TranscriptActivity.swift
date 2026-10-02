import SwiftUI
import ScintRuntime
import ScintComponents


struct TranscriptActivity: View {
    var ref: Reference
    @State private var expanded = false

    var tools: [ToolEntry] { (Transcript.with(ref, { $0.records }) ?? []).filter { $0.fields["type"] == .string("method") }.map { ToolEntry(record: $0) } }

    var summary: String {
        var phrases: [(one: String, many: String, count: Int)] = []
        for tool in tools {
            if let index = phrases.firstIndex(where: { $0.one == tool.phrase.one }) { phrases[index].count += 1 }
            else { phrases.append((tool.phrase.one, tool.phrase.many, 1)) }
        }
        return phrases.enumerated().map { index, phrase in
            let text = phrase.count > 1 ? phrase.many : phrase.one
            return index == 0 ? text : text.prefix(1).lowercased() + text.dropFirst()
        }
        .joined(separator: ", ")
    }

    var body: some View {
        let tools = tools

        if let first = tools.first {
            VStack(alignment: .leading, spacing: 10) {
                Button { withAnimation(Style.Motion.disclosure) { expanded.toggle() } } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Iconography.Icon(symbol: first.symbol, tint: tools.contains(where: \.failed) ? Style.Tint.alert.bright : Style.Tint.neutral.bright, sizing: 12)
                            .frame(width: Style.Dimension.icon)
                        Text(summary)
                            .lineLimit(1)
                        Image(systemName: "chevron.right")
                            .font(Typography.footnote)
                            .foregroundStyle(Style.Foreground.subtle)
                            .rotationEffect(.degrees(expanded ? 90 : 0))
                    }
                    .font(Typography.detail)
                    .foregroundStyle(Style.Foreground.secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if expanded {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(tools, id: \.record.key) { $0 }
                    }
                    .padding(.leading, Style.Dimension.icon + 8)
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
