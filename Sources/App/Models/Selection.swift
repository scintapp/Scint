import AgencyRuntime
import Foundation


struct Selection: Equatable, Sendable {
    var structure: Reference?
    var interface: Reference?
    var content: Reference?
    var entry: UUID?
    var url: URL?

    enum Axis: Sendable { case structure, interface, content, entry, path }

    var workspace: Reference? {
        guard let structure, structure.type is Workspace.Type else { return nil }
        return structure
    }

    var space: Reference? {
        guard let structure, structure.type is Space.Type else { return nil }
        return structure
    }

    func selected(_ ref: Reference) -> Bool {
        switch ref.type {
            case is Workspace.Type, is Space.Type: return structure == ref
            case is any Functional.Type: return interface == ref && entry == nil && url == nil
            case is any Malleable.Type: return content == ref && entry == nil && url == nil
            default: return false
        }
    }

    func selected(_ ref: Reference, _ entry: UUID?) -> Bool {
        guard let entry else { return selected(ref) }
        return content == ref && self.entry == entry
    }

    func selected(_ ref: Reference, _ url: URL?) -> Bool {
        guard let url else { return selected(ref) }
        return (content == ref || interface == ref) && self.url == url
    }

    func selecting(_ ref: Reference, entry: UUID? = nil, url: URL? = nil) -> Self {
        var next = self
        switch ref.type {
            case is Workspace.Type, is Space.Type:
                next.structure = ref
                next.interface = nil
                next.content = nil
                next.entry = entry
                next.url = url
            case is any Functional.Type:
                next.interface = ref
                next.entry = entry
                next.url = url
            case is any Malleable.Type:
                next.content = ref
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
            case .content:
                next.content = nil
                next.entry = nil
                next.url = nil
            case .interface:
                next.interface = nil
                next.url = nil
            case .structure:
                next.interface = nil
                next.content = nil
                next.entry = nil
                next.url = nil
        }
        return next
    }
}
