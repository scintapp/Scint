import SwiftUI
import ScintRuntime


// MARK: - The two conformances

/// The document side. How to read a document's parts, live, from a ref.
///
/// This is deliberately app-side rather than a requirement on `ScintRuntime.Material`:
/// `Material` means "has an origin", not "is made of parts", and not every document
/// needs to be walkable.
protocol Shapeable {
    associatedtype Part: Identifiable where Part.ID: Hashable
    static func parts(of ref: Reference) -> [Part]
}

/// The view side. What a part becomes. A shape knows its part; the canvas never does.
protocol Shaping {
    associatedtype Part
    associatedtype Body: View
    @ViewBuilder func shape(_ run: [Part], _ state: ShapeState) -> Body

    /// Whether two adjacent parts can be handed to one shape instead of two.
    /// Returning false everywhere gives one shape per part.
    func coalesces(_ part: Part, _ next: Part) -> Bool
}

extension Shaping {
    func coalesces(_ part: Part, _ next: Part) -> Bool { false }
}

/// Everything the canvas can say about a run without knowing what it holds.
struct ShapeState {
    let ids: [AnyHashable]
    let isFocused: Bool
    let isSelected: Bool
    let send: (ShapeIntent) -> Void
}

/// What a shape can ask for without naming what it is. The canvas routes these;
/// it does not interpret them.
enum ShapeIntent {
    case focus(AnyHashable)
    case select(AnyHashable, extending: Bool)
    case selectAll
    case split(AnyHashable, at: Int)
    case mergeBackward(AnyHashable)
    case delete(Set<AnyHashable>)
}


// MARK: - The coordinator

/// Walks a document's parts, groups adjacent ones that shape together, and hands each
/// run to the shaper. It owns exactly one thing neither conformance can: which parts
/// are focused and selected. It knows nothing else about either side.
struct ShapingCanvas<Material: Shapeable, Shaper: Shaping>: View where Shaper.Part == Material.Part {
    let ref: Reference
    let shaper: Shaper
    var apply: (ShapeIntent) -> Void = { _ in }

    @State private var focused: AnyHashable?
    @State private var selected: Set<AnyHashable> = []

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(runs()) { run in
                shaper.shape(run.parts, state(for: run.parts))
            }
        }
    }

    private struct Run: Identifiable {
        let id: AnyHashable
        var parts: [Material.Part]
    }

    /// Adjacent parts the shaper says belong together arrive as one run. This is the
    /// seam for "a paragraph of text blocks is one editor, not N editors".
    private func runs() -> [Run] {
        var result: [Run] = []
        for part in Material.parts(of: ref) {
            if let last = result.last?.parts.last, shaper.coalesces(last, part) { result[result.count - 1].parts.append(part) }
            else { result.append(Run(id: AnyHashable(part.id), parts: [part])) }
        }
        return result
    }

    private func state(for run: [Material.Part]) -> ShapeState {
        let ids = run.map { AnyHashable($0.id) }
        return ShapeState(
            ids: ids,
            isFocused: focused.map(ids.contains) ?? false,
            isSelected: ids.contains(where: selected.contains),
            send: route
        )
    }

    private func route(_ intent: ShapeIntent) {
        switch intent {
            case .focus(let id):
                focused = id
                selected = [id]
            case .select(let id, let extending):
                focused = nil
                selected = extending ? selected.union([id]) : [id]
            case .selectAll:
                focused = nil
                selected = Set(Material.parts(of: ref).map { AnyHashable($0.id) })
            case .split, .mergeBackward, .delete:
                // Structural: only the document can answer these.
                apply(intent)
        }
    }
}
