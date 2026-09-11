import Foundation


struct Material: Malleable {
    let ref: Reference
    var origin: Reference
    private(set) var blocks: [Block] = []
    private(set) var buffer: [Block] = []

    enum Block: Codable, Sendable, Identifiable, Equatable {
        case artifact(Reference)
        case command(Reference)
        case material(Reference)
        case task(UUID, String, Bool)
        case text(UUID, String)

        var id: AnyHashable {
            switch self {
                case .artifact(let ref): return ref
                case .command(let ref): return ref
                case .material(let ref): return ref
                case .task(let id, _, _): return id
                case .text(let id, _): return id
            }
        }
    }

    init(_ ref: Reference = .init(Self.self)) {
        self.ref = ref
        self.origin = ref
    }

    var rendered: String { rendered(blocks, depth: 0) }

    func rendered(_ source: [Block] = [], depth: Int) -> String {
        source.map { block in
            switch block {
                case .artifact(let ref):
                    Artifact.with(ref, { $0 })?.rendered ?? ""
                case .command(let ref):
                    Command.with(ref, { $0 })?.rendered ?? ""
                case .material(let ref):
                    depth >= 2 ? ref.descriptor.name : (Material.with(ref, { $0.rendered(depth: depth + 1) }) ?? "")
                case .task(_, let string, let done):
                    "[\(done ? "x" : " ")] \(string)"
                case .text(_, let string):
                    string
            }
        }
        .joined()
    }

    mutating func insert(_ block: Block, at index: Int?) {
        let insertion = index ?? blocks.endIndex
        guard insertion >= blocks.startIndex, insertion <= blocks.endIndex else { return }
        switch block {
            case .artifact(let ref): if ref.type == Artifact.self { blocks.insert(block, at: insertion) }
            case .command(let ref): if ref.type == Command.self { blocks.insert(block, at: insertion) }
            case .material(let ref): if ref.type == Material.self { blocks.insert(block, at: insertion) }
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

    mutating func clear() {
        buffer = blocks
        blocks = []
    }

    mutating func dump() -> String {
        let value = rendered(buffer, depth: 0)
        buffer = []
        return value
    }

    static func new(_ origin: Reference, name: String = "New Material") -> Reference {
        guard origin.type == Space.self
        else { RuntimeError.fatal("Not a valid material origin.") }
        var instance = Self(.init(Self.self))
        instance.origin = origin
        instance.insert(.text(.init(), "# \(name)"), at: 0)
        Descriptor.new(instance.ref, name: name, tags: [])
        Library.shared.store(for: instance.ref)?.add(instance.ref, instance)
        Space.with(origin, { $0.add(instance.ref) })
        return instance.ref
    }

    static func new(_ origin: Reference, input: Bool = true) -> Reference {
        guard origin.type == Space.self
        else { RuntimeError.fatal("Not a valid transcript origin.") }
        var instance = Self(.init(Self.self))
        instance.origin = origin
        Descriptor.new(instance.ref, name: "Input", tags: ["input"], published: false)
        Library.shared.store(for: instance.ref)?.add(instance.ref, instance)
        return instance.ref
    }
}
