import Foundation


@MainActor struct Session: Codable, Sendable {
    private(set) var focused: Focus = .nothing
    private(set) var selected: Selection = .init()
    private(set) var opened: Open = .init()
    private(set) var navigation: Navigation = .init()
    private(set) var workspace: Reference

    init(_ workspace: Reference) {
        self.workspace = workspace
        self.selected = Selection(space: workspace)
        self.navigation.reset(to: selected)
    }

    mutating func load(_ workspace: Reference) {
        self.workspace = workspace
        opened = .init()
        focused = .nothing
        let initial = Selection(space: workspace)
        selected = initial
        navigation.reset(to: initial)
    }

    mutating func focus(_ ref: Reference?) {
        guard let ref else { focused = .nothing; return }
        switch ref.type {
            case is Workspace.Type, is Space.Type: focused = .space(ref)
            case is any Functional.Type: focused = .interface(ref)
            case is any Malleable.Type: focused = .content(ref)
            default: focused = .nothing
        }
    }

    @discardableResult
    mutating func select(_ ref: Reference) -> Bool {
        apply(selected.selecting(ref))
    }

    @discardableResult
    mutating func select(_ ref: Reference, entry: UUID?, url: URL?) -> Bool {
        return apply(selected.selecting(ref, entry: entry, url: url))
    }

    @discardableResult
    mutating func open(_ ref: Reference) -> Bool {
        return opened.open(ref)
    }

    @discardableResult
    mutating func close(_ ref: Reference) -> Bool {
        guard opened.close(ref) else { return false }
        if selected.content == ref { selected = selected.clearing(.content) }
        if focused == .content(ref) { focused = .nothing }
        return true
    }

    @discardableResult
    mutating func forward() -> Selection? {
        guard let target = navigation.forward() else { return nil }
        apply(target, push: false)
        if let content = selected.content { opened.open(content) }
        return target
    }

    @discardableResult
    mutating func back() -> Selection? {
        guard let target = navigation.back() else { return nil }
        apply(target, push: false)
        if let content = selected.content { opened.open(content) }
        return target
    }

    @discardableResult
    mutating func apply(_ next: Selection, push: Bool = true) -> Bool {
        guard next != selected else { return false }
        selected = next
        if push { navigation.push(next) }
        return true
    }
}

extension Session {
    var origin: Reference {
        guard let ref = selected.space, ref.type is Space.Type else { return workspace }
        return ref
    }

    var input: Reference? {
        if origin.type == Space.self { Space.with(origin, { $0.input }).flatMap { $0 } }
        else { Workspace.with(origin, { $0.input }).flatMap { $0 } }
    }

    var transcript: Reference? {
        if case .content(let ref) = focused, ref.type is Transcript.Type { return ref }
        return transcripts.first
    }

    var transcripts: [Reference] {
        let roots = if origin.type == Space.self { Space.with(origin, { $0.transcripts }) ?? [] }
        else { Workspace.with(origin, { $0.transcripts }) ?? [] }
        return roots.sorted { $0.descriptor.created > $1.descriptor.created }
    }

    var material: Reference? {
        guard let content = selected.content else { return nil }
        guard content.type is Material.Type, opened.materials.contains(content) else { return nil }
        return content
    }

    var materials: [Reference] {
        let roots = if origin.type == Space.self { Space.with(origin, { $0.materials }) ?? [] }
        else { Workspace.with(origin, { $0.materials }) ?? [] }
        return roots.sorted { $0.descriptor.created > $1.descriptor.created }
    }

    var rendered: Value {
        Value.collection([
            "focused": focused.resolved,
            "selected": selected.resolved,
            "opened": opened.resolved
        ])
    }
}
