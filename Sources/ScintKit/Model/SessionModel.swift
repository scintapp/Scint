import Foundation


@MainActor struct Session: Codable, Sendable {
    private(set) var focus: Focus = .nothing
    private(set) var selection: Selection = .init()
    private(set) var opened: Opened = .init()
    private(set) var navigation: Navigation = .init()
    private(set) var workspace: Reference

    init(_ workspace: Reference) {
        self.workspace = workspace
        self.selection = Selection(structure: workspace)
        self.navigation.reset(to: selection)
    }

    var origin: Reference { if let ref = selection.structure, ref.type is Space.Type { ref } else { workspace } }

    mutating func load(_ workspace: Reference) {
        self.workspace = workspace
        opened = .init()
        focus = .nothing
        let initial = Selection(structure: workspace)
        selection = initial
        navigation.reset(to: initial)
    }

    mutating func focus(_ ref: Reference?) {
        guard let ref else { focus = .nothing; return }
        switch ref.type {
            case is Space.Type: focus = .structure(ref)
            case is any Functional.Type: focus = .interface(ref)
            case is any Malleable.Type: focus = .content(ref)
            default: focus = .nothing
        }
    }

    mutating func select(_ ref: Reference, entry: UUID? = nil, url: URL? = nil) {
        if opened.material != nil  && opened.material != ref { close(opened.material!) }
        apply(selection.selecting(ref, entry,  url))
    }

    mutating func open(_ ref: Reference) {
        select(ref)
        opened.open(ref)
    }

    mutating func close(_ ref: Reference) {
        opened.close(ref)
        if selection.content == ref { selection = selection.clearing(.content) }
        if focus == .content(ref) { focus = .nothing }
    }

    @discardableResult
    mutating func forward() -> Selection? {
        guard let target = navigation.forward() else { return nil }
        apply(target, push: false)
        if let content = selection.content { opened.open(content) }
        return target
    }

    @discardableResult
    mutating func back() -> Selection? {
        if opened.material != nil { close(opened.material!) }
        guard let target = navigation.back() else { return nil }
        apply(target, push: false)
        if let content = selection.content { opened.open(content) }
        return target
    }

    @discardableResult
    mutating func apply(_ next: Selection, push: Bool = true) -> Bool {
        guard next != selection else { return false }
        selection = next
        if push { navigation.push(next) }
        return true
    }
}

extension Session {
    var input: Reference? {
        Space.with(origin, { $0.input }).flatMap { $0 }
    }

    var transcript: Reference? {
        if case .content(let ref) = focus, ref.type is Transcript.Type { return ref }
        return transcripts.first
    }

    var transcripts: [Reference] {
        let roots = Space.with(origin, { $0.transcripts }) ?? []
        return roots.sorted { $0.descriptor.created > $1.descriptor.created }
    }

    var material: Reference? {
        guard let content = selection.content else { return nil }
        guard content.type is Material.Type else { return nil }
        return content
    }

    var materials: [Reference] {
        let roots = Space.with(origin, { $0.materials }) ?? []
        return roots.sorted { $0.descriptor.created > $1.descriptor.created }
    }

    var rendered: Value {
        Value.collection([
            "focused": focus.resolved,
            "selected": selection.resolved,
            "opened": opened.resolved
        ])
    }
}
