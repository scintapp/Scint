import AgencyRuntime
import SwiftUI


@Observable final class StudioModel {
    let console = Console()
    let content = Content()
    let navigator = Navigator()
    let inspector = Inspector()
}

@Observable final class AgencyModel {
    var artifacts: ArtifactManager
    var panels: [AnyHashable: PanelCoordinator] = [:]
    var studio: StudioModel
    let session: SessionModel
    var search: Search
    var settings: Settings

    init(_ space: Reference) {
        self.search = .init()
        self.artifacts = .init()
        self.session = .init(space)
        self.settings = .init()
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
        if ref.type is Sheet.Type, entry == nil, url == nil { studio.content.model = .edit }
        else if ref.type is Boundary.Type || ref.type is Space.Type { studio.content.model = .browse }
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
        let view = AnyView(BasePanel(ActivityPanel().environment(self)))
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
