import SwiftUI
import UniformTypeIdentifiers


struct Controls {
    var onToggle: ((ItemParams) -> Void)?
    var onChange: ((_ item: ItemParams, _ selection: ItemParams) -> Void)?
    var onValueChange: ((_ item: ItemParams, _ value: String) -> Void)?
    var focused: ((_ item: ItemParams) -> Bool)?
    var selected: ((_ item: ItemParams) -> Bool)?
    var onSelect: ((_ item: ItemParams) -> Void)?
    var onAction: ((_ item: ItemParams) -> Void)?
    var surfaceDropTarget: (() -> ItemParams?)?
    var sectionDropTarget: ((_ section: SectionParams) -> ItemParams?)?
    var itemPalette: ((_ item: ItemParams) -> [Item])?
    var wrapLink: ((_ view: AnyView, _ item: ItemParams, _ depth: Int) -> AnyView)?
    var wrapHeader: ((_ view: AnyView, _ section: SectionParams) -> AnyView)?
    var itemLeadingAccessory: ((_ item: ItemParams, _ depth: Int) -> AnyView?)?
    var dropTypes: ((_ item: ItemParams) -> [UTType])?
    var onDrop: ((_ providers: [NSItemProvider], _ target: ItemParams) -> Bool)?
}
