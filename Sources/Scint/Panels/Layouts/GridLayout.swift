import SwiftUI


private enum GridItemRole: Equatable {
    case item
    case space
    case material(Reference)

    var isMaterial: Bool {
        if case .material = self { return true }
        return false
    }

    var reference: Reference? {
        if case .material(let ref) = self { return ref }
        return nil
    }

    init(_ ref: Reference?) {
        switch ref?.type {
            case is Space.Type: self = .space
            case is Material.Type: self = ref.map(Self.material) ?? .item
            default: self = .item
        }
    }
}

private struct GridItemRoleKey: ContainerValueKey {
    static let defaultValue: GridItemRole = .item
}

private extension ContainerValues {
    var gridItem: GridItemRole {
        get { self[GridItemRoleKey.self] }
        set { self[GridItemRoleKey.self] = newValue }
    }
}

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
        .background(shape.fill(focused ? Style.Tint.info.opacity(0.12) : Color.clear))
        .contentShape(shape)
        .gesture(
            TapGesture(count: 2)
                .onEnded { onOpen() }
                .exclusively(before: TapGesture(count: 1).onEnded { onSelect() })
        )
    }

    @ViewBuilder private var glyph: some View {
        if let ref, ref.type is Material.Type {
            MaterialGlyph(ref: ref)
        } else if let ref {
            spaceGlyph(ref)
        } else {
            Iconography.Icon(
                symbol: image,
                tint: tint ?? Style.Tint.active,
                sizing: 20
            )
        }
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
        .glassEffect(.regular.tint(Style.Background.base.opacity(0.4)), in: shape)
        .overlay(shape.strokeBorder(accent.opacity(0.28), lineWidth: 0.5))
        .contentShape(shape)
    }

    @ViewBuilder private func miniGlyph(at index: Int, refs: [Reference], overflow: Int) -> some View {
        let shape = RoundedRectangle(cornerRadius: 5, style: .continuous)
        let ref = index < refs.count ? refs[index] : nil
        let overflowLabel = index == refs.count && overflow > 0 ? "+\(overflow)" : nil
        let tint = ref.map { Iconography.accent(for: $0) } ?? Style.Tint.active

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

        let materials = contents.1.flatMap { Closure.with($0, { $0.content.filter { $0.type is Material.Type } }) } ?? []
        return contents.0 + materials
    }
}

struct MaterialGlyph: View {
    let ref: Reference
    var width: CGFloat = 42
    var height: CGFloat = 54

    var body: some View {
        let page = RoundedRectangle(cornerRadius: 6, style: .continuous)
        let icon = Iconography.icon(for: ref, size: 15)
        let content = Material.with(ref, { $0.rendered }) ?? ""

        Text(content)
            .font(.system(size: 3, weight: .light))
            .lineSpacing(0)
            .foregroundStyle(.black.opacity(0.9))
            .padding(4)
            .frame(width: width, height: height, alignment: .topLeading)
            .glassEffect(.clear, in: page)
            .background(page.fill(.primary.opacity(0.9)))
            .overlay(page.strokeBorder(icon.tint.opacity(0.38), lineWidth: 0.5))
            .clipShape(page)
    }
}

//struct MaterialStackIcon: View {
//    let refs: [Reference]
//    let expanded: Bool
//    let onToggle: () -> Void
//
//    private let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
//
//    var body: some View {
//        Button(action: onToggle) {
//            VStack {
//                ZStack {
//                    ForEach(Array(refs.prefix(3).enumerated().reversed()), id: \.element) { index, ref in
//                        MaterialGlyph(ref: ref, width: 40, height: 52)
//                            .rotationEffect(.degrees(rotation(for: index)))
//                            .offset(x: offset(for: index).width, y: offset(for: index).height)
//                    }
//
//                    if expanded {
//                        RoundedRectangle(cornerRadius: 6, style: .continuous)
//                            .fill(Style.Background.base.opacity(0.72))
//                            .frame(width: 44, height: 36)
//                            .overlay {
//                                Image(systemName: "chevron.down")
//                                    .font(.system(size: 17, weight: .medium))
//                                    .foregroundStyle(Style.Foreground.primary)
//                            }
//                    }
//                }
//                .frame(width: 66, height: 66)
//
//                Text("Materials\n\(refs.count) items")
//                    .font(.system(size: 12, weight: .medium))
//                    .foregroundStyle(.primary.opacity(0.9))
//                    .multilineTextAlignment(.center)
//                    .lineLimit(2)
//                    .frame(maxWidth: 112, minHeight: 30, maxHeight: 34, alignment: .top)
//            }
//            .frame(width: 96, height: 112)
//            .contentShape(shape)
//        }
//        .buttonStyle(.plain)
//        .help(expanded ? "Collapse materials" : "Show \(refs.count) materials")
//    }
//
//    private func rotation(for index: Int) -> Double {
//        switch index {
//            case 0: return expanded ? -7 : -4
//            case 1: return expanded ? 7 : 4
//            default: return 0
//        }
//    }
//
//    private func offset(for index: Int) -> CGSize {
//        switch index {
//            case 0: return .init(width: -4, height: 1)
//            case 1: return .init(width: 4, height: 2)
//            default: return .zero
//        }
//    }
//}

struct GridLayout<Content: View>: View {
    @State private var expanded = false
    @ViewBuilder let content: () -> Content
    private let gridItem = GridItem(.adaptive(minimum: 128, maximum: 128), spacing: 8, alignment: .topLeading)

    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }

    var body: some View {
        Group(subviews: content()) { subviews in
            let spaces = subviews.filter { $0.containerValues.gridItem == .space }
            let materials = subviews.filter { $0.containerValues.gridItem.isMaterial }
            let items = subviews.filter { $0.containerValues.gridItem == .item }
            let refs = materials.compactMap(\.containerValues.gridItem.reference)

            HStack(alignment: .top, spacing: 8) {
                if !items.isEmpty {
                    LazyHGrid(rows: [gridItem], alignment: .center, spacing: 8) {
                        ForEach(items) { $0 }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                } else { Spacer(minLength: 0) }

                if !spaces.isEmpty || !materials.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(spaces) { $0 }
                    }
                    .frame(width: 128, alignment: .topTrailing)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topTrailing)
        }
    }
}

