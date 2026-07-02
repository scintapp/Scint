import AgencyRuntime
import SwiftUI


enum Layout: CaseIterable { case grid, group, list, table }
enum Nesting: String, CaseIterable { case recursive, single, flat }

extension CaseIterable {
    var image: String { "" }
    var label: String { "" }
}

@MainActor protocol Panel: AnyObject {
    associatedtype Model = CaseIterable
    var model: Model { get }
    var layout: Layout { get }
    var position: CGFloat { get set }
    var presented: Bool { get set }
    var expanded: Set<AnyHashable> { get set }
    func controls(_ agency: AgencyModel) -> Controls
    func parameters(_ agency: AgencyModel) -> PanelParams
}

@MainActor protocol Mapper {
    static func controls(_ agency: AgencyModel, _ panel: any Panel) -> Controls
    static func parameters(_ agency: AgencyModel, _ panel: any Panel) -> PanelParams
    static func item(from result: SearchResult) -> ItemParams
}

@MainActor protocol Feature: View {}

extension Panel {
    func isExpanded(_ id: AnyHashable) -> Bool { expanded.contains(id) }
    func setExpanded(_ id: AnyHashable) { if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) } }
    func controls(_ agency: AgencyModel) -> Controls { .init() }
    func parameters(_ agency: AgencyModel) -> PanelParams { .init() }
    func toolbar(_ agency: AgencyModel) -> any ToolbarContent { ToolbarItem() { EmptyView() } }
    func view(_ agency: AgencyModel) -> some View { Builder.build(agency, self) }
}

extension Mapper {
    static func controls(_ agency: AgencyModel, _ panel: any Panel) -> Controls { .init() }
    static func parameters(_ agency: AgencyModel, _ panel: any Panel) -> PanelParams { .init() }
    static func item(from result: SearchResult) -> ItemParams {
        .init(
            ref: result.ref,
            name: result.name,
            image: Iconography.icon(for: result.ref).symbol,
            description: result.description
        )
    }
}

@Observable final class EmptyPanel: Panel {
    enum Model: CaseIterable { case empty }
    var model: Model = .empty
    var layout: Layout = .grid
    var position: CGFloat = 0
    var presented: Bool = false
    var expanded: Set<AnyHashable> = []
    func controls(_ agency: AgencyModel) -> Controls { .init() }
    func parameters(_ agency: AgencyModel) -> PanelParams { .init() }
    func toolbar() -> some ToolbarContent { ToolbarItem { EmptyView() } }
    func view(_ agency: AgencyModel) -> some View { Builder.build(agency, self).toolbar { self.toolbar() } }
}

@Observable @MainActor final class EmptyModel {
    let sidebar = EmptyPanel()
    let content = EmptyPanel()
    let detail = EmptyPanel()
}

struct EmptyFeature: Feature {
    @Environment(AgencyModel.self) var agency
    @State var model = EmptyModel()

    var body: some View {
        @Bindable var sidebar = model.sidebar
        @Bindable var content = model.content
        @Bindable var detail = model.detail

        NavigationSplitView {
            sidebar.view(agency)
        } content: {
            content.view(agency)
        } detail: {
            detail.view(agency)
        }
    }
}
