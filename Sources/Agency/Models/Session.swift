import AgencyRuntime
import Foundation
import SwiftUI


@Observable final class SessionModel {
    private(set) var selection: Selection
    private(set) var history: [Selection] = []
    private(set) var cursor: Int = -1
    private static let maxHistory = 100
    private static let maxPathDepth = 100

    var space: Reference { selection.space }
    var boundary: Reference? { selection.boundary }
    var component: Reference? { selection.component }
    var entry: UUID? { selection.entry }
    var url: URL? { selection.url }

    var thread: Reference? {
        guard let component, component.type is Journal.Type else { return nil }
        return component
    }

    var sheet: Reference? {
        guard let component, component.type is Sheet.Type else { return nil }
        return component
    }

    var canGoBack: Bool { cursor > 0 }
    var canGoForward: Bool { cursor < history.count - 1 }

    var path: [Reference] {
        var refs: [Reference] = [selection.space]

        if let boundary = selection.boundary {
            var chain: [Reference] = []
            var cursor: Reference? = boundary
            var depth = 0
            while let current = cursor, depth < Self.maxPathDepth {
                chain.append(current)
                cursor = Boundary.with(current) { $0.boundary } ?? nil
                depth += 1
            }
            refs.append(contentsOf: chain.reversed())
        }

        if let component = selection.component {
            refs.append(component)
        }

        return refs
    }

    init(_ space: Reference) {
        let initial = Selection(space: space)
        self.selection = initial
        self.history = [initial]
        self.cursor = 0
    }

    func selected(_ ref: Reference) -> Bool { selection.selected(ref) }
    func selected(_ ref: Reference, _ entry: UUID?) -> Bool { selection.selected(ref, entry) }
    func selected(_ ref: Reference, _ url: URL?) -> Bool { selection.selected(ref, url) }

    @discardableResult
    func apply(_ next: Selection, pushHistory: Bool = true) -> Bool {
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

    func reset(to space: Reference) {
        let initial = Selection(space: space)
        selection = initial
        history = [initial]
        cursor = 0
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
}
