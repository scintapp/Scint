import Foundation
import ScintRuntime
import ScintComponents


@MainActor struct Session {
    var data: DataModel
    var focus: Focus
    var selection: Selection
    var navigation: Navigation

    var agenda: Reference { data.agenda }
    var library: Reference { data.library }
    var spaces: Reference { data.spaces }
    var opened: Opened { selection.opened }

    init(_ data: DataModel) {
        self.data = data
        focus = .nothing
        selection = .init()
        navigation = .init()
    }


    mutating func focus(_ ref: Reference?) {
        guard let ref else { focus = .nothing; return }
        switch ref.type {
            case is Space.Type: focus = .structure(ref)
            case is any Functional.Type: focus = .interface(ref)
            case is any Material.Type: focus = .content(ref)
            default: focus = .nothing
        }
    }

    mutating func select(_ ref: Reference, entry: UUID? = nil, url: URL? = nil) {
        focus(ref)
        if opened.document != nil  && opened.document != ref { close(opened.document!) }
        apply(selection.selecting(ref, entry,  url))
    }

    mutating func open(_ ref: Reference) {
        focus(ref)
        select(ref)
        selection.opened.open(ref)
    }

    mutating func close(_ ref: Reference) {
        selection.opened.close(ref)
        if selection.content == ref { selection = selection.clearing(.content) }
        if focus == .content(ref) { focus = .nothing }
    }

    @discardableResult
    mutating func back() -> Selection? {
        if opened.document != nil { close(opened.document!) }
        guard let target = navigation.back() else { return nil }
        apply(target, push: false)
        if let content = selection.content { selection.opened.open(content) }
        return target
    }

    @discardableResult
    mutating func forward() -> Selection? {
        guard let target = navigation.forward() else { return nil }
        apply(target, push: false)
        if let content = selection.content { selection.opened.open(content) }
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
    var scope: Reference? {
        guard let ref = navigation.path(for: selection).first else { return nil }
        return ref
    }

    var space: Reference? {
        guard let structure = selection.structure else { return nil }
        return navigation.spaces(to: structure).drop { $0 != spaces }.dropFirst().first
    }

    var bridged: [Reference] {
        guard let ref = scope, let refs = Space.with(ref, { $0 })?.bridges else { return [] }
        var bridges =  Array(refs)
        bridges.insert(ref, at: 0)
        return bridges
    }

    var transcript: Reference? {
        guard let space = selection.structure, let context = space.context else { return nil }
        return context.transcript
    }

    var document: Reference? {
        guard let content = selection.content else { return nil }
        guard content.type is Document.Type else { return nil }
        return content
    }

    var documents: [Reference] {
        let order: [Reference: Int] = [:]
        func position(_ ref: Reference) -> Int { order[ref] ?? .max }

        return Runtime.shared.all(as: Document.self)
            .map { $0.0 }
            .filter { !$0.descriptor.tags.contains("task") }
            .compactMap { ref in
                guard ref.type is ScintRuntime.Document.Type else { return nil }
                return ref
            }.sorted {
                let lhs = position($0)
                let rhs = position($1)
                if lhs != rhs { return lhs < rhs }
                return $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending
            }
    }

    var folder: [Reference] {
        guard let structure = selection.structure else { return [] }
        let roots = Space.with(structure, { $0.documents }) ?? []
        return roots.sorted { $0.descriptor.created > $1.descriptor.created }
    }

    var inspected: Reference? {
        focus.ref
        ?? selection.opened.document
        ?? selection.opened.transcript
        ?? selection.content
        ?? selection.interface
        ?? selection.structure
        ?? selection.root
    }

    var rendered: Value {
        Value.collection([
            "focused": focus.resolved,
            "selected": selection.resolved
        ])
    }
}




