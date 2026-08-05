import SwiftUI


struct PaletteIndexComponent: Identifiable {
    let component: ComponentParams
    let startIndex: Int

    var id: AnyHashable { component.id }

    static func index(_ components: [ComponentParams]) -> [PaletteIndexComponent] {
        var offset = 0
        return components.map { component in
            defer { offset += component.items.count }
            return PaletteIndexComponent(component: component, startIndex: offset)
        }
    }
}

struct PaletteRow: View {
    let item: ItemParams
    let isSelected: Bool
    let onTap: () -> Void

    @ViewBuilder var icon: some View {
        if let ref = item.ref {
            Iconography.Icon(
                symbol: Iconography.symbol(for: ref),
                tint: Iconography.accent(for: ref),
                sizing: 20,
                selected: isSelected
            )
        } else {
            Iconography.Icon(
                symbol: item.image.isEmpty ? "square.stack.3d.up" : item.image,
                tint: Design.Tint.active,
                sizing: 20,
                selected: isSelected
            )
        }
    }

    var body: some View {
        HStack(alignment: .center) {
            icon
                .frame(width: 34, height: 34, alignment: .center)
                .padding(.leading, 2)
                .padding(.trailing, 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 16, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(
                        isSelected
                        ? Design.Foreground.primary
                        : Design.Foreground.secondary
                    )
                    .lineLimit(1)

                if !item.description.isEmpty {
                    Text(item.description)
                        .font(.system(size: 13))
                        .foregroundStyle(Design.Foreground.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "return")
                    .padding(.trailing, 8)
                    .font(.system(size: 13))
                    .foregroundStyle(Design.Foreground.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .animation(.easeOut(duration: 0.1), value: isSelected)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(
                    isSelected
                    ? Design.Foreground.quaternary.opacity(0.3)
                    : Color.clear
                )
        )
    }
}

struct PaletteInput: View {
    @Binding var value: String
    @FocusState var focused: Bool

    let image: String
    let placeholder: String
    var onUpArrow: () -> KeyPress.Result = { .ignored }
    var onDownArrow: () -> KeyPress.Result = { .ignored }
    var onReturn: () -> KeyPress.Result = { .ignored }
    var onTab: () -> KeyPress.Result = { .ignored }

    var body: some View {
        VStack {
            HStack(alignment: .center, spacing: 16) {
                Image(systemName: image)
                    .frame(height: 48, alignment: .center)
                    .foregroundStyle(Design.Foreground.tertiary)
                    .font(.system(size: 26, weight: .light))

                TextField(placeholder, text: $value)
                    .frame(height: 48, alignment: .center)
                    .padding(.bottom, 2)
                    .foregroundStyle(Design.Foreground.tertiary)
                    .font(.system(size: 28, weight: .light))
                    .textFieldStyle(.plain)
                    .onKeyPress(.upArrow) { onUpArrow() }
                    .onKeyPress(.downArrow) { onDownArrow() }
                    .onKeyPress(.return) { onReturn() }
                    .onKeyPress(.tab) { onTab() }
                    .focused($focused)
            }
            .frame(height: 48)

            Rectangle()
                .frame(maxWidth: .infinity, maxHeight: 0.5)
                .padding(.horizontal, 4)
                .opacity(0.17)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 8)
        .onAppear { focused = true }
        .onChange(of: placeholder) { _, _ in focused = true }
    }
}

struct PaletteComponent: View {
    let component: ComponentParams
    let startIndex: Int
    let selectedIndex: Int
    let controls: Controls
    let onSelectIndex: (Int) -> Void

    var body: some View {
        if !component.items.isEmpty {
            if component.header && !component.name.isEmpty {
                Text(component.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.top, 12)
                    .padding(.bottom, 6)
            }

            ForEach(Array(component.items.enumerated()), id: \.element.id) { offset, item in
                let absoluteIndex = startIndex + offset
                PaletteRow(
                    item: item,
                    isSelected: absoluteIndex == selectedIndex,
                    onTap: {
                        onSelectIndex(absoluteIndex)
                        controls.onSelect?(item)
                    }
                )
                .id(item.id)
            }
        }
    }
}
