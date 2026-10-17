import SwiftUI
import ScintComponents


struct RowCell: View {
    let primary: String
    let secondary: String
    let marker: String
    let tint: Color
    let selected: Bool
    let divided: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 3) {
                Text(secondary)
                    .font(Typography.footnote)
                    .foregroundStyle(selected ? Style.Foreground.secondary : Style.Foreground.muted)

                Text(primary)
                    .font(Typography.itemTitle)
                    .monospacedDigit()
                    .foregroundStyle(selected ? Style.Foreground.primary : Style.Foreground.secondary)

                Image(systemName: marker.isEmpty ? "circle.fill" : marker)
                    .font(.system(size: 4))
                    .foregroundStyle(tint)
                    .opacity(marker.isEmpty ? 0 : 1)
            }
            .lineLimit(1)
            .padding(.vertical, 6)
            .frame(minWidth: 64, maxWidth: .infinity)
            .background(Style.Shape.control.fill(selected ? Style.Background.surface : .clear))
            .overlay(Style.Shape.control.strokeBorder(selected ? Style.Border.surface : .clear, lineWidth: Style.Border.width))
            .contentShape(Style.Shape.control)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Style.Border.frame)
                .frame(width: Style.Border.width, height: 28)
                .opacity(divided ? 1 : 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct RowLayout<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 0) { content() }
                ScrollView(.horizontal) { HStack(spacing: 0) { content() } }
                    .scrollIndicators(.hidden)
            }

            Rectangle()
                .fill(Style.Border.frame)
                .frame(height: Style.Border.width)
        }
    }
}

#Preview {
    let days = [("Fri", "16"), ("Sat", "17"), ("Sun", "18"), ("Mon", "19"), ("Tue", "20")]

    RowLayout {
        ForEach(Array(days.enumerated()), id: \.offset) { index, day in
            RowCell(primary: day.1, secondary: day.0, marker: index == 0 ? "circle.fill" : "", tint: Style.Tint.accent.bright, selected: index == 1, divided: index > 2) { }
        }
    }
    .padding()
    .frame(width: 620)
    .background(Style.Background.canvas)
}
