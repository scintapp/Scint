import AgencyRuntime
import SwiftUI


enum SheetGlyph {
    static let background = Design.Background.base
    static let card = Design.Background.card
    static let cardHeader = Color.primary.opacity(0.06)
    static let stroke = Color.primary.opacity(0.1)
    static let accent = Color.secondary
    static let accentSoft = Color.primary.opacity(0.06)
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color.secondary.opacity(0.7)
    static let codeBlockBg = Color.primary.opacity(0.08)
}

enum EditorComponent {
    enum Badge {
        static let font = Font.system(size: 9.5)
        static let horizontalPadding: CGFloat = 6
        static let verticalPadding: CGFloat = 3
        static let cornerRadius: CGFloat = 6
        static let foreground = SheetGlyph.textTertiary.opacity(0.9)
        static let background = SheetGlyph.textTertiary.opacity(0.07)
        static let stroke = SheetGlyph.textTertiary.opacity(0.16)
    }

    enum Card {
        static let cornerRadius: CGFloat = 18
        static let horizontalPadding: CGFloat = 14
        static let verticalPadding: CGFloat = 12
        static let background = SheetGlyph.card
        static let stroke = SheetGlyph.stroke
    }

    enum LinkCard {
        static let cornerRadius: CGFloat = 12
        static let horizontalPadding: CGFloat = 12
        static let verticalPadding: CGFloat = 8
        static let outerHorizontalPadding: CGFloat = 4
        static let titleFont = Font.system(size: 13, weight: .medium)
        static let previewFont = Font.system(size: 11.5)
        static let selectedBackground = Color.accentColor.opacity(0.16)
        static let hoveredBackground = Color.primary.opacity(0.055)
        static let clearBorder = Color.primary.opacity(0.0)
    }

    enum StatusPill {
        static let font = Font.system(size: 10.5, weight: .medium)
        static let dotSize: CGFloat = 5
        static let horizontalPadding: CGFloat = 8
        static let verticalPadding: CGFloat = 4
    }
}

struct SpaceIconPreviewModel {
    struct Item: Identifiable {
        var id: Reference { ref }
        let ref: Reference
        let tint: Color
    }

    let items: [Item]
    let overflow: Int
}

struct SpaceIconPreview: View {
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
                let icon = Iconography.icon(for: ref, size: 16)
                Image(systemName: icon.symbol)
                    .font(.system(size: symbolSize, weight: .semibold))
                    .foregroundStyle(icon.tint.opacity(0.92))
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
    let ref: Reference?
    let image: String
    let tint: Color?
    var size: Size = .grid

    enum Size { case grid, table }

    private var tile: CGFloat { size == .grid ? 58 : 26 }
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
        if let ref {
            switch ref.type {
                case is Sheet.Type: sheet(ref)
                default: space(ref)
            }
        } else {
            Image(systemName: image)
                .font(.system(size: appSymbol, weight: .semibold))
                .foregroundStyle((tint ?? Design.Tint.active).opacity(0.95))
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

    private func space(_ ref: Reference) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let preview = spacePreview(ref)

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
        .glassEffect(.regular.tint(Design.Tint.info.opacity(0.06)), in: shape)
        .overlay(shape.strokeBorder(Design.Tint.info.opacity(0.14), lineWidth: 0.5))
        .contentShape(shape)
    }

    private func spacePreview(_ ref: Reference) -> SpaceIconPreviewModel {
        let refs = spaceContentReferences(ref)
        let previewCount = refs.count > 4 ? 3 : 4
        let items = refs.prefix(previewCount).map {
            SpaceIconPreviewModel.Item(ref: $0, tint: Iconography.accent(for: $0))
        }

        return .init(items: items, overflow: max(0, refs.count - items.count))
    }

    private func spaceContentReferences(_ ref: Reference) -> [Reference] {
        switch ref.type {
            case is Workspace.Type:
                return spaceContents(
                    spaces: Workspace.with(ref, { Array($0.spaces) }) ?? [],
                    closure: Workspace.with(ref, { $0.closure })
                )
            case is Space.Type:
                return spaceContents(
                    spaces: Space.with(ref, { Array($0.spaces) }) ?? [],
                    closure: Space.with(ref, { $0.closure })
                )
            default:
                return []
        }
    }

