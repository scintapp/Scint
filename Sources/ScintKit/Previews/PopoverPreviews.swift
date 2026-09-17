import SwiftUI


#if DEBUG
private struct LoadMenuControlsPreview: View {
    let items: [ItemParams]
    @State private var selected: ItemParams?

    var body: some View {
        VStack(alignment: .leading, spacing: Style.Spacing.xl) {
            Text(selected.map { "Selected: \($0.name)" } ?? "Select a reference")
                .font(Typography.row)
                .foregroundStyle(Style.Foreground.secondary)

            LoadMenu(count: selected == nil ? 0 : 1, items: items) { selected = $0 }
                .frame(width: 180)
        }
        .padding(Style.Spacing.xxl)
        .frame(width: 360, height: 150, alignment: .topLeading)
        .background(Style.Background.base)
    }
}

private struct PickerControlsPreview: View {
    let items: [ItemParams]
    @State private var value = "comfortable"
    @State private var date = Value.formatter.string(from: .now)

    var body: some View {
        VStack(spacing: 0) {
            PreviewControlRow("Menu picker") {
                ItemPicker(value: value, items: items) { value = $0.value ?? value }
            }
            Divider().opacity(Style.Opacity.faint)
            PreviewControlRow("Range picker") {
                ItemRangePicker(value: value, items: items) { value = $0.value ?? value }
            }
            Divider().opacity(Style.Opacity.faint)
            PreviewControlRow("Date picker") {
                ItemDatePicker(value: date, components: [.date]) { date = $0 }
            }
        }
        .frame(width: 420)
        .background(Style.Shape.large.fill(Style.Background.group))
        .overlay(Style.Shape.large.stroke(Style.Border.base, lineWidth: 1))
        .padding(Style.Spacing.xxl)
        .background(Style.Background.base)
    }
}

#Preview("Load Menu — Popover") {
    let menu = LoadMenu(count: 1, items: PreviewFixture.shared.loadItems) { _ in }

    return menu.menu
        .padding(Style.Spacing.xl)
        .background(Style.Background.base)
        .preferredColorScheme(.dark)
}

#Preview("Load Menu — Control") {
    LoadMenuControlsPreview(items: PreviewFixture.shared.loadItems)
        .preferredColorScheme(.dark)
}

#Preview("Pickers") {
    PickerControlsPreview(items: PreviewFixture.shared.pickerItems)
        .preferredColorScheme(.dark)
}
#endif
