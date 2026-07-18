import SwiftUI
import AppKit
import Foundation
import OrderedCollections
import AgencyRuntime


enum Layout: CaseIterable { case grid, group, list, table }
enum Nesting: String, CaseIterable { case recursive, single, flat }

@MainActor protocol Mapper {
    static func controls(_ agency: AgencyModel) -> Controls
    static func parameters(_ agency: AgencyModel) -> Params
    static func item(from result: SearchResult) -> ItemParams
}

@MainActor protocol Panel: AnyObject {
    associatedtype Surface
    var state: StateContainer { get set }
    func controls(_ agency: AgencyModel) -> Controls
    func parameters(_ agency: AgencyModel) -> Params
    func surface(_ agency: AgencyModel) -> Surface
//    func isExpanded(_ id: AnyHashable) -> Bool
//    func setExpanded(_ id: AnyHashable)
}

@MainActor protocol Surface: View {
    var panel: any Panel { get set }
//    func controls(_ agency: AgencyModel) -> Controls
//    func parameters(_ agency: AgencyModel) -> Params
    func isExpanded(_ id: AnyHashable) -> Bool
    func setExpanded(_ id: AnyHashable)
}

extension Mapper {
    static func controls(_ agency: AgencyModel) -> Controls { .init() }
    static func parameters(_ agency: AgencyModel) -> Params { .init() }
    static func item(from result: SearchResult) -> ItemParams {
        .init(
            ref: result.ref,
            name: result.name,
            image: Iconography.icon(for: result.ref).symbol,
            description: result.description
        )
    }
}



extension Panel {
    var view: (AnySurface, Params, Controls) -> some View { Builder.build(_ :_ :_ :) }
    func controls(_ agency: AgencyModel) -> Controls { EmptyMap.controls(agency) }
    func parameters(_ agency: AgencyModel) -> Params { EmptyMap.parameters(agency) }
    func surface(_ agency: AgencyModel) -> some View { AnySurface(panel: self).environment(agency) }
//    func isExpanded(_ id: AnyHashable) -> Bool { state.isExpanded(id)}
//    func setExpanded(_ id: AnyHashable) { state.setExpanded(id) }
}

extension Surface {
    var view: (Self, Params, Controls) -> some View { Builder.build(_ :_ :_ :) }
    func toolbar(_ agency: AgencyModel) -> any ToolbarContent { ToolbarItem() { EmptyView() } }
    func isExpanded(_ id: AnyHashable) -> Bool { panel.state.isExpanded(id) }
    func setExpanded(_ id: AnyHashable) { panel.state.setExpanded(id) }
}

struct AnySurface: Surface {
    @Environment(AgencyModel.self) var agency
    var panel: any Panel
    var view: (Self, Params, Controls) -> some View { Builder.build(_ :_ :_ :) }

    var body: some View {
        view(self, panel.parameters(agency), panel.controls(agency))
            .environment(agency)
    }
    
    func isExpanded(_ id: AnyHashable) -> Bool { panel.state.isExpanded(id) }
    func setExpanded(_ id: AnyHashable) { panel.state.setExpanded(id) }
}

@Observable final class StateContainer {
    var presented: Bool = false
    var position: CGFloat = 0
    var filter: String = ""
    var expanded: Set<AnyHashable> = []
    var values: [AnyHashable: AnyHashable] = [:]

    func isExpanded(_ id: AnyHashable) -> Bool { expanded.contains(id) }

    func setExpanded(_ id: AnyHashable) {
        if expanded.contains(id) { expanded.remove(id) }
        else { expanded.insert(id) }
    }

    subscript<Value: Hashable>(_ key: AnyHashable, as type: Value.Type) -> Value? {
        get { values[key]?.base as? Value }
        set {
            if let newValue { values[key] = AnyHashable(newValue) }
            else { values[key] = nil }
        }
    }
}
