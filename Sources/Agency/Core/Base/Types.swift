import SwiftUI
import AppKit
import Foundation
import OrderedCollections
import AgencyRuntime


enum Layout: CaseIterable { case grid, group, list, table }
enum Nesting: String, CaseIterable { case recursive, single, flat }

extension CaseIterable {
    var image: String { "" }
    var label: String { "" }
}

@MainActor protocol Host: View {}
@MainActor protocol Feature: View {}

@MainActor protocol Panel: AnyObject {
    associatedtype Model = CaseIterable
    var model: Model { get }
    var presented: Bool { get set }
    func controls(_ agency: AgencyModel) -> Controls
    func parameters(_ agency: AgencyModel) -> PanelParams
}

protocol Surface {
    associatedtype Model = CaseIterable
    var layout: Layout { get }
    var position: CGFloat { get set }
    var presented: Bool { get set }
    var state: Set<AnyHashable> { get set }
    func controls(_ agency: AgencyModel) -> Controls
    func parameters(_ agency: AgencyModel) -> PanelParams
}

@MainActor protocol Mapper {
    static func controls(_ agency: AgencyModel, _ panel: any Panel) -> Controls
    static func parameters(_ agency: AgencyModel, _ panel: any Panel) -> PanelParams
    static func item(from result: SearchResult) -> ItemParams
}

extension Surface {
    func isExpanded(_ id: AnyHashable) -> Bool { state.contains(id) }
    mutating func setExpanded(_ id: AnyHashable) { if state.contains(id) { state.remove(id) } else { state.insert(id) } }
}

extension Panel {
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

// MARK: - Sketches/examples

@Observable final class EmptyPanel: Panel {
    enum Model: CaseIterable { case empty }
    var state: Set<AnyHashable> = []
    var model: Model = .empty
    var layout: Layout = .grid
    var position: CGFloat = 0
    var presented: Bool = false

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

