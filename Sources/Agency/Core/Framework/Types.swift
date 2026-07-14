import SwiftUI
import AppKit
import Foundation
import OrderedCollections
import AgencyRuntime


enum Layout: CaseIterable { case grid, group, list, table }
enum Nesting: String, CaseIterable { case recursive, single, flat }

struct SurfaceState {
    var expanded: Set<AnyHashable> = []
    var filter: String = ""
    var values: [AnyHashable: AnyHashable] = [:]

    func isExpanded(_ id: AnyHashable) -> Bool { expanded.contains(id) }

    mutating func setExpanded(_ id: AnyHashable) {
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

@MainActor protocol Feature: View {}

@MainActor protocol Mapper {
    static func controls(_ agency: AgencyModel) -> Controls
    static func parameters(_ agency: AgencyModel) -> Params
    static func item(from result: SearchResult) -> ItemParams
}

@MainActor protocol Panel: Surface, AnyObject {
    associatedtype Model = CaseIterable
    var model: Model { get }
    var presented: Bool { get set }
    var state: SurfaceState { get set }
    func controls() -> Controls
    func parameters() -> Params
}

@MainActor protocol Surface: View {
    func controls() -> Controls
    func parameters() -> Params
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
    func controls() -> Controls { .init() }
    func parameters() -> Params { .init() }
    func toolbar() -> any ToolbarContent { ToolbarItem() { EmptyView() } }
    func isExpanded(_ id: AnyHashable) -> Bool { state.isExpanded(id) }
    func setExpanded(_ id: AnyHashable) { state.setExpanded(id) }
}

extension Surface {
    func controls() -> Controls { .init() }
    func parameters() -> Params { .init() }
    func isExpanded(_ id: AnyHashable) -> Bool { false }
    func setExpanded(_ id: AnyHashable) {}

    var body: some View {
        Builder.build(self, parameters(), controls())
    }
}
