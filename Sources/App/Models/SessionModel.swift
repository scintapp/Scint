import AgencyRuntime
import Foundation


@Observable final class SessionModel {
    private(set) var opened: Open = .init()
    private(set) var focused: Focus = .nothing
    private(set) var selected: Selection = .init()
    private(set) var navigation: Navigation = .init()
    private(set) var workspace: Reference

    var focusedSpace: Reference? {
        guard case .structure(let ref) = focused, ref.type is Space.Type else { return nil }
        return ref
    }

    var inspectingSpace: Reference {
        focusedSpace ?? selected.space ?? workspace
    }

    init(_ workspace: Reference) {
        self.workspace = workspace
        let initial = Selection(structure: workspace)
        self.selected = initial
        self.navigation.reset(to: initial)
    }

    func load(_ workspace: Reference) {
        self.workspace = workspace
        opened = .init()
        focused = .nothing
        let initial = Selection(structure: workspace)
        selected = initial
        navigation.reset(to: initial)
    }

    func focus(_ ref: Reference) {
        switch ref.type {
            case is Workspace.Type, is Space.Type: focused = .structure(ref)
            case is any Functional.Type: focused = .interface(ref)
            case is any Malleable.Type: focused = .content(ref)
            default: focused = .nothing
        }
    }

    func isFocused(_ ref: Reference) -> Bool {
        switch focused {
            case .structure(let focused), .interface(let focused), .content(let focused): return focused == ref
            default: return false
        }
    }

    func clearFocus() {
        focused = .nothing
    }

    @discardableResult
    func select(_ ref: Reference) -> Bool {
        focused = .nothing
        return apply(selected.selecting(ref))
    }

    @discardableResult
    func select(_ ref: Reference, entry: UUID?, url: URL?) -> Bool {
        focused = .nothing
        return apply(selected.selecting(ref, entry: entry, url: url))
    }

    @discardableResult
    func open(_ ref: Reference) -> Bool {
        focused = .nothing
        if ref.type is Workspace.Type {
            workspace = ref
            opened = .init()
            return true
        }
        if ref.type is Space.Type { return true }
        return opened.open(ref)
    }

    @discardableResult
    func close(_ ref: Reference) -> Bool {
        opened.close(ref)
    }

    @discardableResult
    func back() -> Selection? {
        guard let target = navigation.back() else { return nil }
        apply(target, push: false)
        restore(target)
        return target
    }

    @discardableResult
    func forward() -> Selection? {
        guard let target = navigation.forward() else { return nil }
        apply(target, push: false)
        restore(target)
        return target
    }

    @discardableResult
    func apply(_ next: Selection, push: Bool = true) -> Bool {
        guard next != selected else { return false }
        selected = next
        if push { navigation.push(next) }
        return true
    }

    private func restore(_ selected: Selection) {
        opened = .init()
        guard let content = selected.content else { return }
        opened.open(content)
    }
}
