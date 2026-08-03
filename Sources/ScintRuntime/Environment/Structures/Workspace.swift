import Foundation


public struct Workspace: Structural {
    public let ref: Reference
    public var spaces: Set<Reference> = []
    public var harness: Reference
    public var closure: Reference

    public init(_ ref: Reference = .init(Self.self)) {
        self.ref = ref
        self.closure = ref
        self.harness = ref
    }

    public var input: Reference? {
        get { Closure.with(closure, { $0.input }) }
        set {
            guard let input = newValue else { return }
            Closure.update(closure) {
                $0.content.removeAll { $0 == input }
                $0.content.insert(input, at: 0)
                $0.input = Sheet.new(ref, input: true)
            }
        }
    }
    public var composable: Bool { harness.type is Harness.Type }
    public var composition: Composition? { Composer.shared.resolve(ref) }
    public var artifacts: [Reference] { Closure.with(closure, { $0 })?.artifacts ?? [] }
    public var commands: [Reference] { Closure.with(closure, { $0 })?.commands ?? [] }
    public var harnesses: [Reference] { Closure.with(closure, { $0 })?.harnesses ?? [] }
    public var sheets: [Reference] { Closure.with(closure, { $0 })?.sheets ?? [] }
    public var transcripts: [Reference] { Closure.with(closure, { $0 })?.transcripts ?? [] }
    public var directories: [Reference] { Closure.with(closure, { $0 })?.directories ?? [] }
    public var config: Config { Closure.with(closure, { $0.config }) ?? [:] }
    public var components: [Reference] { artifacts + commands + harnesses + sheets + transcripts }
    public var rendered: String { Closure.with(closure, { $0.rendered }) ?? "" }

    public func configure(_ value: Value?, for key: String) { Closure.update(closure) { $0.config[key] = value } }

    public func add(_ ref: Reference) {
        switch ref.type {
            case is Space.Type: Space.update(ref) { $0.attach(to: self.ref) }
            case is any Functional.Type: Closure.update(closure) { $0.interfaces.update(with: ref) }
            case is any Malleable.Type: Closure.update(closure) { if !$0.content.contains(ref) { $0.content.append(ref) } }
            default: break
        }
    }

    public func remove(_ ref: Reference) {
        switch ref.type {
            case is Space.Type: Space.update(ref) { $0.detach(from: self.ref) }
            case is any Functional.Type: Closure.update(closure) { $0.interfaces.remove(ref) }
            case is any Malleable.Type: Closure.update(closure) { $0.content.removeAll { $0 == ref } }
            default: break
        }
    }

    public static func new(_ name: String) -> Reference { new(name, framing: .Scint) }

    public static func new(_ name: String, framing: Framing) -> Reference {
        var instance = Workspace(.init(Self.self))
        Descriptor.add(instance.ref, framing: framing, name: name, tags: ["space"])
        instance.closure = Closure.new("Closure", owner: instance.ref)
        Workspaces.shared.add(instance.ref, instance)
        return instance.ref
    }

    private enum CodingKeys: String, CodingKey { case ref, spaces, closure, harness }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.ref = try container.decode(Reference.self, forKey: .ref)
        self.spaces = try container.decodeIfPresent(Set<Reference>.self, forKey: .spaces) ?? []
        self.closure = try container.decode(Reference.self, forKey: .closure)
        self.harness = try container.decode(Reference.self, forKey: .harness)
    }
}
