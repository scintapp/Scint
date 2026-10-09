import SwiftUI
import ScintRuntime
import ScintComponents


struct MenuList: View {
    let items: [MenuItem]
    let selectedID: String?
    let onSelect: (MenuItem) -> Void

    var body: some View {
        ScrollView(.vertical) {
            ScrollViewReader { proxy in
                VStack(spacing: 4) {
                    ForEach(items) { item in
                        if case .divider = item {
                            Divider()
                                .opacity(Style.Opacity.inactive)
                                .padding(.horizontal, 6)
                        } else {
                            let selected = item.id == selectedID
                            let shape = Style.Shape.button

                            Button { onSelect(item) } label: {
                                HStack(alignment: .center, spacing: 0) {
                                    Iconography.menuIcon(for: item, selected: selected)
                                        .saturation(selected ? 1.0 : 0.0)
                                        .padding(.leading, 8)
                                        .padding(.trailing, 4)

                                    VStack(alignment: .leading, spacing: Style.Spacing.detail) {
                                        Text(item.label)
                                            .font(.system(size: 13))
                                            .foregroundColor(Style.Foreground.primary)
                                            .lineLimit(1)

                                        if !item.detail.isEmpty {
                                            Text(item.detail)
                                                .font(.system(size: 11))
                                                .foregroundColor(Style.Foreground.subtle)
                                                .lineLimit(1)
                                        }
                                    }

                                    Spacer(minLength: .zero)
                                }
                                .padding(.vertical, 4)
                                .frame(minHeight: 28, maxHeight: 28)
                                .background(shape.fill(selected ? Style.Background.selection : Color.clear))
                                .contentShape(shape)
                            }
                            .buttonStyle(.plain)
                            .id(item.id)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(5)
                .onChange(of: selectedID) { _, newID in
                    guard let newID else { return }
                    withAnimation(Metrics.menuSelection) {
                        proxy.scrollTo(newID, anchor: .center)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}
