import AgencyRuntime
import AppKit
import SwiftUI


struct ComponentIcon: View {
    enum Size { case grid, table }

    let item: ItemParams
    var size: Size = .grid

    private var tile: CGFloat { size == .grid ? 58 : 26 }
    private var appTile: CGFloat { size == .grid ? 50 : 22 }
    private var doc: CGSize { size == .grid ? .init(width: 42, height: 54) : .init(width: 20, height: 26) }
    private var radius: CGFloat { size == .grid ? 18 : 9 }
    private var appRadius: CGFloat { size == .grid ? 11 : 5 }
    private var symbol: CGFloat { size == .grid ? 24 : 12 }
    private var appSymbol: CGFloat { size == .grid ? 20 : 10 }

    var body: some View {
        ZStack { icon }
            .frame(width: size == .grid ? 66 : 28, height: size == .grid ? 66 : 28)
    }

    @ViewBuilder private var icon: some View {
        if let ref = item.ref {
            switch ref.type {
            case is Artifact.Type:
                if let entry = Artifact.with(ref, { $0.kind }) { artifact(entry) }
                else { app(Design.Component.icon(for: ref), Design.Tint.artifact) }
            case is Command.Type: app(Design.Component.icon(for: ref), Design.Tint.control)
            case is Route.Type: route
            case is Harness.Type: service
            case is Sheet.Type: sheet
            case is Transcript.Type: transcript
            case is Space.Type, is Workspace.Type: space
            default: app(Design.Component.icon(for: ref), Design.Tint.active)
            }
        } else {
            app(item.image.isEmpty ? "app.grid" : item.image, item.tint ?? Design.Tint.active)
        }
    }

    @ViewBuilder private func artifact(_ entry: Artifact.Kind) -> some View {
        switch entry {
        case .app:
            app(Design.Component.icon(for: entry), Design.Tint.artifact)
        case .file:
            folder
        case .http: bookmark
        case .image(let url):
            if let url, let image = NSImage(contentsOf: url) { imageIcon(image, clipped: true) }
            else { app("photo", Design.Tint.artifact) }
        case .script: script
        case .skill: app("shippingbox.fill", Design.Tint.structure)
        case .exec: terminalApp
        }
    }

    private func existingPath(for url: URL) -> String? {
        guard url.isFileURL else { return nil }
        let path = url.path(percentEncoded: false)
        let hostedPath = url.host.map { "/\($0)\(path)" }
        return ([path] + [hostedPath].compactMap { $0 }).first { FileManager.default.fileExists(atPath: $0) }
    }

    private func workspaceIcon(_ url: URL) -> NSImage? {
        guard let path = existingPath(for: url) else { return nil }
        return NSWorkspace.shared.icon(forFile: path).copy() as? NSImage
    }

