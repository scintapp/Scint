import Foundation


struct Scene: Malleable {
    let ref: Reference
    var owner: Reference
    private(set) var blocks: [Block] = []

    enum Block: Codable, Sendable, Identifiable, Equatable {
        case artifact(Reference)
        case command(Reference)
        case scene(Reference)
        case task(UUID, String, Bool)
        case text(UUID, String)

        var id: AnyHashable {
            switch self {
                case .artifact(let ref): return ref
                case .command(let ref): return ref
                case .scene(let ref): return ref
                case .task(let id, _, _): return id
                case .text(let id, _): return id
            }
        }
    }

    init(_ ref: Reference = .init(Self.self)) {
        self.ref = ref
        self.owner = ref
    }

    var rendered: String {
        blocks.map { block in
            switch block {
                case .artifact(let ref):
                    Artifact.with(ref, { $0.rendered }) ?? ""
                case .command(let ref):
                    Command.with(ref, { _ in "Scint.command.\(ref.id.uuidString.lowercased())" }) ?? ""
                case .scene(let ref):
                    Scene.with(ref, { $0.rendered }) ?? ""
                case .task(_, let string, let done):
                    "[\(done ? "x" : " ")] \(string)"
                case .text(_, let string):
                    string
            }
        }
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
    }

    mutating func insert(_ block: Block, at index: Int?) {
        let insertion = index ?? blocks.endIndex
        guard insertion >= blocks.startIndex, insertion <= blocks.endIndex else { return }
        switch block {
            case .artifact(let ref): if ref.type == Artifact.self { blocks.insert(block, at: insertion) }
            case .command(let ref): if ref.type == Command.self { blocks.insert(block, at: insertion) }
            case .scene(let ref): if ref.type == Scene.self { blocks.insert(block, at: insertion) }
            case .task: blocks.insert(block, at: insertion)
            case .text: blocks.insert(block, at: insertion)
        }
    }

    mutating func insert(_ blocks: [Block], at index: Int?) {
        var insertion = index
        for block in blocks {
            let count = self.blocks.count
            insert(block, at: insertion)
            if self.blocks.count > count, let current = insertion { insertion = current + 1 }
        }
    }

    mutating func update(_ block: Block, at index: Int) {
        delete(at: index)
        insert(block, at: index)
    }

    mutating func delete(at index: Int) {
        guard blocks.indices.contains(index) else { return }
        blocks.remove(at: index)
    }

    mutating func delete(from range: NSRange) {
        guard range.location != NSNotFound else { return }
        for _ in 0..<range.length { delete(at: range.location) }
    }

    mutating func clear() { blocks = [] }

    static func new(_ owner: Reference, name: String = "New Scene") -> Reference {
        guard owner.type == Space.self || owner.type == Workspace.self else { RuntimeError.fatal() }
        var instance = Self(.init(Self.self))
        instance.owner = owner
        Descriptor.new(instance.ref, name: name, tags: ["scene"])
        Library.shared.store(for: instance.ref)?.add(instance.ref, instance)
        if owner.type == Workspace.self { Workspace.with(owner, { $0.add(instance.ref) }) }
        else {  Space.with(owner, { $0.add(instance.ref) }) }
        return instance.ref
    }

    static func new(_ owner: Reference, input: Bool = true) -> Reference {
        guard owner.type == Space.self || owner.type == Workspace.self
        else { RuntimeError.fatal() }
        var instance = Self(.init(Self.self))
        instance.owner = owner
        Descriptor.new(instance.ref, name: "Input", tags: ["input"], published: false)
        Library.shared.store(for: instance.ref)?.add(instance.ref, instance)
        return instance.ref
    }
}