    private func spaceContents(spaces: [Reference], closure: Reference?) -> [Reference] {
        let sheets = closure.flatMap { Closure.with($0, { $0.state.filter { $0.type is Sheet.Type } }) } ?? []
        return spaces + sheets
    }

    private func sheet(_ ref: Reference) -> some View {
        let page = RoundedRectangle(cornerRadius: size == .grid ? 6 : 3, style: .continuous)
        let icon = Iconography.icon(for: ref, size: 16)
        let content = Sheet.with(ref, { $0.rendered }) ?? ""

        return Text(content)
            .font(.system(size: size == .grid ? 3 : 2, weight: .light))
            .lineSpacing(0)
            .foregroundStyle(.black.opacity(0.9))
            .padding(size == .grid ? 4 : 2)
            .frame(width: doc.width, height: doc.height, alignment: .topLeading)
            .glassEffect(.clear, in: page)
            .background(page.fill(.primary.opacity(0.9)))
            .overlay(page.strokeBorder(icon.tint.opacity(0.38), lineWidth: 0.5))
            .clipShape(page)
    }
}

struct ItemIcon: View {
    let name: String
    let ref: Reference?
    let image: String
    let tint: Color?
    let focused: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void

    private let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

    var body: some View {
        VStack(spacing: 6) {
            ComponentIcon(ref: ref, image: image, tint: tint)

            Text(name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary.opacity(0.9))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 112, minHeight: 30, maxHeight: 34, alignment: .top)
        }
        .frame(width: 96, height: 112)
        .background(shape.fill(focused ? Design.Tint.info.opacity(0.12) : Color.clear))
        .overlay(shape.strokeBorder(focused ? Design.Tint.info.opacity(0.34) : Color.clear, lineWidth: 1))
        .contentShape(shape)
        .gesture(
            TapGesture(count: 2)
                .onEnded { onOpen() }
                .exclusively(before: TapGesture(count: 1).onEnded { onSelect() })
        )
    }
}

@MainActor enum Iconography {
    static func icon(for block: Sheet.Block, size: CGFloat = 15) -> Icon {
        switch block {
            case .artifact(let ref), .command(let ref), .sheet(let ref): return Iconography.icon(for: ref, size: size)
            case .content: return Icon(symbol: "text.alignleft", tint: Design.Tint.sheet, size: size)
            case .task(_, _, let done): return Icon(symbol: done ? "checkmark.app" : "app", tint: Design.Tint.task, size: size)
        }
    }

    static func icon(for routine: Harness.Routine, size: CGFloat = 15) -> Icon {
        switch routine {
            case .compose: return Icon(symbol: "rectangle.3.offgrid", tint: Design.Tint.command, size: size)
            case .dispatch: return Icon(symbol: "function", tint: Design.Tint.dispatch, size: size)
            case .observe: return Icon(symbol: "clock.arrow.trianglehead.clockwise.rotate.90.path.dotted", tint: Design.Tint.active, size: size)
            case .execute: return Icon(symbol: "arrow.triangle.2.circlepath", tint: Design.Tint.execute, size: size)
            case .traverse: return Icon(symbol: "graph.3d", tint: Design.Tint.traverse, size: size)
        }
    }

    static func icon(for entry: Transcript.Entry, size: CGFloat = 15) -> Icon {
        switch entry {
            case .event: return Icon(symbol: "calendar", tint: Design.Tint.active, size: size)
            case .sheet(let ref, _): return Iconography.icon(for: ref, size: size)
            case .transcript(let ref, _, _): return Iconography.icon(for: ref, size: size)
        }
    }

    static func icon(for handle: Artifact.Handle, size: CGFloat = 15) -> Icon {
        switch handle {
            case .app: return Icon(symbol: "square.grid.2x2.fill", tint: Design.Tint.artifact, size: size)
            case .file: return Icon(symbol: "folder", tint: Design.Tint.artifact, size: size)
            case .http: return Icon(symbol: "bookmark", tint: Design.Tint.artifact, size: size)
            case .image: return Icon(symbol: "photo", tint: Design.Tint.artifact, size: size)
            case .script: return Icon(symbol: "scroll", tint: Design.Tint.artifact, size: size)
            case .skill: return Icon(symbol: "brain.head.profile", tint: Design.Tint.artifact, size: size)
            case .exec: return Icon(symbol: "terminal", tint: Design.Tint.artifact, size: size)
        }
    }

