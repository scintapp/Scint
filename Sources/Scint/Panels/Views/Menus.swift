import SwiftUI


struct LoaderMenu: View {
    @State private var presented = false
    @State private var query = ""

    let count: Int?
    let items: [ItemParams]
    let onPick: (ItemParams) -> Void

    private var height: CGFloat { min(max(CGFloat(filteredItems.count) * 64 + 52, 132), 360) }

    private var filteredItems: [ItemParams] {
        guard !query.isEmpty else { return items }
        return items.filter {
            $0.name.localizedCaseInsensitiveContains(query)
            || $0.description.localizedCaseInsensitiveContains(query)
        }
    }

    var button: some View {
        ForEach(filteredItems) { item in
            Button {
                onPick(item)
                presented = false
            } label: {
                HStack(alignment: .center) {
                    if let ref = item.ref { Iconography.icon(for: ref, size: 15) }
                    else {
                        Iconography.Icon(
                            symbol: item.image,
                            tint: item.tint ?? Style.Tint.active,
                            sizing: 15,
                            selected: item.active
                        )
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.system(size: 13))
                            .foregroundStyle(Style.Foreground.secondary)
                            .lineLimit(1)
                    }
                    .frame(height: 42, alignment: .leading)

                    Spacer(minLength: 0)

                    if item.active {
                        Image(systemName: "checkmark")
                            .frame(height: 32, alignment: .leading)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Style.Foreground.tertiary)
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 42, alignment: .leading)
                .contentShape(Style.Shape.card)
            }
            .buttonStyle(.plain)
        }
    }

    var menu: some View {
        VStack(alignment: .leading, spacing: 0) {
            Filter(text: $query).padding(.top, 8)
            Divider().opacity(0.42)

            if filteredItems.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18))
                        .foregroundStyle(Style.Foreground.quaternary)
                    Text(query.isEmpty ? "Nothing in library" : "No matches")
                        .font(.system(size: 12))
                        .foregroundStyle(Style.Foreground.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView { VStack(alignment: .leading, spacing: 2) { button } }
            }
        }
        .frame(width: 280, height: height, alignment: .topLeading)
        .glassEffect(.regular, in: Style.Shape.menu)
        .clipShape(Style.Shape.menu)
    }

    var body: some View {
        GroupCountButton(count: count) { presented = true }
            .popover(isPresented: $presented) { menu }
            .onChange(of: presented) { _, presented in if !presented { query = "" } }
    }
}
