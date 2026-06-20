import AgencyRuntime
import AppKit
import SwiftUI


private struct SpaceIconPreviewModel {
    struct Item: Identifiable {
        let ref: Reference
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
        let ref: Reference?
        let label: String?
        let tint: Color
    }

    private var cells: [Cell] {
        let content = preview.items.map {
            Cell(id: AnyHashable($0.id), ref: $0.ref, label: nil, tint: $0.tint)
        }

        guard preview.overflow > 0 else { return content }
        return content + [
            Cell(
                id: "overflow",
                ref: nil,
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

            if let ref = cell.ref {
                let icon = Iconography.icon(for: ref)
                Image(systemName: icon.symbol)
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
                    if let handle = Artifact.with(ref, { $0.handle }) { artifact(handle) }
                    else { app(Iconography.icon(for: ref), Design.Tint.artifact) }
                case is Command.Type: app(Iconography.icon(for: ref), Design.Tint.command)
                case is Route.Type: route
                case is Harness.Type: service
                case is Sheet.Type: sheet
                case is Transcript.Type: transcript
                case is Space.Type, is Workspace.Type: space
                default: app(Iconography.icon(for: ref), Design.Tint.active)
            }
        } else {
            app(item.image.isEmpty ? "app.grid" : item.image, item.tint ?? Design.Tint.active)
        }
    }

    @ViewBuilder private func artifact(_ entry: Artifact.Handle) -> some View {
        switch entry {
            case .app:
                app(Iconography.icon(for: entry), Design.Tint.artifact)
            case .file:
                folder
            case .http: bookmark
            case .image(let url):
                if let url, let image = NSImage(contentsOf: url) { imageIcon(image, clipped: true) }
                else { app("photo", Design.Tint.artifact) }
            case .script: script
            case .skill: app("shippingbox.fill", Design.Tint.space)
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
            SpaceIconPreviewModel.Item(ref: $0, tint: Iconography.accent(for: $0))
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
        let sheets = closure.flatMap { Closure.with($0, { Array($0.state) }) } ?? []
        let components = closure.flatMap { Closure.with($0, { Array($0.components) }) } ?? []
        return spaces + sheets + components + routes
    }

    private func app(_ systemName: String, _ tint: Color) -> some View {
        app(tint) {
            Image(systemName: systemName)
                .font(.system(size: appSymbol, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.76))
        }
    }

    private func app(_ icon: Iconography.Icon, _ tint: Color) -> some View {
        app(tint) {
            Image(systemName: icon.symbol)
                .font(.system(size: appSymbol, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.76))
        }
    }

    private func app<Content: View>(_ tint: Color, @ViewBuilder content: () -> Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: appRadius, style: .continuous)
        return ZStack {
            LinearGradient(colors: [tint.opacity(0.34), Color.primary.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
            content()
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

    @ViewBuilder private var service: some View {
        if let ref = item.ref { app(Iconography.icon(for: ref), Design.Tint.harness) }
        else { app("app.connected.to.app.below.fill", Design.Tint.harness) }
    }

    private var sheet: some View {
        let page = RoundedRectangle(cornerRadius: size == .grid ? 6 : 3, style: .continuous)
        var content = ""
        if let ref = item.ref { content = Sheet.with(ref, { $0.rendered }) ?? "" }

        return Text(content)
            .font(.system(size: size == .grid ? 3 : 2, weight: .light))
            .lineSpacing(0)
            .foregroundStyle(.black)
            .padding(size == .grid ? 4 : 2)
            .frame(width: doc.width, height: doc.height, alignment: .topLeading)
            .glassEffect(.clear, in: page)
            .background(page.fill(Color.primary.opacity(0.93)))
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

    private func document<Content: View>(fill: Color, foreground: Color, @ViewBuilder content: () -> Content) -> some View {
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

struct ItemIcon: View {
    @Environment(AgencyModel.self) private var agency
    let item: ItemParams
    let controls: Controls

    private let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

    private var selected: Bool { controls.selected?(item) ?? false }

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
            TapGesture(count: 2).onEnded { controls.onOpen?(item) }
                .exclusively(before: TapGesture(count: 1).onEnded { controls.onSelect?(item) })
        )
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
        .frame(maxWidth: .infinity, minHeight: 26)
        .background(RoundedRectangle(cornerRadius: 7).fill(selected ? Color.secondary.opacity(0.1) : .clear))
        .foregroundStyle(selected ? Color.gray : .primary)
        .contentShape(RoundedRectangle(cornerRadius: 7))
    }
}

struct ItemCard: View {
    let item: ItemParams
    let controls: Controls
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
        .onTapGesture(count: 2) { controls.onOpen?(item) }
        .onTapGesture { controls.onSelect?(item) }
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
            if let icon { Image(systemName: icon).font(.system(size: 10, weight: .medium)) }
            Text(label).font(.system(size: 10.5, weight: .medium))
        }
        .foregroundStyle(Design.SheetGlyph.textSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Design.SheetGlyph.accentSoft)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Design.SheetGlyph.stroke, lineWidth: 1)
        )
    }
}

struct EntryCard<Body: View>: View {
    let shape: RoundedRectangle = RoundedRectangle(cornerRadius: 18, style: .continuous)
    @ViewBuilder var content: () -> Body

    var body: some View {
        VStack(alignment: .leading) { content() }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .contentShape(shape)
            .background { shape.fill(Design.SheetGlyph.card) }
            .overlay { shape.stroke(lineWidth: 1).fill(Design.SheetGlyph.stroke) }
    }
}

private struct CardBadge: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 9.5))
            .foregroundStyle(Design.SheetGlyph.textTertiary.opacity(0.9))
            .lineLimit(1)
            .truncationMode(.middle)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Design.SheetGlyph.textTertiary.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Design.SheetGlyph.textTertiary.opacity(0.16), lineWidth: 0.75)
            }
    }
}

struct CardLink: View {
    @State private var hovered = false
    let ref: Reference
    let title: String
    let selected: Bool
    let onSelect: () -> Void

    private var facts: [String] { Sheet.with(ref, { details($0.blocks) }) ?? [] }

    private var preview: String {
        let rendered = Sheet.with(ref, { $0.rendered }) ?? ""
        let compact = rendered
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return compact.isEmpty ? "No additional text" : compact
    }

    private var background: Color {
        if selected { return Color.accentColor.opacity(0.16) }
        if hovered { return Color.primary.opacity(0.055) }
        return Color.primary.opacity(0.0)
    }

    private var border: Color {
        selected ? Color.accentColor.opacity(0.0) : Color.primary.opacity(0.0)
    }

    private func details(_ entries: [Sheet.Block]) -> [String] {
        let artifacts = entries.filter { if case .artifact = $0 { true } else { false } }.count
        let commands = entries.filter { if case .command = $0 { true } else { false } }.count
        let tasks = entries.filter { if case .task = $0 { true } else { false } }.count
        let done = entries.filter { if case .task(_, _, true) = $0 { true } else { false } }.count

        return [
            tasks == 0 ? nil : "\(done)/\(tasks) tasks",
            artifacts == 0 ? nil : "\(artifacts) artifact\(artifacts == 1 ? "" : "s")",
            commands == 0 ? nil : "\(commands) command\(commands == 1 ? "" : "s")"
        ].compactMap(\.self)
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .padding(.bottom, 4)

                Text(preview)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.primary.opacity(0.9))
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 4) { ForEach(facts, id: \.self) { fact in CardBadge(label: fact) } }
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(alignment: .topLeading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                selected ? background.opacity(0.4) : background.opacity(0.0),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.horizontal, 4)
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}
