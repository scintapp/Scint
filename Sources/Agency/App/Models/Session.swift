import AgencyRuntime
import Foundation


@Observable final class Session {
    private(set) var selection: Selection
    private(set) var focus: Focus?
    private(set) var open: Open?
    private(set) var history: [Selection] = []
    private(set) var cursor: Int = -1
    private static let maxHistory = 100
    private static let maxPathDepth = 100

    var service: Reference?
    var workspace: Reference { selection.workspace }
    var space: Reference? { selection.space }
    var component: Reference? { selection.component }
    var entry: UUID? { selection.entry }
    var url: URL? { selection.url }
    var sheet: Reference? { open?.sheet }
    var canGoBack: Bool { cursor > 0 }
    var canGoForward: Bool { cursor < history.count - 1 }

    var transcript: Reference? {
        guard let component, component.type is Transcript.Type else { return nil }
        return component
    }

    var path: [Reference] {
        var refs: [Reference] = [selection.workspace]

        if let space = selection.space {
            var chain: [Reference] = []
            var cursor: Reference? = space
            var depth = 0

            while let current = cursor, depth < Self.maxPathDepth {
                chain.append(current)
                cursor = Space.with(current) { $0.space } ?? nil
                depth += 1
            }
            refs.append(contentsOf: chain.reversed())
        }

        if let component = selection.component { refs.append(component) }
        return refs
    }

    init(_ space: Reference) {
        let initial = Selection(space: space)
        self.selection = initial
        self.history = [initial]
        self.cursor = 0
    }

    func focused(_ ref: Reference, entry: UUID?, url: URL?) -> Bool {
        focus?.focused(ref, entry: entry, url: url) ?? false
    }

    func selected(_ ref: Reference) -> Bool {
        selection.selected(ref)
    }

    func selected(_ ref: Reference, _ entry: UUID?) -> Bool {
        selection.selected(ref, entry)
    }

    func selected(_ ref: Reference, _ url: URL?) -> Bool {
        selection.selected(ref, url)
    }

    func focus(_ ref: Reference, from origin: Reference? = nil, entry: UUID? = nil, url: URL? = nil) {
        focus = Focus.focusing(ref, from: origin, entry: entry, url: url)
    }

    @discardableResult
    func select(_ ref: Reference, from origin: Reference? = nil, entry: UUID? = nil, url: URL? = nil) -> Bool {
        apply(selection.selecting(ref, from: origin, entry: entry, url: url))
    }

    @discardableResult
    func open(_ ref: Reference, from origin: Reference? = nil, entry: UUID? = nil, url: URL? = nil) -> Bool {
        focus(ref, from: origin, entry: entry, url: url)
        guard ref.type is Sheet.Type else { return select(ref, from: origin, entry: entry, url: url) }
        open = Open.opening(ref, from: origin, entry: entry)
        return true
    }

    @discardableResult
    func clear(_ axis: Selection.Axis) -> Bool {
        apply(selection.clearing(axis))
    }

    @discardableResult
    private func apply(_ next: Selection, pushHistory: Bool = true) -> Bool {
        guard next != selection else { return false }
        selection = next
        if pushHistory { push(next) }
        return true
    }

    @discardableResult
    func back() -> Selection? {
        guard canGoBack else { return nil }
        cursor -= 1
        let target = history[cursor]
        apply(target, pushHistory: false)
        return target
    }

    @discardableResult
    func forward() -> Selection? {
        guard canGoForward else { return nil }
        cursor += 1
        let target = history[cursor]
        apply(target, pushHistory: false)
        return target
    }

    private func push(_ selection: Selection) {
        if cursor < history.count - 1 { history.removeSubrange((cursor + 1)...) }
        history.append(selection)
        cursor = history.count - 1

        if history.count > Self.maxHistory {
            let drop = history.count - Self.maxHistory
            history.removeFirst(drop)
            cursor -= drop
        }
    }

    func reset(to space: Reference) {
        let initial = Selection(space: space)
        selection = initial
        history = [initial]
        cursor = 0
        focus = nil
        open = nil
        service = nil
    }
}
