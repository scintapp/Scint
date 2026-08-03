import SwiftUI

import UniformTypeIdentifiers


struct Controls {
    var onToggle: ((ItemParams) -> Void)?
    var onChange: ((_ item: ItemParams, _ selection: ItemParams) -> Void)?
    var onValueChange: ((_ item: ItemParams, _ value: String) -> Void)?
    var focused: ((_ item: ItemParams) -> Bool)?
    var selected: ((_ item: ItemParams) -> Bool)?
    var onSelect: ((_ item: ItemParams) -> Void)?
    var onOpen: ((_ item: ItemParams) -> Void)?
    var onAction: ((_ item: ItemParams) -> Void)?
    var onAddItem: ((_ parentId: AnyHashable, _ name: String) -> Void)?
    var onAddSection: ((_ name: String) -> Void)?
    var onRename: ((_ id: AnyHashable, _ newName: String) -> Void)?
    var onDelete: ((_ id: AnyHashable) -> Void)?
    var onDuplicate: ((_ id: AnyHashable) -> Void)?
    var onMove: ((_ id: AnyHashable, _ newParentId: AnyHashable, _ index: Int) -> Void)?
    var surfaceActions: (() -> [Item])?
    var surfaceDropTarget: (() -> ItemParams?)?
    var itemActions: ((_ item: ItemParams) -> [Item])?
    var wrapLink: ((_ view: AnyView, _ item: ItemParams, _ depth: Int) -> AnyView)?
    var wrapSection: ((_ view: AnyView, _ item: ItemParams, _ depth: Int) -> AnyView)?
    var wrapHeader: ((_ view: AnyView, _ section: ComponentParams) -> AnyView)?
    var itemLeadingAccessory: ((_ item: ItemParams, _ depth: Int) -> AnyView?)?
    var sectionLeadingAccessory: ((_ item: ItemParams, _ depth: Int) -> AnyView?)?
    var itemAccessory: ((_ item: ItemParams, _ depth: Int) -> AnyView?)?
    var sectionAccessory: ((_ item: ItemParams, _ depth: Int) -> AnyView?)?
    var addableSections: Set<AnyHashable>?
    var isItemEditable: ((_ item: ItemParams) -> Bool)?
    var canAddChild: ((_ item: ItemParams) -> Bool)?
    var isItemRenameable: ((_ item: ItemParams) -> Bool)?
    var isItemDeleteable: ((_ item: ItemParams) -> Bool)?
    var isItemDuplicateable: ((_ item: ItemParams) -> Bool)?
    var canDrag: ((_ item: ItemParams) -> Bool)?
    var dropTypes: ((_ item: ItemParams) -> [UTType])?
    var onDrop: ((_ providers: [NSItemProvider], _ target: ItemParams) -> Bool)?
    var onCanvasPosition: ((_ item: ItemParams, _ position: CGPoint) -> Void)?

