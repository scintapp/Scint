import AgencyRuntime
import Foundation
import SwiftUI


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

    var transcript: Reference? {
        guard let component, component.type is Transcript.Type else { return nil }
        return component
    }

    var canGoBack: Bool { cursor > 0 }
    var canGoForward: Bool { cursor < history.count - 1 }

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

    func selected(_ ref: Reference) -> Bool { selection.selected(ref) }
    func selected(_ ref: Reference, _ entry: UUID?) -> Bool { selection.selected(ref, entry) }
    func selected(_ ref: Reference, _ url: URL?) -> Bool { selection.selected(ref, url) }
    func focused(_ ref: Reference) -> Bool { focus?.focused(ref) ?? false }
    func focused(_ ref: Reference, _ entry: UUID?) -> Bool { focus?.focused(ref, entry) ?? false }
    func focused(_ ref: Reference, _ url: URL?) -> Bool { focus?.focused(ref, url) ?? false }
    func focused(_ ref: Reference, entry: UUID?, url: URL?) -> Bool {
        focus?.focused(ref, entry: entry, url: url) ?? false
    }

    func setFocus(_ ref: Reference, from origin: Reference? = nil, entry: UUID? = nil, url: URL? = nil) {
        focus = Focus.focusing(ref, from: origin, entry: entry, url: url)
    }

    @discardableResult
    func setOpen(_ ref: Reference, from origin: Reference? = nil, entry: UUID? = nil) -> Bool {
        guard ref.type is Sheet.Type else { return false }
        open = Open.opening(ref, from: origin, entry: entry)
        return true
    }

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
        focus = nil
        open = nil
        service = nil
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

@Observable final class AgencyModel: Model {
    var aperture: Aperture
    var artifacts: ArtifactManager
    var studio: StudioModel
    var session: Session
    var models: [AnyHashable: any Model] = [:]
    var panels: [AnyHashable: PanelCoordinator] = [:]

    init(_ space: Reference) {
        self.aperture = .init()
        self.artifacts = .init()
        self.studio = .init()
        self.session = .init(space)
    }

    func load() async {
        await load(Runtime.shared.workspace)
        await SampleData.load()
        try? await Runtime.shared.save()
    }

    func load(_ space: Reference) async {
        session.reset(to: space)
        await artifacts.load(runtime: Runtime.shared, space: space)
    }

    func focus(_ ref: Reference, from origin: Reference? = nil, entry: UUID? = nil, url: URL? = nil) {
        session.setFocus(ref, from: origin, entry: entry, url: url)
    }

    func select(_ ref: Reference, entry: UUID?) {
        guard !(ref.type is Sheet.Type) else {
            open(ref, entry: entry)
            return
        }
        session.apply(session.selection.selecting(ref, entry: entry))
        syncContentModel(for: session.selection)
    }

    func select(_ ref: Reference, from origin: Reference? = nil, entry: UUID? = nil, url: URL? = nil) {
        guard !(ref.type is Sheet.Type) else {
            open(ref, from: origin, entry: entry)
            return
        }
        session.apply(session.selection.selecting(ref, from: origin, entry: entry, url: url))
        syncContentModel(for: session.selection)
    }

    func open(_ ref: Reference, from origin: Reference? = nil, entry: UUID? = nil) {
        if session.setOpen(ref, from: origin, entry: entry) {
            studio.content.model = .sheet
        } else {
            select(ref, from: origin)
        }
    }
    func forward() {
        if let selection = session.forward() { syncContentModel(for: selection) }
    }
    func backward() {
        if let selection = session.back() { syncContentModel(for: selection) }
    }
    func clear(_ axis: Selection.Axis) {
        session.apply(session.selection.clearing(axis))
        syncContentModel(for: session.selection)
    }
    func query(_ query: String, facet: String, limit: Int) -> [QueryResult] {
        Runtime.shared.query("\(query) !\(facet)", limit: limit).all
    }

    private func syncContentModel(for _: Selection) {
        studio.content.model = .space
    }

    @discardableResult
    func process(service: Reference? = nil, arguments: [String] = []) -> Composition? {
        let services = Workspace.with(session.workspace, { $0.services }) ?? []
        let selected = service ?? session.service

        guard let origin = session.space,
              let closure = Space.with(origin, { $0.closure }),
              let service = selected.flatMap({ services.contains($0) ? $0 : nil }) ?? services.first
        else { return nil }

        let existing = Set(Runtime.shared.transcripts(for: origin))
        session.service = service
        let processArguments = arguments.isEmpty ? [closure.id.uuidString] : arguments
        guard let composition = Runtime.shared.compose(Request(origin, [.process(service, args: processArguments)]))
        else { return nil }

        let transcript = latestProcessTranscript(in: composition)
        ?? Runtime.shared.transcripts(for: origin).first { !existing.contains($0) }
        ?? composition.transcript
        select(transcript, from: origin)
        studio.inspector.context = .processing
        return composition
    }

    @discardableResult
    func selectProcessTranscript(for origin: Reference? = nil) -> Reference? {
        guard let origin = origin ?? session.space,
              origin.type is Space.Type,
              let composition = Runtime.shared.context(for: origin),
              let transcript = latestProcessTranscript(in: composition)
        else { return nil }
        select(transcript, from: origin)
        return transcript
    }

    func openProcessInspector() {
        selectProcessTranscript()
        studio.inspector.context = .processing
        studio.inspector.presented = true
    }

    private func latestProcessTranscript(in composition: Composition) -> Reference? {
        composition.intention.reversed().compactMap { intention in
            if case .process(let ref) = intention { return ref }
            return nil
        }.first
    }

    func item(from result: QueryResult) -> ItemParams {
        ItemParams(
            ref: result.ref,
            name: result.name,
            image: Design.Component.icon(for: result.ref),
            description: result.description,
            tags: result.tags.sorted()
        )
    }

    @MainActor func toggleAperture() {
        let view = AnyView(BasePanel(SearchView().environment(self)))
        panel(id: "aperture", size: CGSize(width: 640, height: 480), view: view).toggle()
    }

    @MainActor func toggleProcesses() {
        let view = AnyView(BasePanel(EmptyView().environment(self)))
        panel(id: "processes", size: CGSize(width: 640, height: 480), view: view).toggle()
    }

    @MainActor func panel(id: AnyHashable, size: CGSize, view: @autoclosure () -> AnyView) -> PanelCoordinator {
        if let existing = panels[id] { return existing }
        let new = PanelCoordinator.load(agency: self, size: size, view: view())
        panels[id] = new
        return new
    }
}
