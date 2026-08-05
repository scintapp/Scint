import Foundation


public struct Route: Structural {
    public var ref: Reference
    public var origin: Reference? = nil
    public var target: Reference? = nil

    public init(_ ref: Reference = .init(Self.self)) { self.ref = ref }

    public func update(origin ref: Reference) -> Self {
        var route = self
        if let current = route.origin, current != origin { Space.update(ref) { space in space.routes.remove(route.ref) } }
        route.origin = origin
        Space.update(ref) { space in space.routes.insert(route.ref) }
        return route
    }

    public func update(target ref: Reference) -> Self {
        var route = self
        if let current = route.target, current != target { Space.update(ref) { space in space.routes.remove(route.ref) } }
        route.target = target
        Space.update(ref) { space in space.routes.insert(route.ref) }
        return route
    }
}
