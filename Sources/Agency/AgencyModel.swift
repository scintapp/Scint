import AgencyRuntime
import Foundation
import SwiftUI


struct Selection: Equatable, Sendable {
    var space: Reference
    var boundary: Reference?
    var component: Reference?
    var entry: UUID?
    var url: URL?

    init(space: Reference) { self.space = space }

    enum Axis: Sendable { case boundary, component, entry, url }

    func selected(_ ref: Reference) -> Bool {
        switch ref.type {
        case is Workspace.Type: return space == ref
        case is Space.Type:  return boundary == ref
        case is any Composable.Type, is any Interfacing.Type:
            return component == ref && entry == nil && url == nil
        default: return false
        }
    }

    func selected(_ ref: Reference, _ entry: UUID?) -> Bool {
        guard let entry else { return selected(ref) }
        return component == ref && self.entry == entry
    }

    func selected(_ ref: Reference, _ url: URL?) -> Bool {
        guard let url else { return selected(ref) }
        return component == ref && self.url == url
    }

    func selecting(_ ref: Reference, from origin: Reference? = nil, entry: UUID? = nil, url: URL? = nil) -> Self {
        var next = self

        switch ref.type {
        case is Workspace.Type:
            next.space = ref
            next.boundary = nil
            next.component = nil
            next.entry = nil
            next.url = nil

        case is Space.Type:
            next.boundary = ref
            next.component = nil
            next.entry = nil
            next.url = nil

        case is any Composable.Type, is any Interfacing.Type:
            if let origin, origin != next.boundary {
                next.boundary = origin
            }
            next.component = ref
            next.entry = entry
            next.url = url

        default:
            break
        }

        return next
    }

    func clearing(_ axis: Axis) -> Self {
        var next = self
        switch axis {
        case .boundary:
            next.boundary = nil
            next.component = nil
            next.entry = nil
            next.url = nil

        case .component:
            next.component = nil
            next.entry = nil
            next.url = nil

        case .entry:
            next.entry = nil

        case .url:
            next.url = nil
        }
        return next
    }
}

@Observable final class Session {
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
        guard let component, component.type is Transcript.Type else { return nil }
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
                cursor = Space.with(current) { $0.boundary } ?? nil
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

@Observable final class AgencyModel {
    var artifacts: ArtifactManager
    var features: [AnyHashable: any Feature] = [:]
    var panels: [AnyHashable: PanelCoordinator] = [:]
    var studio: StudioModel
    let session: Session
    var search: Search

    init(_ space: Reference) {
        self.search = .init()
        self.artifacts = .init()
        self.session = .init(space)
        self.studio = .init()
    }

    func load() async {
        await load(Runtime.shared.space)
        await SampleData.load()
        try? await Runtime.shared.save()
    }

    func load(_ space: Reference) async {
        session.reset(to: space)
        await artifacts.load(runtime: Runtime.shared, space: space)
    }

    func select(_ ref: Reference, from origin: Reference? = nil, entry: UUID? = nil, url: URL? = nil) {
        session.apply(session.selection.selecting(ref, from: origin, entry: entry, url: url))
        if ref.type is Sheet.Type, entry == nil, url == nil { studio.content.model = .sheet }
        else if ref.type is Space.Type || ref.type is Workspace.Type { studio.content.model = .space }
    }

    func select(_ ref: Reference, _ entry: UUID?) { session.apply(session.selection.selecting(ref, entry: entry)) }
    func open(_ ref: Reference) { select(ref) }
    func forward() { session.forward() }
    func backward() { session.back() }
    func clear(_ axis: Selection.Axis) { session.apply(session.selection.clearing(axis)) }

    func search(_ query: String, facet: String, limit: Int) -> [ItemParams] {
        Runtime.shared
            .search("\(query) !\(facet)", limit: limit)
            .all
            .map(item(from:))
    }

    func item(from result: SearchResult) -> ItemParams {
        ItemParams(
            ref: result.ref,
            name: result.name,
            image: Design.Component.icon(for: result.ref),
            description: result.description,
            tags: result.tags.sorted()
        )
    }

    @MainActor func toggleCompose() {
        let view = AnyView(BasePanel(ComposePanel().environment(self)))
        panel(id: "compose", size: CGSize(width: 640, height: 480), view: view).toggle()
    }

    @MainActor func toggleActivity() {
        let view = AnyView(BasePanel(Activities().environment(self)))
        panel(id: "activity", size: CGSize(width: 640, height: 480), view: view).toggle()
    }

    @MainActor func toggleSearch() {
        let view = AnyView(BasePanel(SearchPanel().environment(self)))
        panel(id: "search", size: CGSize(width: 640, height: 480), view: view).toggle()
    }

    @MainActor func panel(id: AnyHashable, size: CGSize, view: @autoclosure () -> AnyView) -> PanelCoordinator {
        if let existing = panels[id] { return existing }
        let new = PanelCoordinator.load(agency: self, size: size, view: view())
        panels[id] = new
        return new
    }
}
