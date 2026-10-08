import SwiftUI
import UniformTypeIdentifiers
import ScintRuntime


enum Layout: CaseIterable { case grid, group, list, table }

struct Params: Hashable, Identifiable {
    var id = AnyHashable("host")
    var ref: Reference?
    var name = ""
    var description = ""
    var layout: Layout?
    var header = false
    var panel: PanelParams?
    var sections: [SectionParams] = []
}
