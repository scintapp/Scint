import AgencyRuntime
import Foundation
import SwiftUI


struct Focus: Equatable, Sendable {
    var ref: Reference
    var origin: Reference?
    var entry: UUID?
    var url: URL?

    static func focusing(_ ref: Reference, from origin: Reference? = nil, entry: UUID? = nil, url: URL? = nil) -> Self {
        .init(ref: ref, origin: origin, entry: entry, url: url)
    }

    func focused(_ ref: Reference) -> Bool {
        self.ref == ref && entry == nil && url == nil
    }

    func focused(_ ref: Reference, _ entry: UUID?) -> Bool {
        guard let entry else { return focused(ref) }
        return self.ref == ref && self.entry == entry
    }

    func focused(_ ref: Reference, _ url: URL?) -> Bool {
        guard let url else { return focused(ref) }
        return self.ref == ref && self.url == url
    }

    func focused(_ ref: Reference, entry: UUID?, url: URL?) -> Bool {
        if let url { return focused(ref, url) }
        if let entry { return focused(ref, entry) }
        return focused(ref)
    }
}

struct Open: Equatable, Sendable {
    var sheet: Reference
    var origin: Reference?
    var entry: UUID?

    static func opening(_ sheet: Reference, from origin: Reference? = nil, entry: UUID? = nil) -> Self {
        .init(sheet: sheet, origin: origin, entry: entry)
    }
}

struct Selection: Equatable, Sendable {
    var workspace: Reference
    var space: Reference?
    var component: Reference?
    var entry: UUID?
    var url: URL?

    init(space: Reference) { self.workspace = space }

    enum Axis: Sendable { case space, component, entry, path }

    func selected(_ ref: Reference) -> Bool {
        switch ref.type {
        case is Workspace.Type: return workspace == ref
        case is Space.Type:  return space == ref
        case is Sheet.Type: return false
        case is any Malleable.Type, is any Functional.Type:
            return component == ref && entry == nil && url == nil
        default: return false
        }
    }

    func selected(_ ref: Reference, _ entry: UUID?) -> Bool {
        guard !(ref.type is Sheet.Type) else { return false }
        guard let entry else { return selected(ref) }
        return component == ref && self.entry == entry
    }

    func selected(_ ref: Reference, _ url: URL?) -> Bool {
        guard !(ref.type is Sheet.Type) else { return false }
        guard let url else { return selected(ref) }
        return component == ref && self.url == url
    }

    func selecting(_ ref: Reference, from origin: Reference? = nil, entry: UUID? = nil, url: URL? = nil) -> Self {
        var next = self
        switch ref.type {
        case is Workspace.Type:
            next.workspace = ref
            next.space = nil
            next.component = nil
            next.entry = nil
            next.url = nil
        case is Space.Type:
            next.space = ref
            next.component = nil
            next.entry = nil
            next.url = nil
        case is Sheet.Type:
            break
        case is any Malleable.Type, is any Functional.Type:
            if let origin, origin != next.space { next.space = origin }
            next.component = ref
            next.entry = entry
            next.url = url
        default: break
        }
        return next
    }

    func clearing(_ axis: Axis) -> Self {
        var next = self
        switch axis {
        case .path:
            next.url = nil
        case .entry:
            next.entry = nil
        case .component:
            next.component = nil
            next.entry = nil
            next.url = nil
        case .space:
            next.space = nil
            next.component = nil
            next.entry = nil
            next.url = nil
        }
        return next
    }
}
