import Foundation


struct Workspace: Structural {
    let ref: Reference
    var origin: Reference
    var bridges: Set<Reference> = []
    var spaces: Set<Reference> = []
    var harness: Reference
    var closure: Reference

    init(_ ref: Reference = .init(Self.self)) {
        self.ref = ref
        self.origin = ref
        self.closure = ref
        self.harness = ref
    }

    var composable: Bool { harness.type is Harness.Type }
    var composition: Composition? { Composer.shared.resolve(ref) }
    var artifacts: [Reference] { Closure.with(closure, { $0 })?.artifacts ?? [] }
    var commands: [Reference] { Closure.with(closure, { $0 })?.commands ?? [] }
    var harnesses: [Reference] { Closure.with(closure, { $0 })?.harnesses ?? [] }
    var materials: [Reference] { Closure.with(closure, { $0 })?.materials ?? [] }
    var transcripts: [Reference] { Closure.with(closure, { $0 })?.transcripts ?? [] }
    var directories: [Reference] { Closure.with(closure, { $0 })?.directories ?? [] }
    var config: Config { Closure.with(closure, { $0.config }) ?? [:] }
    var components: [Reference] { artifacts + commands + harnesses + materials + transcripts }
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
    var rendered: String { Closure.with(closure, { $0.rendered }) ?? "" }

    func add(_ ref: Reference) {
        switch ref.type {
            case is Space.Type: Space.update(ref) { $0.attach(to: self.ref) }
            case is any Functional.Type: Closure.update(closure) { $0.interfaces.update(with: ref) }
            case is Transcript.Type: // TEMP
                print("[TEMP workspace.add] transcript case matched, closure=\(closure.storageId.uuidString.prefix(8))")
                Closure.update(closure) { if !$0.transcripts.contains(ref) { $0.transcripts.append(ref) } }
                print("[TEMP workspace.add] closure now holds \(Closure.with(closure, { $0.transcripts.count }) ?? -1) transcript(s)")
            case is any Malleable.Type: Closure.update(closure) { if !$0.content.contains(ref) { $0.content.append(ref) } }
            default: print("[TEMP workspace.add] UNMATCHED type=\(String(describing: ref.type))") // TEMP
        }
    }

    func remove(_ ref: Reference) {
        switch ref.type {
            case is Space.Type: Space.update(ref) { $0.detach(from: self.ref) }
            case is any Functional.Type: Closure.update(closure) { $0.interfaces.remove(ref) }
            case is Transcript.Type: Closure.update(closure) { $0.transcripts.removeAll { $0 == ref } }
            case is any Malleable.Type: Closure.update(closure) { $0.content.removeAll { $0 == ref } }
            default: break
        }
    }

    func configure(_ value: Value?, for key: String) { Closure.update(closure) { $0.config[key] = value } }

    @discardableResult
    static func new(_ name: String) -> Reference {
        var instance = Workspace(.init(Self.self))
        Descriptor.new(instance.ref, name: name, tags: ["space"])
        instance.closure = Closure.new("Closure", owner: instance.ref)
        Workspaces.shared.add(instance.ref, instance)
        return instance.ref
    }
}
