import Foundation


public struct Closure: Structural {
    public let ref: Reference
    public var owner: Reference
    public var input: Reference
    public var content: [Reference] = []
    public var interfaces: Set<Reference> = []
    public var config: Config = [:]

    public init(_ ref: Reference = .init(Self.self)) {
        self.ref = ref
        self.owner = ref
        self.input = ref
    }

    public var artifacts: [Reference] { interfaces.filter { $0.type is Artifact.Type } }
    public var commands: [Reference] { interfaces.filter { $0.type is Command.Type } }
    public var harnesses: [Reference] { interfaces.filter { $0.type is Harness.Type } }
    public var sheets: [Reference] { content.filter { $0.type is Sheet.Type } }
    public var transcripts: [Reference] { content.filter { $0.type is Transcript.Type } }

    public var directories: [Reference] {
        artifacts.filter { Artifact.with($0, { $0.handler.directory }) == true }.sorted {
            let lhs = $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name)
            return lhs == .orderedSame ? $0.id.uuidString < $1.id.uuidString : lhs == .orderedAscending
        }
    }

    public var rendered: String {
        var includedInput = false
        return sheets.compactMap { ref -> String? in
            if ref.descriptor.tags.contains("input") {
                guard !includedInput else { return nil }
                includedInput = true
            }
            guard let content = Sheet.with(ref, { $0.rendered }), !content.isEmpty else { return nil }
            return "# \(ref.descriptor.name)\n\(content)"
        }.joined(separator: "\n\n")
    }

    public static func new(_ name: String, owner: Reference) -> Reference {
        var instance = Closure(.init(Self.self))
        instance.owner = owner
        instance.input = Sheet.new(owner, input: true)
        Descriptor.add(instance.ref, name: name, tags: ["closure"])
        Workspaces.shared.add(instance.ref, instance)
        if owner.type == Workspace.self { Workspace.update(owner, { $0.closure = instance.ref}) }
        else { Space.update(owner, { $0.closure = instance.ref}) }
        return instance.ref
    }
}
