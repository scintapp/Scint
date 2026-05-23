import SwiftUI
import AppKit
import AgencyRuntime
import UniformTypeIdentifiers


protocol Mapper {
    static func closures(_ agency: AgencyModel, _ frame: any Panel) -> Closures
    static func params(_ agency: AgencyModel, _ frame: any Panel) -> Params
}

extension Mapper {
    static func closures(_ agency: AgencyModel, _ frame: any Panel) -> Closures { .init() }
    static func params(_ agency: AgencyModel, _ frame: any Panel) -> Params { .init() }
}

protocol Panel: AnyObject {
    associatedtype Model = CaseIterable
    var model: Model { get }
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

protocol Feature {}

