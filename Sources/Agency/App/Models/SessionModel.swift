import AgencyRuntime
import Foundation


@Observable final class SessionModel {
    private(set) var focused: Focus = .nothing
    private(set) var selected: Selection = .init()
    private(set) var opened: Open = .init()
    private(set) var navigation: Navigation = .init()
    private(set) var workspace: Reference

    init(_ workspace: Reference) {
        self.workspace = workspace
        let initial = Selection(structure: workspace)
        self.selected = initial
        self.navigation.reset(to: initial)
    }

    var active: Reference? {
        guard let content = selected.content else { return nil }
        switch content.type {
            case is Sheet.Type: return opened.sheets.contains(content) ? content : nil
            case is Transcript.Type: return opened.transcripts.contains(content) ? content : nil
            default: return nil
        }
    }

    var space: Reference? {
        guard let structure = selected.structure, structure.type is Space.Type else { return nil }
        return selected.structure
    }

    func load(_ workspace: Reference) {
        self.workspace = workspace
        opened = .init()
        focused = .nothing
        let initial = Selection(structure: workspace)
        selected = initial
        navigation.reset(to: initial)
    }

    func focus(_ ref: Reference?) {
        guard let ref else {
            focused = .nothing
            return
        }
        switch ref.type {
            case is Workspace.Type, is Space.Type: focused = .structure(ref)
            case is any Functional.Type: focused = .interface(ref)
            case is any Malleable.Type: focused = .content(ref)
            default: focused = .nothing
        }
    }

    @discardableResult
    func select(_ ref: Reference) -> Bool {
        return apply(selected.selecting(ref))
    }

    @discardableResult
    func select(_ ref: Reference, entry: UUID?, url: URL?) -> Bool {
        return apply(selected.selecting(ref, entry: entry, url: url))
    }

    @discardableResult
    func open(_ ref: Reference) -> Bool {
        return opened.open(ref)
    }

    @discardableResult
    func close(_ ref: Reference) -> Bool {
        return opened.close(ref)
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
        guard let content = selected.content else { return }
        opened.open(content)
    }

}
