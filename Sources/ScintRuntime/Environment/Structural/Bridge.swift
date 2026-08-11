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

    var artifacts: [Reference] { Closure.with(closure, { $0 })?.artifacts ?? [] }
    var commands: [Reference] { Closure.with(closure, { $0 })?.commands ?? [] }
    var harnesses: [Reference] { Closure.with(closure, { $0 })?.harnesses ?? [] }
    var materials: [Reference] { Closure.with(closure, { $0 })?.materials ?? [] }
    var transcripts: [Reference] { Closure.with(closure, { $0 })?.transcripts ?? [] }
    var directories: [Reference] { Closure.with(closure, { $0 })?.directories ?? [] }
    var config: Config { Closure.with(closure, { $0.config }) ?? [:] }
    var components: [Reference] { artifacts + commands + harnesses + materials + transcripts }

    var rendered: String { Closure.with(closure, { $0.rendered }) ?? "" }

    func configure(_ value: Value?, for key: String) { Closure.update(closure) { $0.config[key] = value } }

    mutating func bridge(space origin: Reference, to target: Reference) {
        Space.update(self.origin, { $0.bridges.remove(self.ref) })
        Space.update(ref, { $0.bridges.update(with: self.ref) })
        self.origin = ref
    }

    mutating func bridge(workspace origin: Reference, to target: Reference) {
        Workspace.update(self.origin, { $0.bridges.remove(self.ref) })
        Workspace.update(ref, { $0.bridges.update(with: self.ref) })
        self.origin = ref
    }

    func add(_ ref: Reference) {
        switch ref.type {
            case is any Functional.Type:
                Closure.update(closure) { $0.interfaces.update(with: ref) }
            case is any Malleable.Type:
                Closure.update(closure) { if !$0.content.contains(ref) { $0.content.append(ref) } }
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

}
