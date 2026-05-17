import AgencyRuntime
import Foundation


struct Selection: Equatable, Sendable {
    var space: Reference
    var boundary: Reference?
    var component: Reference?
    var entry: UUID?
    var url: URL?

    init(space: Reference) { self.space = space }

    enum Axis: Sendable { case boundary, component, entry, url }

    func selected(_ ref: Reference) -> Bool {
        switch ref.type {
        case is Space.Type: return space == ref
        case is Boundary.Type:  return boundary == ref
        case is any Composable.Type, is any Interfacing.Type:
            return component == ref && entry == nil && url == nil
        default: return false
        }
    }

    func selected(_ ref: Reference, _ entry: UUID?) -> Bool {
        guard let entry else { return selected(ref) }
        return component == ref && self.entry == entry
    }

    func selected(_ ref: Reference, _ url: URL?) -> Bool {
        guard let url else { return selected(ref) }
        return component == ref && self.url == url
    }

    func selecting(_ ref: Reference, from origin: Reference? = nil, entry: UUID? = nil, url: URL? = nil) -> Self {
        var next = self

        switch ref.type {
        case is Space.Type:
            next.space = ref
            next.boundary = nil
            next.component = nil
            next.entry = nil
            next.url = nil

        case is Boundary.Type:
            next.boundary = ref
            next.component = nil
            next.entry = nil
            next.url = nil

        case is any Composable.Type, is any Interfacing.Type:
            if let origin, origin != next.boundary {
                next.boundary = origin
            }
            next.component = ref
            next.entry = entry
            next.url = url

        default:
            break
        }

        return next
    }

    func clearing(_ axis: Axis) -> Self {
        var next = self
        switch axis {
        case .boundary:
            next.boundary = nil
            next.component = nil
            next.entry = nil
            next.url = nil

        case .component:
            next.component = nil
            next.entry = nil
            next.url = nil

        case .entry:
            next.entry = nil

        case .url:
            next.url = nil
        }
        return next
    }
}
