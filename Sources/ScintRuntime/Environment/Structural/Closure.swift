import Foundation


struct Closure: Structural {
    let ref: Reference
    var origin: Reference
    var content: [Reference] = []
    var interfaces: Set<Reference> = []
    var config: Config = [:]
    var input: Reference

    init(_ ref: Reference = .init(Self.self)) {
        self.ref = ref
        self.origin = ref
        self.input = ref
    }

    var artifacts: [Reference] { interfaces.filter { $0.type is Artifact.Type } }
    var commands: [Reference] { interfaces.filter { $0.type is Command.Type } }
    var harnesses: [Reference] { interfaces.filter { $0.type is Harness.Type } }
    var scenes: [Reference] { content.filter { $0.type is Scene.Type } }
    var transcripts: [Reference] { content.filter { $0.type is Transcript.Type } }

    var directories: [Reference] {
        artifacts.filter { Artifact.with($0, { $0.handler.directory }) == true }.sorted {
            let lhs = $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name)
            return lhs == .orderedSame ? $0.id.uuidString < $1.id.uuidString : lhs == .orderedAscending
        }
    }

    var rendered: String {
        var refs = scenes.filter { !$0.descriptor.tags.contains("input") }
        if input.type == Scene.self { refs.append(input) }

        let content = refs.compactMap { ref -> String? in
            let rendered = Runtime.shared.rendered(ref)
            guard !rendered.isEmpty else { return nil }
            return "# \(ref.descriptor.name)\n\(rendered)"
        }

        let available = (harnesses.sorted { $0.descriptor.name < $1.descriptor.name }
                         + commands.sorted { $0.descriptor.name < $1.descriptor.name })
            .map { Runtime.shared.rendered($0) }
            .filter { !$0.isEmpty }

        let capabilities = available.isEmpty ? [] : ["# Available Interfaces\n" + available.joined(separator: "\n\n")]
        return (content + capabilities).joined(separator: "\n\n")
    }

    static func new(_ name: String, owner: Reference) -> Reference {
        var instance = Closure(.init(Self.self))
        instance.origin = owner
        instance.input = Scene.new(owner, input: true)
        Descriptor.new(instance.ref, name: name, tags: ["closure"], published: false)
        Workspaces.shared.add(instance.ref, instance)
        if owner.type == Workspace.self { Workspace.update(owner, { $0.closure = instance.ref}) }
        else if owner.type == Space.self { Space.update(owner, { $0.closure = instance.ref}) }
        else { Bridge.update(owner, { $0.closure = instance.ref}) }
        return instance.ref
    }
}
