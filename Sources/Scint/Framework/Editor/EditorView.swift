import SwiftUI
import UniformTypeIdentifiers
import ScintRuntime
import ScintComponents


internal typealias Block = ScintRuntime.Document.Block

struct EditorView: View {
    @State var focus: EditorFocus
    @State private var frames: [Int: CGRect] = [:]
    @State private var indicator: CGRect?
    @State private var dragged: Int?

    let ref: Reference
    let autofocus: Bool

    init(ref: Reference, autofocus: Bool = true) {
        self.ref = ref
        self.autofocus = autofocus
        _focus = State(initialValue: EditorFocus(ref))
    }

    var io: EditorIO { EditorIO(ref: ref) }
    private var content: EditorContent { EditorContent(editor: self) }

    func drag(_ index: Int) -> NSItemProvider {
        dragged = index
        let provider = NSItemProvider()
        provider.registerDataRepresentation(forTypeIdentifier: UTType.block.identifier, visibility: .ownProcess) { $0(Data(), nil); return nil }
        return provider
    }

    private func aim(at point: CGPoint) -> (target: Int?, line: CGRect)? {
        let placed = io.body.indices.compactMap { index in frames[index].map { (index: index, frame: $0) } }.sorted { $0.frame.minY < $1.frame.minY }
        guard let last = placed.last else { return nil }
        guard let index = placed.firstIndex(where: { point.y < $0.frame.midY }) else {
            return (nil, CGRect(x: last.frame.minX, y: last.frame.maxY + 4, width: last.frame.width, height: 3))
        }
        let above = index > 0 ? placed[index - 1].frame.maxY : placed[index].frame.minY - 8
        let frame = placed[index].frame
        return (placed[index].index, CGRect(x: frame.minX, y: (above + frame.minY) / 2 - 1.5, width: frame.width, height: 3))
    }

    private func drop(at point: CGPoint) -> Bool {
        defer { dragged = nil }
        guard let aim = aim(at: point), let index = dragged, index != aim.target, io.position(index) < io.blocks.count else { return false }
        let from = io.position(index), to = aim.target.map(io.position) ?? io.blocks.count
        ScintRuntime.Document.update(ref) { document in
            let moving = document.blocks[from]
            document.delete(at: from)
            document.insert(moving, at: min(to > from ? to - 1 : to, document.blocks.count))
        }
        return true
    }

    var body: some View {
        let blocks = io.body, targets = focus.targets
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                let layout = content.spacing(block, at: index, in: blocks)
                content.view(block, targets[index], at: index, listStart: layout.start)
                    .background { if focus.selected == targets[index] && EditorIO.edits(block) { Style.Shape.card.fill(Style.Background.selection).padding(-4) } }
                    .padding(.leading, 20)
                    .overlay(alignment: .topLeading) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 11))
                            .foregroundStyle(Style.Foreground.secondary)
                            .frame(width: 16, height: Typography.Prose.lineHeight)
                            .contentShape(Rectangle())
                            .opacity(focus.target == targets[index] ? 1 : 0)
                            .onTapGesture { focus.select(targets[index]) }
                            .onDrag { drag(index) }
                            .opacity(0.0)
                    }
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("blocks")) } action: { frames[index] = $0 }
                    .padding(.top, layout.gap)
                    .contentShape(Rectangle())
                    .onTapGesture(coordinateSpace: .local) { location in focus.enter(location.y < layout.gap / 2 && index > 0 ? targets[index - 1] : targets[index], from: .previous) }
            }
            switch blocks.last {
                case .paragraph?: EmptyView()
                default:
                    BlockTextView(text: "", onClick: { _ in focus.append() })
                        .padding(.leading, 20)
                        .padding(.top, blocks.isEmpty ? 0 : Typography.Prose.blockSpacing)
                        .contentShape(Rectangle())
                        .onTapGesture { focus.append() }
            }
        }
        .coordinateSpace(.named("blocks"))
        .overlay {
            if dragged != nil {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { dragged = nil; indicator = nil }
                    .onDrop(of: [.block], delegate: BlockDrop(
                        onUpdate: { indicator = aim(at: $0)?.line },
                        onExit: { indicator = nil },
                        onPerform: { point in
                            indicator = nil
                            return drop(at: point)
                        }
                    ))
                    .overlay(alignment: .topLeading) {
                        if let indicator {
                            Capsule()
                                .fill(Style.Tint.accent.bright)
                                .frame(width: indicator.width, height: indicator.height)
                                .offset(x: indicator.minX, y: indicator.minY)
                                .allowsHitTesting(false)
                        }
                    }
            }
        }
        .padding(.leading, -20)
        .background { BlockKeys(active: focus.selected != nil) { focus.key($0) } }
        .onAppear { if autofocus, focus.target == nil, !focus.append(), let last = focus.targets.last { focus.edit(last, entry: .previous) } }
    }
}
