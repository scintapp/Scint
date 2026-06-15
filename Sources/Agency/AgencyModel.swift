import AgencyRuntime
import Foundation
import SwiftUI


@Observable @MainActor final class AgencyModel {
    var aperture: Aperture
    var artifacts: ArtifactManager
    var studio: StudioModel
    var session: Session
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
        session.focus(ref, from: origin, entry: entry, url: url)
    }

    func select(_ ref: Reference, entry: UUID?) {
        session.select(ref, entry: entry)
    }

    func select(_ ref: Reference, from origin: Reference? = nil, entry: UUID? = nil, url: URL? = nil) {
        session.select(ref, from: origin, entry: entry, url: url)
    }

    func open(_ ref: Reference, from origin: Reference? = nil, entry: UUID? = nil, url: URL? = nil) {
        session.open(ref, from: origin, entry: entry, url: url)
    }

    func forward() {
        session.forward()
    }

    func backward() {
        session.back()
    }

    func clear(_ axis: Selection.Axis) {
        session.clear(axis)
    }

    func query(_ query: String, facet: String, limit: Int) -> [QueryResult] { Runtime.shared.query("\(query) !\(facet)", limit: limit).all }

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
        studio.inspector.model = .composition
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
        studio.inspector.model = .composition
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

    func toggleAperture() {
        let view = AnyView(BasePanel(SearchView().environment(self)))
        panel(id: "aperture", size: CGSize(width: 640, height: 480), view: view).toggle()
    }

    private func panel(id: AnyHashable, size: CGSize, view: @autoclosure () -> AnyView) -> PanelCoordinator {
        if let existing = panels[id] { return existing }
        let new = PanelCoordinator.load(agency: self, size: size, view: view())
        panels[id] = new
        return new
    }
}
