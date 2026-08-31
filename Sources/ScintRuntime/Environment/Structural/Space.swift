import Foundation
import OrderedCollections


struct Space: Structural {
    let ref: Reference
    var space: Reference? = nil
    var spaces: Set<Reference> = []
    var bridges: Set<Reference> = []
    var harness: Reference? = nil
    var closure: Reference

    init(_ ref: Reference = .init(Self.self)) {
        self.ref = ref
        self.closure = ref
    }

    var composable: Bool { harness != nil }
    var composition: Composition? { Composer.shared.resolve(ref) }
    var artifacts: [Reference] { Closure.with(closure, { $0 })?.artifacts ?? [] }
    var commands: [Reference] { Closure.with(closure, { $0 })?.commands ?? [] }
    var harnesses: [Reference] { Closure.with(closure, { $0 })?.harnesses ?? [] }
    var materials: [Reference] { Closure.with(closure, { $0 })?.materials ?? [] }
    var transcripts: [Reference] { Closure.with(closure, { $0 })?.transcripts ?? [] }
    var directories: [Reference] { Closure.with(closure, { $0 })?.directories ?? [] }
    var config: Config { Closure.with(closure, { $0.config }) ?? [:] }
    var components: [Reference] { artifacts + commands + harnesses + materials + transcripts }
    var rendered: String { Closure.with(closure, { $0.rendered }) ?? "" }

    var input: Reference? {
        get { Closure.with(closure, { $0.input }) }
        set {
            guard let input = newValue else { return }
            Closure.update(closure) {
                $0.content.removeAll { $0 == input }
                $0.content.insert(input, at: 0)
                $0.input = Material.new(ref, input: true)
            }
        }
    }

    func configure(_ value: Value?, for key: String) { Closure.update(closure) { $0.config[key] = value } }

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

    mutating func attach(to parent: Reference) {
        guard parent != ref else { return }
        if let previous = space, previous != parent {
            if previous.type is Space.Type { Space.update(previous) { $0.spaces.remove(ref) } }
            else if previous.type is Workspace.Type { Workspace.update(previous) { $0.spaces.remove(ref) } }
        }

        guard parent.type is Space.Type || parent.type is Workspace.Type else { return }
        self.space = parent
        if parent.type is Space.Type { Space.update(parent) { $0.spaces.update(with: ref) } }
        else { Workspace.update(parent) { $0.spaces.update(with: ref) } }
    }

    mutating func detach(from parent: Reference) {
        if parent.type is Space.Type { Space.update(parent) { $0.spaces.remove(ref) } }
        else if parent.type is Workspace.Type { Workspace.update(parent) { $0.spaces.remove(ref) } }
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
        if let parent = space {
            if parent.type is Space.Type {
                Space.update(parent) {
                    $0.spaces.remove(ref)
                    $0.spaces.formUnion(spaces)
                }
            } else if parent.type is Workspace.Type {
                Workspace.update(parent) {
                    $0.spaces.remove(ref)
                    $0.spaces.formUnion(spaces)
                }
            }
        }
        for child in spaces { Space.update(child) { $0.space = space } }
        return self.ref
    }

    static func new(_ owner: Reference, name: String = "New Space") -> Reference {
        guard owner.type == Space.self || owner.type == Workspace.self else { RuntimeError.fatal() }
        var instance = Space(.init(Self.self))
        Descriptor.new(instance.ref, name: name, tags: ["space"])
        instance.closure = Closure.new("Closure", owner: instance.ref)
        Workspaces.shared.add(instance.ref, instance)
        Space.update(instance.ref) { $0.attach(to: owner) }
        return instance.ref
    }
}
