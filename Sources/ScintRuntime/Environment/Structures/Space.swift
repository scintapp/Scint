import Foundation
import OrderedCollections


public struct Space: Structural {
    public let ref: Reference
    public var space: Reference? = nil
    public var spaces: Set<Reference> = []
    public var routes: Set<Reference> = []
    public var harness: Reference? = nil
    public var closure: Reference

    public init(_ ref: Reference = .init(Self.self)) {
        self.ref = ref
        self.closure = ref
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

    public var composable: Bool { harness != nil }
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
            case is any Functional.Type: Closure.update(closure) { $0.interfaces.update(with: ref) }
            case is any Malleable.Type: Closure.update(closure) { if !$0.content.contains(ref) { $0.content.append(ref) } }
            default: break
        }
    }

    public func remove(_ ref: Reference) {
        switch ref.type {
            case is any Functional.Type: Closure.update(closure) { $0.interfaces.remove(ref) }
            case is any Malleable.Type: Closure.update(closure) { $0.content.removeAll { $0 == ref } }
            default: break
        }
    }

    public mutating func attach(to parent: Reference) {
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

    public mutating func detach(from parent: Reference) {
        if parent.type is Space.Type { Space.update(parent) { $0.spaces.remove(ref) } }
        else if parent.type is Workspace.Type { Workspace.update(parent) { $0.spaces.remove(ref) } }
        if space == parent { space = nil }
    }

    public mutating func attach(child: Reference) {
        guard child != ref, child.type is Space.Type else { return }
        spaces.update(with: child)
        Space.update(child) { $0.attach(to: ref) }
    }

    public mutating func detach(child: Reference) {
        guard child.type is Space.Type else { return }
        spaces.remove(child)
        Space.update(child) { $0.detach(from: ref) }
    }

    public func restructure() -> Reference {
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
}
