import SwiftUI
import ScintRuntime


/// Proof the two sides connect. Neither of these is the real thing — they exist so the
/// coordinator has something to coordinate.
enum DocumentParts: Shapeable {
    static func parts(of ref: Reference) -> [Document.Block] {
        Document.with(ref, { $0.blocks }) ?? []
    }
}

struct PlainShaper: Shaping {
    /// Adjacent text blocks belong to one shape; cards stand alone.
    func coalesces(_ part: Document.Block, _ next: Document.Block) -> Bool {
        if case .text = part, case .text = next { return true }
        return false
    }

    func shape(_ run: [Document.Block], _ state: ShapeState) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(run) { block in
                DocumentBlock(block: block, isSelected: state.isSelected)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if let id = state.ids.first { state.send(.focus(id)) } }
    }
}

/// `ShapingCanvas<DocumentParts, PlainShaper>(ref: ref, shaper: PlainShaper())`
