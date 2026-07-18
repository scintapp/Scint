import AgencyRuntime
import SwiftUI


struct GridIcon: View {
    let name: String
    let ref: Reference?
    let image: String
    let tint: Color?
    let focused: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void

    private let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

    var body: some View {
        VStack {
            glyph
                .frame(width: 66, height: 66)
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
        .contentShape(shape)
        .gesture(
            TapGesture(count: 2)
                .onEnded { onOpen() }
                .exclusively(before: TapGesture(count: 1).onEnded { onSelect() })
        )
    }

    @ViewBuilder private var glyph: some View {
        if let ref, ref.type is Sheet.Type {
            sheetGlyph(ref)
        } else if let ref {
            spaceGlyph(ref)
        } else {
            Iconography.Icon(
                symbol: image,
                tint: tint ?? Design.Tint.active,
                sizing: 20
            )
        }
    }

    private func sheetGlyph(_ ref: Reference) -> some View {
        let page = RoundedRectangle(cornerRadius: 6, style: .continuous)
        let icon = Iconography.icon(for: ref, size: 15)
        let content = Sheet.with(ref, { $0.rendered }) ?? ""

        return Text(content)
            .font(.system(size: 3, weight: .light))
            .lineSpacing(0)
            .foregroundStyle(.black.opacity(0.9))
            .padding(4)
            .frame(width: 42, height: 54, alignment: .topLeading)
            .glassEffect(.clear, in: page)
            .background(page.fill(.primary.opacity(0.9)))
            .overlay(page.strokeBorder(icon.tint.opacity(0.38), lineWidth: 0.5))
            .clipShape(page)
    }

    private func spaceGlyph(_ ref: Reference) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        let accent = Iconography.accent(for: ref)
        let refs = previewRefs(for: ref)
        let shown = Array(refs.prefix(refs.count > 4 ? 3 : 4))
        let overflow = refs.count - shown.count

        return ZStack {
            LinearGradient(
                colors: [accent.opacity(0.14), Color.primary.opacity(0.035)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if shown.isEmpty {
                Iconography.icon(for: ref, size: 22)
                    .opacity(0.72)
            } else {
                VStack {
                    ForEach(0..<2, id: \.self) { row in
                        HStack {
                            ForEach(0..<2, id: \.self) { column in
                                miniGlyph(at: row * 2 + column, refs: shown, overflow: overflow)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 58, height: 58)
        .clipShape(shape)
        .glassEffect(.regular.tint(Design.Background.base.opacity(0.4)), in: shape)
        .overlay(shape.strokeBorder(accent.opacity(0.28), lineWidth: 0.5))
        .contentShape(shape)
    }

    @ViewBuilder private func miniGlyph(at index: Int, refs: [Reference], overflow: Int) -> some View {
        let shape = RoundedRectangle(cornerRadius: 5, style: .continuous)
        let ref = index < refs.count ? refs[index] : nil
        let overflowLabel = index == refs.count && overflow > 0 ? "+\(overflow)" : nil
        let tint = ref.map { Iconography.accent(for: $0) } ?? Design.Tint.active

        if ref != nil || overflowLabel != nil {
            ZStack {
                LinearGradient(
                    colors: [tint.opacity(0.52), Color.primary.opacity(0.16)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                if let ref {
                    Iconography.icon(for: ref, size: 10)
                } else if let overflowLabel {
                    Text(overflowLabel)
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.76))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
            }
            .frame(width: 18, height: 18)
            .background(shape.fill(Color.primary.opacity(0.06)))
            .overlay(shape.strokeBorder(.black.opacity(0.16), lineWidth: 0.5))
            .clipShape(shape)
        } else {
            Color.clear.frame(width: 18, height: 18)
        }
    }

    private func previewRefs(for ref: Reference) -> [Reference] {
        let contents: ([Reference], Reference?)

        switch ref.type {
            case is Workspace.Type:
                contents = (
                    Workspace.with(ref, { Array($0.spaces) }) ?? [],
                    Workspace.with(ref, { $0.closure })
                )
            case is Space.Type:
                contents = (
                    Space.with(ref, { Array($0.spaces) }) ?? [],
                    Space.with(ref, { $0.closure })
                )
            default:
                return []
        }

        let sheets = contents.1.flatMap { Closure.with($0, { $0.content.filter { $0.type is Sheet.Type } }) } ?? []
        return contents.0 + sheets
    }
}

struct GridLayout<Content: View>: View {
    @ViewBuilder let content: () -> Content
    private let gridItem = GridItem(.adaptive(minimum: 128, maximum: 128), spacing: 8, alignment: .topLeading)

    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }

    var body: some View {
        LazyVGrid(columns: [gridItem], alignment: .leading, spacing: 8) { content() }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