    @ViewBuilder private func imageIcon(_ image: NSImage, dimension: CGFloat? = nil, clipped: Bool = false) -> some View {
        let side = dimension ?? tile
        if clipped {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        } else {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: side, height: side)
        }
    }

    private var space: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let preview = spacePreview

        return ZStack {
            if preview.items.isEmpty {
                Image(systemName: "square.dashed")
                    .font(.system(size: size == .grid ? 18 : 8, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.28))
            } else {
                SpaceIconPreview(preview: preview, size: size)
            }
        }
        .frame(width: tile, height: tile)
        .clipShape(shape)
        .glassEffect(.regular.tint(Design.Tint.success.opacity(0.06)), in: shape)
        .overlay(shape.strokeBorder(Design.Tint.success.opacity(0.14), lineWidth: 0.5))
        .contentShape(shape)
    }

    private var spacePreview: SpaceIconPreviewModel {
        let refs = spaceContentReferences
        let previewCount = refs.count > 4 ? 3 : 4
        let items = refs.prefix(previewCount).map {
            SpaceIconPreviewModel.Item(
                ref: $0,
                symbol: Design.Component.icon(for: $0),
                tint: previewTint(for: $0)
            )
        }

        return .init(items: items, overflow: max(0, refs.count - items.count))
    }

    private var spaceContentReferences: [Reference] {
        guard let ref = item.ref else { return [] }

        switch ref.type {
        case is Workspace.Type:
            return spaceContents(
                spaces: Workspace.with(ref, { Array($0.spaces) }) ?? [],
                closure: Workspace.with(ref, { $0.closure }),
                routes: []
            )
        case is Space.Type:
            return spaceContents(
                spaces: Space.with(ref, { Array($0.spaces) }) ?? [],
                closure: Space.with(ref, { $0.closure }),
                routes: Space.with(ref, { Array($0.routes) }) ?? []
            )
        default:
            return []
        }
    }

    private func spaceContents(spaces: [Reference], closure: Reference?, routes: [Reference]) -> [Reference] {
        let sheets = closure.flatMap { Closure.with($0, { Array($0.sheets) }) } ?? []
        let components = closure.flatMap { Closure.with($0, { Array($0.components) }) } ?? []
        return spaces + sheets + components + routes
    }

    private func previewTint(for ref: Reference) -> Color {
        switch ref.type {
        case is Artifact.Type: Design.Tint.artifact
        case is Command.Type: Design.Tint.control
        case is Route.Type: Design.Tint.structure
        case is Harness.Type: Design.Tint.service
        case is Sheet.Type: Design.Tint.sheet
        case is Transcript.Type: Design.Tint.running
        case is Space.Type, is Workspace.Type: Design.Tint.success
        default: Design.Tint.active
        }
    }

    private func app(_ systemName: String, _ tint: Color) -> some View {
        let shape = RoundedRectangle(cornerRadius: appRadius, style: .continuous)
        return ZStack {
            LinearGradient(colors: [tint.opacity(0.34), Color.primary.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: systemName)
                .font(.system(size: appSymbol, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.76))
        }
        .frame(width: appTile, height: appTile)
        .glassEffect(.regular.tint(tint.opacity(0.12)), in: shape)
        .overlay(shape.strokeBorder(.black.opacity(0.14), lineWidth: 0.5))
        .clipShape(shape)
    }

    private var route: some View {
        ZStack {
            space.offset(x: size == .grid ? -6 : -3, y: size == .grid ? 6 : 3).scaleEffect(0.72)
            space.offset(x: size == .grid ? 7 : 3, y: size == .grid ? -7 : -3).scaleEffect(0.72)
        }
        .frame(width: tile, height: tile)
    }

    private var service: some View {
        app(item.ref.map(Design.Component.icon(for:)) ?? "app.connected.to.app.below.fill", Design.Tint.service)
    }

    private var sheet: some View {
        let page = RoundedRectangle(cornerRadius: size == .grid ? 6 : 3, style: .continuous)
        var content = ""
        if let ref = item.ref { content = Sheet.with(ref, { $0.content }) ?? "" }

        return Text(content)
            .font(.system(size: size == .grid ? 3 : 2, weight: .light))
            .lineSpacing(0)
            .foregroundStyle(.black)
            .padding(size == .grid ? 4 : 2)
            .frame(width: doc.width, height: doc.height, alignment: .topLeading)
            .glassEffect(.clear, in: page)
            .background(page.fill(Color.primary.opacity(0.8)))
            .overlay(page.strokeBorder(.black.opacity(0.12), lineWidth: 0.5))
            .clipShape(page)
    }

    private var transcript: some View {
        document(fill: Color.primary.opacity(0.9), foreground: .black.opacity(0.74)) {
            Image(systemName: "newspaper.fill")
                .font(.system(size: size == .grid ? 18 : 9, weight: .medium))
        }
    }

    private var bookmark: some View {
        document(fill: Color.primary.opacity(0.9), foreground: .black.opacity(0.74)) {
            VStack(spacing: size == .grid ? 5 : 2) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: size == .grid ? 14 : 7, weight: .semibold))
                Image(systemName: "link")
                    .font(.system(size: size == .grid ? 10 : 5, weight: .medium))
            }
        }
    }

    private var script: some View {
        document(fill: Color.primary.opacity(0.13), foreground: Design.Tint.running.opacity(0.82)) {
            VStack(alignment: .leading, spacing: size == .grid ? 3 : 1) {
                ForEach(0..<6, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(index == 0 ? Design.Tint.warning.opacity(0.74) : Design.Tint.running.opacity(0.62))
                        .frame(width: (size == .grid ? [20, 13, 24, 17, 22, 15] : [9, 6, 11, 8, 10, 7])[index], height: size == .grid ? 1.5 : 0.7)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.top, size == .grid ? 8 : 3)
            .padding(.leading, size == .grid ? 8 : 3)
        }
    }

    private var terminalApp: some View {
        app("terminal.fill", Design.Tint.active)
            .overlay {
                Text(">")
                    .font(.system(size: size == .grid ? 18 : 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Design.Tint.running.opacity(0.9))
                    .offset(x: size == .grid ? -9 : -4, y: size == .grid ? 5 : 2)
            }
    }

    private var folder: some View {
        Image(systemName: "folder.fill")
            .font(.system(size: size == .grid ? 49 : 22, weight: .regular))
            .symbolRenderingMode(.palette)
            .foregroundStyle(
                Color(red: 0.42, green: 0.70, blue: 1.0),
                Color(red: 0.26, green: 0.52, blue: 0.92)
            )
            .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
            .frame(width: tile, height: tile)
    }

    private func document<Content: View>(
        fill: Color,
        foreground: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let page = RoundedRectangle(cornerRadius: size == .grid ? 6 : 3, style: .continuous)
        return ZStack {
            page.fill(fill)
            content().foregroundStyle(foreground)
        }
        .frame(width: doc.width, height: doc.height)
        .overlay(page.strokeBorder(.black.opacity(0.12), lineWidth: 0.5))
        .clipShape(page)
    }
}

private struct SpaceIconPreviewModel {
    struct Item: Identifiable {
        let ref: Reference
        let symbol: String
        let tint: Color

        var id: Reference { ref }
    }

    let items: [Item]
    let overflow: Int
}

private struct SpaceIconPreview: View {
    let preview: SpaceIconPreviewModel
    let size: ComponentIcon.Size

    private struct Cell: Identifiable {
        let id: AnyHashable
        let symbol: String?
        let label: String?
        let tint: Color
    }

    private var cells: [Cell] {
        let content = preview.items.map {
            Cell(id: AnyHashable($0.id), symbol: $0.symbol, label: nil, tint: $0.tint)
        }

        guard preview.overflow > 0 else { return content }
        return content + [
            Cell(
                id: "overflow",
                symbol: nil,
                label: "+\(preview.overflow)",
                tint: Design.Tint.active
            )
        ]
    }

    private var cellSide: CGFloat { size == .grid ? 18 : 7 }
    private var gap: CGFloat { size == .grid ? 4 : 2 }
    private var cornerRadius: CGFloat { size == .grid ? 5 : 2 }
    private var symbolSize: CGFloat { size == .grid ? 10 : 4.8 }
    private var labelSize: CGFloat { size == .grid ? 8.5 : 3.8 }

    var body: some View {
        VStack(spacing: gap) {
            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: gap) {
                    ForEach(0..<2, id: \.self) { column in
                        let index = row * 2 + column
                        if index < cells.count {
                            previewCell(cells[index])
                        } else {
                            Color.clear.frame(width: cellSide, height: cellSide)
                        }
                    }
                }
            }
        }
    }

    private func previewCell(_ cell: Cell) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return ZStack {
            LinearGradient(
                colors: [cell.tint.opacity(0.52), Color.primary.opacity(0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if let symbol = cell.symbol {
                Image(systemName: symbol)
                    .font(.system(size: symbolSize, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.78))
            } else if let label = cell.label {
                Text(label)
                    .font(.system(size: labelSize, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.76))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
        }
        .frame(width: cellSide, height: cellSide)
        .background(shape.fill(Color.primary.opacity(0.06)))
        .overlay(shape.strokeBorder(.black.opacity(0.16), lineWidth: 0.5))
        .clipShape(shape)
    }
}

struct ItemIcon: View {
    @Environment(AgencyModel.self) private var agency
    let item: ItemParams
    let closures: Closures

    private let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

    private var selected: Bool { closures.selected?(item) ?? false }

    var body: some View {
        VStack(spacing: 6) {
            ComponentIcon(item: item)

            Text(item.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary.opacity(0.9))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 112, minHeight: 30, maxHeight: 34, alignment: .top)
        }
        .frame(width: 96, height: 112)
        .background {
            shape.fill(selected ? Design.Tint.success.opacity(0.12) : Color.clear)
        }
        .overlay {
            shape.strokeBorder(selected ? Design.Tint.success.opacity(0.34) : Color.clear, lineWidth: 1)
        }
        .contentShape(shape)
        .gesture(
            TapGesture(count: 2).onEnded { closures.onOpen?(item) }
                .exclusively(before: TapGesture(count: 1).onEnded { closures.onSelect?(item) })
        )
    }
}

struct ItemCard: View {
    let item: ItemParams
    let closures: Closures
    let shape: RoundedRectangle = RoundedRectangle(cornerRadius: 24)

    var body: some View {
        VStack(alignment: .leading) {
            VStack(alignment: .leading) {
                Text(item.name)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .padding(.bottom, 4)

                if let description = item.description {
                    Text(description)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if !item.badges.isEmpty {
                    HStack(spacing: 0) {
                        ForEach(item.badges) { badge in Badge(icon: badge.icon, label: badge.label, count: badge.count, color: badge.tint, glass: false) }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .frame(width: 160, height: 160, alignment: .topLeading)
        .contentShape(shape)
        .background { shape.fill(Design.Background.panel) }
        .overlay { shape.stroke(lineWidth: 1).fill(.primary.opacity(0.1)) }
        .contentShape(shape)
        .onTapGesture(count: 2) { closures.onOpen?(item) }
        .onTapGesture { closures.onSelect?(item) }
    }
}

struct ItemRow<Content: View>: View {
    let name: String
    let accessory: AnyView?
    let trailingImage: String?
    let count: Int?
    let indent: CGFloat
    let isHovered: Bool
    let selected: Bool
    let isEditing: Bool
    let editText: Binding<String>?
    let onCommitEdit: (() -> Void)?
    let content: Content

    init(
        name: String, accessory: AnyView? = nil, trailingImage: String? = nil, count: Int? = nil,
        indent: CGFloat = 0, isHovered: Bool = false, selected: Bool = false, isEditing: Bool = false,
        editText: Binding<String>? = nil, onCommitEdit: (() -> Void)? = nil,
        @ViewBuilder leading: () -> Content) {

            self.name = name
            self.accessory = accessory
            self.count = count
            self.indent = indent
            self.isHovered = isHovered
            self.selected = selected
            self.isEditing = isEditing
            self.editText = editText
            self.onCommitEdit = onCommitEdit
            self.trailingImage = trailingImage
            self.content = leading()
        }

    var body: some View {
        HStack {
            Color.clear.frame(width: indent)
            content

            if isEditing, let editText {
                TextField("Name", text: editText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .onSubmit { onCommitEdit?() }
            } else {
                Text(name)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            if let accessory { accessory.padding(.trailing, 8) }
            if let trailingImage { Image(systemName: trailingImage).font(.system(size: 12)) }

            if let count {
                Text("\(count)")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 3)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 24)
        .background(RoundedRectangle(cornerRadius: 7).fill(selected ? Color.secondary.opacity(0.1) : .clear))
        .foregroundStyle(selected ? Color.gray : .primary)
        .contentShape(RoundedRectangle(cornerRadius: 7))
    }
}

struct StatusPill: View {
    let label: String
    var color: Color = Design.Tint.ready

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color.opacity(0.88))
                .frame(width: 5, height: 5)
            Text(label)
                .font(.system(size: 10.5, weight: .medium))
        }
        .foregroundStyle(color.opacity(0.88))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.06))
        .clipShape(Capsule())
        .overlay(
            Capsule().strokeBorder(color.opacity(0.17), lineWidth: 1)
        )
    }
}

struct GhostButton: View {
    let label: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
            }
            Text(label)
                .font(.system(size: 10.5, weight: .medium))
        }
        .foregroundStyle(Design.SheetEntry.textSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Design.SheetEntry.accentSoft)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Design.SheetEntry.stroke, lineWidth: 1)
        )
    }
}