    init(
        onToggle: ((ItemParams) -> Void)? = nil,
        onChange: ((_ item: ItemParams, _ selection: ItemParams) -> Void)? = nil,
        onValueChange: ((_ item: ItemParams, _ value: String) -> Void)? = nil,
        focused: ((_ item: ItemParams) -> Bool)? = nil,
        selected: ((_ item: ItemParams) -> Bool)? = nil,
        onSelect: ((_ item: ItemParams) -> Void)? = nil,
        onOpen: ((_ item: ItemParams) -> Void)? = nil,
        onAction: ((_ item: ItemParams) -> Void)? = nil,
        onAddItem: ((_ parentId: AnyHashable, _ name: String) -> Void)? = nil,
        onAddSection: ((_ name: String) -> Void)? = nil,
        onRename: ((_ id: AnyHashable, _ newName: String) -> Void)? = nil,
        onDelete: ((_ id: AnyHashable) -> Void)? = nil,
        onDuplicate: ((_ id: AnyHashable) -> Void)? = nil,
        onMove: ((_ id: AnyHashable, _ newParentId: AnyHashable, _ index: Int) -> Void)? = nil,
        surfaceActions: (() -> [Item])? = nil,
        surfaceDropTarget: (() -> ItemParams?)? = nil,
        itemActions: ((_ item: ItemParams) -> [Item])? = nil,
        wrapLink: ((_ view: AnyView, _ item: ItemParams, _ depth: Int) -> AnyView)? = nil,
        wrapSection: ((_ view: AnyView, _ item: ItemParams, _ depth: Int) -> AnyView)? = nil,
        wrapHeader: ((_ view: AnyView, _ section: ComponentParams) -> AnyView)? = nil,
        itemLeadingAccessory: ((_ item: ItemParams, _ depth: Int) -> AnyView?)? = nil,
        sectionLeadingAccessory: ((_ item: ItemParams, _ depth: Int) -> AnyView?)? = nil,
        itemAccessory: ((_ item: ItemParams, _ depth: Int) -> AnyView?)? = nil,
        sectionAccessory: ((_ item: ItemParams, _ depth: Int) -> AnyView?)? = nil,
        addableSections: Set<AnyHashable>? = nil,
        isItemEditable: ((_ item: ItemParams) -> Bool)? = nil,
        canAddChild: ((_ item: ItemParams) -> Bool)? = nil,
        isItemRenameable: ((_ item: ItemParams) -> Bool)? = nil,
        isItemDeleteable: ((_ item: ItemParams) -> Bool)? = nil,
        isItemDuplicateable: ((_ item: ItemParams) -> Bool)? = nil,
        canDrag: ((_ item: ItemParams) -> Bool)? = nil,
        dropTypes: ((_ item: ItemParams) -> [UTType])? = nil,
        onDrop: ((_ providers: [NSItemProvider], _ target: ItemParams) -> Bool)? = nil,
        onCanvasPosition: ((_ item: ItemParams, _ position: CGPoint) -> Void)? = nil
    ) {
        self.onToggle = onToggle
        self.onChange = onChange
        self.onValueChange = onValueChange
        self.focused = focused
        self.selected = selected
        self.onSelect = onSelect
        self.onOpen = onOpen
        self.onAction = onAction
        self.onAddItem = onAddItem
        self.onAddSection = onAddSection
        self.onRename = onRename
        self.onDelete = onDelete
        self.onDuplicate = onDuplicate
        self.onMove = onMove
        self.surfaceActions = surfaceActions
        self.surfaceDropTarget = surfaceDropTarget
        self.itemActions = itemActions
        self.wrapLink = wrapLink
        self.wrapSection = wrapSection
        self.wrapHeader = wrapHeader
        self.itemLeadingAccessory = itemLeadingAccessory
        self.sectionLeadingAccessory = sectionLeadingAccessory
        self.itemAccessory = itemAccessory
        self.sectionAccessory = sectionAccessory
        self.addableSections = addableSections
        self.isItemEditable = isItemEditable
        self.canAddChild = canAddChild
        self.isItemRenameable = isItemRenameable
        self.isItemDeleteable = isItemDeleteable
        self.isItemDuplicateable = isItemDuplicateable
        self.canDrag = canDrag
        self.dropTypes = dropTypes
        self.onDrop = onDrop
        self.onCanvasPosition = onCanvasPosition
    }

    var isEditable: Bool {
        onAddItem != nil || onAddSection != nil || onRename != nil ||
        onDelete != nil || onDuplicate != nil || onMove != nil ||
        surfaceActions != nil || itemActions != nil
    }

    func canEdit(_ item: ItemParams) -> Bool {
        isItemEditable?(item) ?? true
    }

    func canAddChild(for item: ItemParams) -> Bool {
        guard onAddItem != nil else { return false }
        return canAddChild?(item) ?? item.isParent
    }

    func canRename(_ item: ItemParams) -> Bool {
        guard onRename != nil else { return false }
        return isItemRenameable?(item) ?? true
    }

    func canDelete(_ item: ItemParams) -> Bool {
        guard onDelete != nil else { return false }
        return isItemDeleteable?(item) ?? true
    }

    func canDuplicate(_ item: ItemParams) -> Bool {
        guard onDuplicate != nil else { return false }
        return isItemDuplicateable?(item) ?? true
    }

    func canAddInline(sectionId: AnyHashable) -> Bool {
        guard onAddItem != nil else { return false }
        guard let allowed = addableSections else { return true }
        return allowed.contains(sectionId)
    }
}
