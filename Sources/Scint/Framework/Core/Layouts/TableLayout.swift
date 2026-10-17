import SwiftUI
import ScintRuntime
import ScintComponents


struct TableDivider: View {
    var body: some View {
        Rectangle()
            .fill(Style.Border.hairline)
            .frame(height: Style.Border.width)
            .padding(.horizontal, 8)
    }
}

struct TableHeader: View {
    let name: String

    var body: some View {
        Text(name)
            .font(Typography.detail.weight(.medium))
            .foregroundStyle(Style.Foreground.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.top, 16)
            .padding(.bottom, 2)
    }
}

struct TableLabel: View {
    let name: String
    let icon: Iconography.Icon

    var body: some View {
        HStack(spacing: 6) {
            icon
            Text(name).lineLimit(1)
        }
        .font(Typography.detail)
        .foregroundStyle(Style.Foreground.subtle)
    }
}

struct TableLayout<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovered = false
    let time: String?
    let name: String
    let detail: String
    let done: Bool?
    let origin: (name: String, icon: Iconography.Icon)?
    let expandable: Bool
    let isExpanded: Bool
    let selected: Bool
    let onToggle: () -> Void
    let onSelect: () -> Void
    let onOpen: () -> Void
    let onToggleExpanded: () -> Void
    @ViewBuilder let content: () -> Content

    func line(compact: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(time ?? "")
                .font(Typography.detail)
                .monospacedDigit()
                .foregroundStyle(Style.Foreground.subtle)
                .lineLimit(1)
                .frame(width: 64, alignment: .leading)

            Group {
                if let done {
                    Button(action: onToggle) { TaskCompletionIndicator(completed: done, size: 14) }
                        .buttonStyle(.plain)
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 3 }
                        .accessibilityLabel("Complete")
                        .accessibilityValue(done ? "Complete" : "Incomplete")
                        .accessibilityAddTraits(.isToggle)
                } else {
                    Color.clear.frame(height: 0)
                }
            }
            .frame(width: 16)

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(Typography.body)
                    .foregroundStyle(done == true ? Style.Foreground.secondary : Style.Foreground.primary)
                    .strikethrough(done == true, color: Style.Foreground.subtle)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if !detail.isEmpty {
                    Text(detail)
                        .font(Typography.detail)
                        .foregroundStyle(Style.Foreground.muted)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 0, idealWidth: 160, maxWidth: .infinity, alignment: .leading)

            if !compact {
                Group {
                    if let origin { TableLabel(name: origin.name, icon: origin.icon) }
                    else { Color.clear.frame(height: 0) }
                }
                .frame(width: 120, alignment: .leading)
            }

            Group {
                if expandable {
                    Button { withAnimation(reduceMotion ? nil : Style.Motion.disclosure, onToggleExpanded) } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Style.Foreground.secondary)
                            .contentTransition(.symbolEffect(.replace))
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
                    .opacity(isExpanded || hovered ? 1 : 0)
                    .accessibilityLabel("Details")
                    .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
                } else {
                    Color.clear.frame(height: 0)
                }
            }
            .frame(width: 20, alignment: .trailing)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                line(compact: false)
                line(compact: true)
            }

            if isExpanded {
                content()
                    .padding(.leading, 104)
                    .padding(.trailing, 32)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(Style.Shape.control.fill(selected ? Style.Background.selection.opacity(Style.Opacity.outline) : isExpanded ? Style.Background.group : .clear))
        .contentShape(Style.Shape.control)
        .onHover { hovered = $0 }
        .onTapGesture(count: 2, perform: onOpen)
        .onTapGesture(perform: onSelect)
    }
}

#Preview {
    let icon = Iconography.Icon(symbol: "square.stack", tint: Style.Foreground.subtle, sizing: 12)

    VStack(alignment: .leading, spacing: 0) {
        TableHeader(name: "Morning")
        TableLayout(time: "9:00 AM", name: "Short", detail: "One line of summary.", done: false, origin: ("Engineering", icon), expandable: false, isExpanded: false, selected: true, onToggle: {}, onSelect: {}, onOpen: {}, onToggleExpanded: {}) { EmptyView() }
        TableDivider()
        TableLayout(time: "10:00 AM", name: "A considerably longer task title that has to wrap when the window narrows", detail: "", done: false, origin: nil, expandable: false, isExpanded: false, selected: false, onToggle: {}, onSelect: {}, onOpen: {}, onToggleExpanded: {}) { EmptyView() }
        TableHeader(name: "Afternoon")
        TableLayout(time: "1:00 PM", name: "Expanded and complete", detail: "Summary under the title.", done: true, origin: ("Composition", icon), expandable: true, isExpanded: true, selected: false, onToggle: {}, onSelect: {}, onOpen: {}, onToggleExpanded: {}) {
            TextBlock(content: "Detail starts at the task text column and shares the row background.")
        }
    }
    .padding()
    .frame(width: 720)
    .background(Style.Background.canvas)
}
