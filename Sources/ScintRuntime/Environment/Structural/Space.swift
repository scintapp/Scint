import Foundation
import OrderedCollections


struct Space: Structural {
    let ref: Reference
    var space: Reference?
    var spaces: Set<Reference> = []
    var bridges: Set<Reference> = []
    var closure: Reference
    var harness: Reference?

    init(_ ref: Reference = .init(Self.self)) {
        self.ref = ref
        self.closure = ref
    }

    var composable: Bool { harness != nil }

    func configure(_ value: Value?, for key: String) {
        Closure.update(closure) { $0.config[key] = value }
    }

    func add(_ ref: Reference) {
        switch ref.type {
            case is Space.Type:
                Space.update(ref) { $0.attach(to: self.ref) }
            case is any Functional.Type:
                Closure.update(closure) { $0.interfaces.update(with: ref) }
            case is any Malleable.Type:
                Closure.update(closure) {
                    $0.content.append(ref)
                    switch ref.type {
                        case is Material.Type: Material.update(ref) { mat in mat.origin = self.ref }
                        case is Transcript.Type: Transcript.update(ref) { mat in mat.origin = self.ref }
                        default: break
                    }
                }
            default: break
        }
    }

    func remove(_ ref: Reference) {
        switch ref.type {
            case is any Functional.Type: Closure.update(closure) { $0.interfaces.remove(ref) }
            case is any Malleable.Type: Closure.update(closure) { $0.content.removeAll { $0 == ref } }
            default: break
        }
    }

    mutating func attach(to parent: Reference) {
        guard parent != ref else { return }
        if let previous = space, previous != parent, previous.type is Space.Type {
            Space.update(previous) { $0.spaces.remove(ref) }
        }

        guard parent.type is Space.Type else { return }
        self.space = parent
        Space.update(parent) { $0.spaces.update(with: ref) }
    }

    mutating func detach(from parent: Reference) {
        if parent.type is Space.Type { Space.update(parent) { $0.spaces.remove(ref) } }
        if space == parent { space = nil }
    }

    mutating func attach(child: Reference) {
        guard child != ref, child.type is Space.Type else { return }
        spaces.update(with: child)
        Space.update(child) { $0.attach(to: ref) }
    }

    mutating func detach(child: Reference) {
        guard child.type is Space.Type else { return }
        spaces.remove(child)
        Space.update(child) { $0.detach(from: ref) }
    }

    func restructure() -> Reference {
        if let parent = space, parent.type is Space.Type {
            Space.update(parent) {
                $0.spaces.remove(ref)
                $0.spaces.formUnion(spaces)
            }
        }
        for child in spaces { Space.update(child) { $0.space = self.space } }
        return self.ref
    }

    @discardableResult
    static func new(_ name: String) -> Reference {
        var instance = Space(.init(Self.self))
        Descriptor.new(instance.ref, name: name, tags: ["space"])
        instance.closure = Closure.new("Closure", origin: instance.ref)
        Workspaces.shared.add(instance.ref, instance)
        return instance.ref
    }

    static func new(_ origin: Reference, name: String = "New Space") -> Reference {
        guard origin.type == Space.self else { RuntimeError.fatal("Not a valid space.") }
        var instance = Space(.init(Self.self))
        Descriptor.new(instance.ref, name: name, tags: ["space"])
        instance.closure = Closure.new("Closure", origin: instance.ref)
        Workspaces.shared.add(instance.ref, instance)
        Space.update(instance.ref) { $0.attach(to: origin) }
        return instance.ref
    }
}