    static func icon(for ref: Reference, size: CGFloat = 15) -> Icon {
        switch ref.type {
            case is Artifact.Type:
                guard let handle = Artifact.with(ref, { $0 })?.handle
                else { return Icon(symbol: "", tint: Design.Tint.active, size: size) }
                return Iconography.icon(for: handle, size: size)
            case is Space.Type:
                guard let space = Space.with(ref, { $0.harness }).flatMap({ $0 }), let harness = Harness.with(space, { $0.routine })
                else { return Icon(symbol: "app", tint: Design.Tint.info, size: size) }
                return Iconography.icon(for: harness, size: size)
            case is Command.Type:
                return Icon(symbol: "switch.2", tint: Design.Tint.command, size: size)
            case is Route.Type:
                return Icon(symbol: "app.connected.to.app.below.fill", tint: Design.Tint.space, size: size)
            case is Harness.Type:
                guard let routine = Harness.with(ref, { $0.routine })
                else { return Icon(symbol: "gear", tint: Design.Tint.harness, size: size) }
                return Iconography.icon(for: routine, size: size)
            case is Sheet.Type:
                return Icon(symbol: "text.alignleft", tint: Design.Tint.sheet, size: size)
            case is Transcript.Type:
                for entry in Transcript.with(ref, { $0.entries }) ?? [] { return Iconography.icon(for: entry, size: size) }
                return Icon(symbol: "rectangle.stack", tint: Design.Tint.running, size: size)
            case is Workspace.Type:
                return Icon(symbol: "cube.transparent", tint: Design.Tint.info, size: size)
            default:
                break
        }
        return Icon(symbol: "app", tint: Design.Tint.active)
    }

    static func symbol(for ref: Reference) -> String { icon(for: ref).symbol }
    static func symbol(for block: Sheet.Block) -> String { icon(for: block).symbol }
    static func symbol(for entry: Transcript.Entry) -> String { icon(for: entry).symbol }
    static func symbol(for handle: Artifact.Handle) -> String { icon(for: handle).symbol }
    static func symbol(for routine: Harness.Routine) -> String { icon(for: routine).symbol }

    static func accent(for ref: Reference) -> Color {
        switch ref.type {
            case is Artifact.Type:
                return Design.Tint.artifact
            case is Command.Type:
                return Design.Tint.command
            case is Route.Type:
                return Design.Tint.space
            case is Harness.Type:
                return Iconography.icon(for: ref).tint
            case is Sheet.Type:
                return Design.Tint.sheet
            case is Transcript.Type:
                return Design.Tint.running
            case is Space.Type:
                guard let harness = Space.with(ref, { $0.harness }).flatMap({ $0 }), let mode = Harness.with(harness, { $0.routine })
                else { return Design.Tint.info }
                return Iconography.icon(for: mode).tint
            case is Workspace.Type:
                return Design.Tint.info
            default:
                return Iconography.icon(for: ref).tint
        }
    }

    struct Icon: View {
        let symbol: String
        let size: CGFloat
        let tint: Color

        private var symbolSize: CGFloat { size * 0.72 }
        private var cornerRadius: CGFloat { size * 0.35 }
        private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: cornerRadius, style: .continuous) }

        init(symbol: String, tint: Color, size: CGFloat = 16) {
            self.symbol = symbol
            self.size = size
            self.tint = tint
        }

        var body: some View {
            ZStack(alignment: .center) {
                shape.fill(tint.opacity(0.18))

                Image(systemName: symbol)
                    .frame(alignment: .center)
                    .font(.system(size: symbolSize))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(tint)
            }
            .frame(width: size, height: size)
            .overlay(shape.strokeBorder(tint.opacity(0.3), lineWidth: 0.5))
        }
    }
}
