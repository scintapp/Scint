import Foundation


struct Bridge: Structural {
    var ref: Reference
    var origin: Reference
    var target: Reference
    var closure: Reference

    init(_ ref: Reference = .init(Self.self)) {
        self.ref = ref
        self.origin = ref
        self.target = ref
        self.closure = ref
    }
    
    mutating func bridge(_ origin: Reference, to target: Reference) {
        Space.update(self.origin, { $0.bridges.remove(self.ref) })
        Space.update(self.target, { $0.bridges.remove(self.ref) })
        self.origin = origin
        self.target = target
        Space.update(origin, { $0.bridges.update(with: self.ref) })
        Space.update(target, { $0.bridges.update(with: self.ref) })
    }

    func add(_ ref: Reference) {
        switch ref.type {
            case is any Functional.Type: Closure.update(closure) { $0.interfaces.update(with: ref) }
            case is any Malleable.Type: Closure.update(closure) { if !$0.content.contains(ref) { $0.content.append(ref) } }
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

    @discardableResult
    static func new(_ name: String, origin: Reference, to target: Reference) -> Reference {
        guard origin.type is Space.Type, target.type is Space.Type else { RuntimeError.fatal("Invalid spaces.") }
        var instance = Bridge(.init(Self.self))
        instance.bridge(origin, to: target)
        Descriptor.new(instance.ref, name: name, tags: ["branch"], published: true)
        Workspaces.shared.add(instance.ref, instance)
        return instance.ref
    }
}
