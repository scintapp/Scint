import SwiftUI
import UniformTypeIdentifiers
import ScintRuntime


enum Layout: CaseIterable { case grid, group, list, table }

struct Controls {
    enum Input { case move(Int), submit, secondary, cancel }

    var onToggle: ((ItemParams) -> Void)?
    var onChange: ((_ item: ItemParams, _ selection: ItemParams) -> Void)?
    var onValueChange: ((_ item: ItemParams, _ value: String) -> Void)?
    var focused: ((_ item: ItemParams) -> Bool)?
    var selected: ((_ item: ItemParams) -> Bool)?
    var onSelect: ((_ item: ItemParams) -> Void)?
    var onAction: ((_ item: ItemParams) -> Void)?
    var onInput: ((_ input: Input) -> Bool)?
    var onTabSelect: ((_ tab: SectionParams) -> Void)?
    var results: ((_ section: SectionParams, _ query: String) -> [SectionParams])?
    var surfaceDropTarget: (() -> ItemParams?)?
    var sectionDropTarget: ((_ section: SectionParams) -> ItemParams?)?
    var itemPalette: ((_ item: ItemParams) -> [ActionParams])?
    var wrapLink: ((_ view: AnyView, _ item: ItemParams, _ depth: Int) -> AnyView)?
    var wrapHeader: ((_ view: AnyView, _ section: SectionParams) -> AnyView)?
    var itemLeadingAccessory: ((_ item: ItemParams, _ depth: Int) -> AnyView?)?
    var dropTypes: ((_ item: ItemParams) -> [UTType])?
    var onDrop: ((_ providers: [NSItemProvider], _ target: ItemParams) -> Bool)?
}

struct Params: Hashable, Identifiable {
    var id = AnyHashable("host")
    var ref: Reference?
    var name = ""
    var description = ""
    var layout: Layout?
    var header = false
    var described = true
    var tabbed = false
    var input: ItemParams?
    var cursor: AnyHashable?
    var panel: PanelParams?
    var sections: [SectionParams] = []

    func tab(_ id: AnyHashable) -> SectionParams? { sections.first { $0.id == id } ?? sections.first }

    func shown(_ tab: AnyHashable) -> [SectionParams] { tabbed ? self.tab(tab)?.sections ?? [] : sections }

    func rows(_ tab: AnyHashable) -> [ItemParams] { shown(tab).flatMap(\.items).flatMap { $0.isParent ? $0.items : [$0] }.filter(\.actionable) }
}

