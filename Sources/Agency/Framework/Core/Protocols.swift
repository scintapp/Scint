import SwiftUI
import AppKit
import AgencyRuntime
import UniformTypeIdentifiers

protocol Model: CaseIterable {}

protocol Mapper {
    static func params(_ agency: AgencyModel) -> Params
    static func params(_ agency: AgencyModel, _ frame: any Frame) -> Params
    static func controls(_ agency: AgencyModel) -> Controls
}

extension Mapper {
    static func params(_ agency: AgencyModel, _ frame: any Frame) -> Params { .init() }
}

protocol Panel: View {}

protocol Frame: AnyObject {
    var position: CGFloat { get set }
    var presented: Bool { get set }
    var expanded: Set<AnyHashable> { get set }
}

extension Frame {
    func isExpanded(_ id: AnyHashable) -> Bool { expanded.contains(id) }
    func setExpanded(_ id: AnyHashable) {
        if expanded.contains(id) { expanded.remove(id) }
        else { expanded.insert(id) }
    }

    @MainActor func build(_ agency: AgencyModel) -> some View {
        ContentUnavailableView(String(describing: self), image: "app.grid")
    }

    @MainActor func detatch(_ agency: AgencyModel) {
        let view = AnyView(BasePanel(self.build(agency)))
        agency.panel(id: "search", size: CGSize(width: 640, height: 480), view: view).toggle()
    }
}

protocol Feature {}

