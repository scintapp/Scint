import Foundation


struct Closure: Structural {
    let ref: Reference
    var config: Config = [:]
    var content: [Reference] = []
    var interfaces: Set<Reference> = []
    var input: Reference
    var owner: Reference

    init(_ ref: Reference = .init(Self.self)) {
        self.ref = ref
        self.owner = ref
        self.input = ref
    }

    var artifacts: [Reference] { interfaces.filter { $0.type is Artifact.Type } }
    var commands: [Reference] { interfaces.filter { $0.type is Command.Type } }
    var harnesses: [Reference] { interfaces.filter { $0.type is Harness.Type } }
    var sheets: [Reference] { content.filter { $0.type is Sheet.Type } }
    var transcripts: [Reference] { content.filter { $0.type is Transcript.Type } }
    var directories: [Reference] {
        artifacts.filter { Artifact.with($0, { $0.handler.directory }) == true }.sorted {
            let lhs = $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name)
            return lhs == .orderedSame ? $0.id.uuidString < $1.id.uuidString : lhs == .orderedAscending
        }
    }

    var rendered: String {
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

    static func new(_ name: String, owner: Reference) -> Reference {
        var instance = Closure(.init(Self.self))
        instance.owner = owner
        instance.input = Sheet.new(owner, input: true)
        Descriptor.new(instance.ref, name: name, tags: ["closure"])
        Workspaces.shared.add(instance.ref, instance)
        if owner.type == Workspace.self { Workspace.update(owner, { $0.closure = instance.ref}) }
        else { Space.update(owner, { $0.closure = instance.ref}) }
        return instance.ref
    }
}
