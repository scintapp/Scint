import Foundation


@MainActor struct Session: Codable, Sendable {
    private(set) var focus: Focus = .nothing
    private(set) var selection: Selection = .init()
    private(set) var opened: Opened = .init()
    private(set) var navigation: Navigation = .init()
    private(set) var spaces: [Reference]

    init(_ spaces: [Reference]) {
        self.spaces = spaces
        opened = .init()
        focus = .nothing
        let initial = Selection()
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
    mutating func back() -> Selection? {
        if opened.material != nil { close(opened.material!) }
        guard let target = navigation.back() else { return nil }
        apply(target, push: false)
        if let content = selection.content { opened.open(content) }
        return target
    }

    @discardableResult
    mutating func forward() -> Selection? {
        guard let target = navigation.forward() else { return nil }
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
    var space: Reference? {
        guard let ref = selection.structure, Space.with(ref, { $0 }) != nil else { return nil }
        return ref
    }

    var scope: Reference? {
        guard space != nil, let ref = navigation.path(for: selection).first else { return nil }
        return ref
    }

    var bridged: [Reference] {
        guard let ref = scope, let refs = Space.with(ref, { $0 })?.bridges else { return [] }
        var bridges =  Array(refs)
        bridges.insert(ref, at: 0)
        return bridges
    }

    var input: Reference? {
        guard let structure = selection.structure else { return nil }
        return Space.with(structure, { $0.input }).flatMap { $0 }
    }

    var transcript: Reference? {
        if case .content(let ref) = focus, ref.type is Transcript.Type { return ref }
        return transcripts.first
    }

    var transcripts: [Reference] {
        guard let structure = selection.structure else { return [] }
        let roots = Space.with(structure, { $0.transcripts }) ?? []
        return roots.sorted { $0.descriptor.created > $1.descriptor.created }
    }

    var material: Reference? {
        guard let content = selection.content else { return nil }
        guard content.type is Material.Type else { return nil }
        return content
    }

    var materials: [Reference] {
        guard let structure = selection.structure else { return [] }
        let roots = Space.with(structure, { $0.materials }) ?? []
        return roots.sorted { $0.descriptor.created > $1.descriptor.created }
    }

    var rendered: Value {
        Value.collection([
            "focused": focus.resolved,
            "selected": selection.resolved
        ])
    }
}
