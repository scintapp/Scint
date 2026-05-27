import SwiftUI
import AppKit
import AgencyRuntime
import UniformTypeIdentifiers

enum Layout: CaseIterable { case list, grid, column, group, table }
protocol Model {}

protocol Mapper {
    static func closures(_ agency: AgencyModel, _ panel: any Panel) -> Closures
    static func params(_ agency: AgencyModel, _ panel: any Panel) -> Params
}

extension Mapper {
    static func closures(_ agency: AgencyModel, _ panel: any Panel) -> Closures { .init() }
    static func params(_ agency: AgencyModel, _ panel: any Panel) -> Params { .init() }
}

protocol Panel: AnyObject {
    associatedtype Model = CaseIterable
    var model: Model { get }
    var layout: Layout { get }
    var position: CGFloat { get set }
    var presented: Bool { get set }
    var expanded: Set<AnyHashable> { get set }
    func closures(_ agency: AgencyModel) -> Closures
    func params(_ agency: AgencyModel) -> Params
}

extension Panel {
    func isExpanded(_ id: AnyHashable) -> Bool { expanded.contains(id) }
    func setExpanded(_ id: AnyHashable) {
        if expanded.contains(id) { expanded.remove(id) }
        else { expanded.insert(id) }
    }

    @MainActor func build(_ agency: AgencyModel) -> some View {
        Builder.build(self, closures(agency), params(agency))
    }
}

protocol Feature: View {}

@Observable final class EmptyPanel: Panel {
    var layout: Layout = .grid
    var model: Model = .empty
    var position: CGFloat = 0
    var presented: Bool = false
    var expanded: Set<AnyHashable> = []
    enum Model: CaseIterable { case empty }
    func closures(_ agency: AgencyModel) -> Closures { .init() }
    func params(_ agency: AgencyModel) -> Params { .init() }
}

@Observable final class EmptyModel: Model {
    let sidebar = EmptyPanel()
    let content = EmptyPanel()
    let detail = EmptyPanel()
}

struct EmptyFeature: Feature {
    @Environment(AgencyModel.self) var agency

    init() { agency.models["EmptyModel"] = EmptyModel() }

    var body: some View {
        @Bindable var model = agency.models["EmptyModel"] as! EmptyModel
        @Bindable var sidebar = model.sidebar
        @Bindable var content = model.content
        @Bindable var detail = model.detail

        NavigationSplitView {
            sidebar.build(agency)
        } content: {
            content.build(agency)
        } detail: {
            detail.build(agency)
        }
    }
}
