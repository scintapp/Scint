@testable import AgencyRuntime
import Foundation
import Testing


@MainActor
@Suite("Value construction", .serialized)
struct ValueTests {
    @Test("command parameters preserve registration shape and render runtime values")
    func commandParametersRenderRuntimeValues() throws {
        let exec = Artifact.register("value.echo", URL(fileURLWithPath: "/bin/echo"))
        let command = Command.register(
            "value.command",
            exec: exec,
            params: [
                .fixed(.string("--json")),
                .argument(name: "count", type: .collection(["--count": .integer(0)]), required: true),
                .argument(name: "paths", type: .collection(["--path": .sequence(.string(""))]))
            ]
        )
        let parameters = Command.with(command, { $0.parameters })!
        let values = try Parser.parse(
            ["count": .integer(42), "paths": .sequence([.string("/tmp/one"), .string("/tmp/two")])],
            parameters: parameters
        )
        let rendered = Command.with(command, { $0.rendered(with: values) })!

        #expect(rendered == ["--json", "--count", "42", "--path", "/tmp/one", "/tmp/two"])
    }

    @Test("recursive values preserve and render referenced sequences")
    func recursiveValuesPreserveReferences() throws {
        let first = Artifact.register("First Value Artifact", URL(string: "https://example.com/first")!)
        let second = Artifact.register("Second Value Artifact", URL(string: "https://example.com/second")!)
        let template = Value.sequence(.reference(Artifact.self))
        let value = try template.construct(.sequence([.reference(first), .reference(second)]), name: "artifacts")

        #expect(value.references == [first, second])
        #expect(value.rendered == ["https://example.com/first", "https://example.com/second"])
    }

    @Test("wildcard reference schemas preserve contextual references")
    func wildcardReferenceSchemasPreserveReferences() throws {
        let space = Space.new("Wildcard Target")
        let value = try Value.anyReference.construct(.reference(space), name: "target")

        #expect(value == .reference(space))
    }

    @Test("runtime callbacks resolve descriptors and search the catalog")
    func runtimeCallbacksResolveDescriptorsAndSearchCatalog() throws {
        let space = Space.new("Callback Search Space")
        let open = URL(string: "agency://open?descriptor=\(space.descriptorId.uuidString)")!
        let search = URL(string: "agency://search?query=Callback%20Search%20Space")!

        guard case .open(let opened) = try Runtime.shared.handle(open) else {
            Issue.record("Expected an open callback.")
            return
        }
        guard case .search(let results) = try Runtime.shared.handle(search) else {
            Issue.record("Expected a search callback.")
            return
        }

        #expect(opened == space)
        #expect(results.all.contains { $0.ref == space })
    }

    @Test("runtime trigger callbacks compose structural targets")
    func runtimeTriggerCallbacksComposeStructuralTargets() throws {
        let exec = Artifact.register("callback.traverse", URL(fileURLWithPath: "/bin/echo"))
        let command = Command.register("callback.traverse.command", exec: exec)
        let harness = Harness.register("callback.traverse.harness", command: command, intent: .traverse)
        let space = Space.new("Callback Trigger Space")
        Space.update(space) { $0.harness = harness }
        let url = URL(string: "agency://trigger?descriptor=\(space.descriptorId.uuidString)")!

        guard case .trigger(let triggered) = try Runtime.shared.handle(url) else {
            Issue.record("Expected a trigger callback.")
            return
        }

        #expect(triggered == space)
        #expect(Runtime.shared.context(for: space) != nil)
    }
}
