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
                VStack(spacing: 0) {
                    ForEach(items) { item in
                        if case .divider = item {
                            Divider()
                                .opacity(Style.Opacity.inactive)
                                .padding(.horizontal, 2)
                                .padding(.vertical, 4)
                        } else {
                            let selected = item.id == selectedID
                            let shape = Style.Shape.button

                            Button { onSelect(item) } label: {
                                HStack(alignment: .center) {
                                    Iconography.menuIcon(for: item, selected: selected)
                                        .saturation(selected ? 1.0 : 0.0)
                                        .padding(.leading, 8)
                                        .padding(.trailing, 2)

                                    VStack(alignment: .leading, spacing: Style.Spacing.detail) {
                                        Text(item.label)
                                            .font(.system(size: 13))
                                            .foregroundColor(Style.Foreground.primary)
                                            .lineLimit(1)
                                            .frame(height: 10)

                                        if !item.detail.isEmpty {
                                            Text(item.detail)
                                                .font(.system(size: 11))
                                                .foregroundColor(Style.Foreground.subtle)
                                                .lineLimit(1)
                                                .frame(height: 8)
                                        }
                                    }

                                    Spacer(minLength: .zero)
                                }
                                .padding(.vertical, 4)
                                .frame(minHeight: 14)
                                .background(
                                    shape
                                        .fill(selected ? Style.Background.selection : Color.clear)
                                )
                                .contentShape(shape)
                            }
                            .buttonStyle(.plain)
                            .id(item.id)
                        }
                    }
                }
                .padding(5)
                .frame(maxWidth: .infinity)
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
