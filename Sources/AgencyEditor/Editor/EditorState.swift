import AppKit
import AgencyRuntime
import Foundation
import SwiftUI


@Observable final class EditorState {
    private(set) var sheet: SheetModel
    private(set) var menu: MenuModel
    let themer = EditorThemer()
    private(set) var themeRevision = 0

    init(sheet ref: Reference, menu: MenuModel) {
        self.sheet = SheetModel(ref)
        self.menu = menu
    }

    func setSheet(_ ref: Reference) {
        if menu.isOpen { menu.close() }
        sheet = SheetModel(ref)
    }

    func setMenu(_ menu: MenuModel) {
        self.menu.close()
        self.menu = menu
    }

    func setTheme(_ theme: Theme) {
        themer.theme = theme
        themeRevision &+= 1
    }

    func focusGained(id: UUID) {
        sheet.focusGained(id: id)
    }

    func setCaret(id: UUID, selection: NSRange) {
        guard sheet.setCaret(id: id, selection: selection) || menu.isOpen else { return }
        updateMenu(allowOpen: false)
    }

    func write(id: UUID, text: String, selection: NSRange) {
        let didChangeText = sheet.write(id: id, text: text, selection: selection)
        if didChangeText || menu.isOpen { updateMenu(allowOpen: didChangeText) }
    }

    func commitMenuSelection() {
        guard let commit = menu.commitSelection() else { return }
        sheet.insert(commit.entries, replacing: commit.replacementRange)
    }

    func handleCommand(_ selector: Selector, atTopLine: Bool, atBottomLine: Bool) -> Bool {
        if menu.isOpen {
            let result = menu.handleCommand(selector)
            if let commit = result.commit { sheet.insert(commit.entries, replacing: commit.replacementRange) }
            return result.handled
        }

        return sheet.handleCommand(selector, atTopLine: atTopLine, atBottomLine: atBottomLine)
    }

    @discardableResult
    func beginEditingFromCanvasClick(at point: CGPoint) -> Bool {
        if menu.isOpen { menu.close() }
        return sheet.beginEditingFromCanvasClick(at: point)
    }

    private func updateMenu(allowOpen: Bool) {
        guard allowOpen || menu.isOpen else { return }
        guard let trigger = sheet.menuTrigger() else {
            if menu.isOpen { menu.close() }
            return
        }
        menu.open(
            kind: trigger.kind.menuKind,
            query: trigger.query,
            replacementRange: trigger.range,
            anchorRect: trigger.anchorRect
        )
    }
}

private extension SheetTrigger.Kind {
    var menuKind: MenuKind {
        switch self {
        case .command: return .command
        case .reference: return .reference
        }
    }
}
