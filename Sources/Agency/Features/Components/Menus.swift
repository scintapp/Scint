import SwiftUI


struct LoaderMenu: View {
    @State private var presented = false
    @State private var query = ""

    let count: Int?
    let items: [ItemParams]
    let onPick: (ItemParams) -> Void

    private var filteredItems: [ItemParams] {
        guard !query.isEmpty else { return items }
        return items.filter {
            $0.name.localizedCaseInsensitiveContains(query)
            || $0.description.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        GroupCountButton(count: count) { presented = true }
            .popover(isPresented: $presented) {
                let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

                VStack(alignment: .leading, spacing: 0) {
                    FilterInput(text: $query)
                        .padding(.top, 8)

                    Divider()
                        .opacity(0.42)

                    if filteredItems.isEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 18))
                                .foregroundStyle(Design.Foreground.quaternary)
                            Text(query.isEmpty ? "Nothing in library" : "No matches")
                                .font(.system(size: 12))
                                .foregroundStyle(Design.Foreground.tertiary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 2) {
                                ForEach(filteredItems) { item in
                                    Button {
                                        onPick(item)
                                        presented = false
                                    } label: {
                                        HStack(alignment: .center) {
                                            Group {
                                                if let ref = item.ref {
                                                    Iconography.icon(for: ref, size: 20)
                                                } else {
                                                    Iconography.Icon(
                                                        symbol: item.image,
                                                        tint: item.tint ?? Design.Tint.active,
                                                        sizing: 20,
                                                        selected: item.active
                                                    )
                                                }
                                            }
                                            .frame(width: 32, height: 32)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(item.name)
                                                    .font(.system(size: 13.5, weight: .medium))
                                                    .foregroundStyle(Design.Foreground.secondary)
                                                    .lineLimit(1)

                                                if !item.description.isEmpty {
                                                    Text(item.description)
                                                        .font(.system(size: 12, weight: .medium))
                                                        .foregroundStyle(Design.Foreground.disabled)
                                                        .lineLimit(1)
                                                }
                                            }

                                            Spacer(minLength: 0)

                                            if item.active {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 11, weight: .semibold))
                                                    .foregroundStyle(Design.Foreground.tertiary)
                                            }
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .frame(minHeight: 46)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(8)
                        }
                    }
                }
                .frame(
                    width: 280,
                    height: min(max(CGFloat(filteredItems.count) * 46 + 52, 132), 360),
                    alignment: .topLeading
                )
                .glassEffect(.regular, in: shape)
                .clipShape(shape)
                .overlay {
                    shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.75)
                }
            }
            .onChange(of: presented) { _, presented in
                if !presented { query = "" }
            }
    }
}
