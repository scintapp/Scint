import SwiftUI
import ScintComponents


struct SymbolTile: View {
    @State private var hovered = false
    let symbol: String
    let tint: Color
    let selected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(selected ? tint.opacity(0.2) : hovered ? Style.Background.selection : .clear))
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .help(symbol)
    }
}

struct SwatchTile: View {
    let color: Color?
    let selected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            ZStack {
                if let color { Circle().fill(color) }
                else {
                    Circle().fill(Style.Background.selection)
                    Image(systemName: "line.diagonal")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Style.Foreground.secondary)
                }
            }
            .frame(width: 22, height: 22)
            .padding(3)
            .overlay { if selected { Circle().strokeBorder(Style.Foreground.secondary, lineWidth: 1.5) } }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

struct IconPicker: View {
    @State private var query = ""
    let icon: String?
    let color: String?
    let tint: Color
    var symbols = [
        "tray", "folder", "chevron.left.forwardslash.chevron.right", "cylinder", "flask", "wrench.and.screwdriver", "hammer", "chart.bar",
        "chart.line.uptrend.xyaxis", "person.2", "person.3", "book", "books.vertical", "cube", "doc", "note.text",
        "lightbulb", "paintpalette", "paintbrush", "star", "flag", "house", "sun.max", "moon",
        "clock", "calendar", "cloud", "leaf", "globe", "atom", "key", "lock",
        "camera", "mic", "music.note", "cup.and.saucer", "gift", "graduationcap", "building.columns", "briefcase",
        "tablecells", "checklist", "list.bullet", "clipboard", "photo", "bookmark", "mappin", "map",
        "heart", "bolt", "eye", "binoculars", "megaphone", "paperplane", "envelope", "bubble.left",
        "gamecontroller", "puzzlepiece", "sparkles", "flame", "drop", "snowflake", "airplane", "car"
    ]
    let onSelect: (_ icon: String?, _ color: String?) -> Void

    var shown: [String] { query.isEmpty ? symbols : symbols.filter { $0.localizedCaseInsensitiveContains(query) } }
    var swatches: [Iconography.Swatch] { Iconography.Swatch.allCases }

    var body: some View {
        VStack(spacing: 0) {
            FilterField(text: $query)
                .padding(12)

            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(32), spacing: 6), count: 8), spacing: 6) {
                    ForEach(shown, id: \.self) { symbol in
                        SymbolTile(symbol: symbol, tint: tint, selected: symbol == icon) { onSelect(symbol, color) }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            .frame(height: 232)

            Divider()

            Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                GridRow {
                    SwatchTile(color: nil, selected: color == nil) { onSelect(icon, nil) }
                    ForEach(swatches.prefix(swatches.count / 2), id: \.self) { swatch in
                        SwatchTile(color: swatch.color, selected: color == swatch.rawValue) { onSelect(icon, swatch.rawValue) }
                    }
                }
                GridRow {
                    Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                    ForEach(swatches.suffix(swatches.count / 2), id: \.self) { swatch in
                        SwatchTile(color: swatch.color, selected: color == swatch.rawValue) { onSelect(icon, swatch.rawValue) }
                    }
                }
            }
            .padding(12)

            Divider()

            Button { onSelect(nil, nil) } label: {
                Label("Reset Icon and Color", systemImage: "circle.slash")
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Style.Foreground.secondary)
        }
    }
}