struct SheetTextView: View {
    let text: String

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var looksLikeBlock: Bool { text.contains("\n") && (trimmed.contains("- ") || trimmed.hasPrefix("##")) }
    private var isHeading: Bool { !trimmed.contains("\n") && trimmed.hasPrefix("#") }
    private var isQuote: Bool { trimmed.hasPrefix(">") }
    private var quotePrefix: String { ">" }

    private var attributed: AttributedString {
        (try? AttributedString(
            markdown: trimmed,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(trimmed)
    }

    private func stripped(_ prefix: String) -> String {
        var s = trimmed
        while s.hasPrefix(prefix) || s.hasPrefix(" ") {
            if s.hasPrefix(prefix) { s.removeFirst(prefix.count) }
            else { s.removeFirst() }
        }
        return s
    }

    var body: some View {
        if looksLikeBlock {
            Text(text)
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(Design.SheetEntry.textPrimary)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Design.SheetEntry.codeBlockBg)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Design.SheetEntry.stroke, lineWidth: 1)
                )
        } else if isQuote {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Design.SheetEntry.accent)
                    .frame(width: 3)
                Text(stripped(quotePrefix))
                    .font(.system(size: 13, weight: .regular))
                    .italic()
                    .foregroundStyle(Design.SheetEntry.textSecondary)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 12)
            }
        } else if isHeading {
            Text(stripped("#"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Design.SheetEntry.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(attributed)
                .font(.system(size: 13))
                .foregroundStyle(Design.SheetEntry.textPrimary)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct EntryCard<Body: View>: View {
    let shape: RoundedRectangle = RoundedRectangle(cornerRadius: 18, style: .continuous)
    @ViewBuilder var content: () -> Body

    var body: some View {
        VStack(alignment: .leading) {
            content()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .contentShape(shape)
        .background { shape.fill(Design.SheetEntry.card) }
        .overlay { shape.stroke(lineWidth: 1).fill(Design.SheetEntry.stroke) }
    }
}

//struct Block: View {
//    let title: String
//    let text: String
//    let footnote: String
//
//    var body: some View {
//        VStack {
//            if !title.isEmpty {
//                Text(title)
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .font(.system(size: 11, weight: .semibold))
//                    .foregroundStyle(.secondary.opacity(0.75))
//            }
//
//            Group {
//                if text.isEmpty {
//                    Text("Empty")
//                        .font(.system(size: 10.5, design: .monospaced))
//                        .foregroundStyle(.tertiary)
//                        .frame(maxWidth: .infinity, alignment: .leading)
//                } else {
//                    Text(text)
//                        .font(.system(size: 10.5, design: .monospaced))
//                        .foregroundStyle(.secondary)
//                        .textSelection(.enabled)
//                        .frame(maxWidth: .infinity, alignment: .leading)
//                        .fixedSize(horizontal: false, vertical: true)
//                }
//            }
//            .padding(10)
//            .background {
//                RoundedRectangle(cornerRadius: 14, style: .continuous)
//                    .fill(.primary.opacity(0.08))
//            }
//            .overlay {
//                RoundedRectangle(cornerRadius: 14, style: .continuous)
//                    .stroke(.primary.opacity(0.03), lineWidth: 1)
//            }
//
//            if !footnote.isEmpty {
//                Text(footnote)
//                    .padding(.leading, 4)
//                    .font(.system(size: 11, weight: .light))
//                    .foregroundStyle(.secondary.opacity(0.6))
//                    .frame(maxWidth: .infinity, alignment: .leading)
//            }
//        }
//    }
//}
