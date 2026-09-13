import Foundation
@testable import Scint

/// Runs against the compiled app module with a temporary XDG data directory.
/// Active process records are fixtures; these tests never launch an agent or executable.
@main struct ToolCatalogRegression {
    @MainActor static func main() async throws {
        func report(_ text: String) { FileHandle.standardOutput.write(Data((text + "\n").utf8)) }
        let origin = Space.new("Catalog test origin")
        let child = Space.new(origin, name: "Child")
        let foreign = Space.new("Foreign origin")
        let document = Material.new(child, name: "Child document")
        let secret = Material.new(foreign, name: "Foreign document")
        let privateInput = Space.with(origin, { $0.input })!
        let artifact = Artifact.register("Executable", URL(fileURLWithPath: "/usr/bin/true"))
        let command = Command.register("Command", exec: artifact)
        let harness = Harness.register("Composer", command: command, intent: .compose)
        for member in [artifact, command, harness] { Space.with(origin) { $0.add(member) } }
        Space.update(origin) { $0.harness = harness }
        let branch = try activate(origin, harness: harness)
        let identity = try ToolIdentity.resolve(branch.contextId)
        let catalog = ToolCatalog()
        let server = ContextServer()

        func address(_ ref: Reference) -> Property { .string(Reference.Link.url(for: ref)!.absoluteString) }
        func call(_ domain: String, _ action: String, _ arguments: [String: Property]) async -> ToolResult {
            await catalog.resolve("scint.domain", arguments: .object([
                "domain": .string(domain), "action": .string(action), "arguments": .object(arguments)
            ]), for: identity)
        }
        func intent(_ name: String, _ action: String, _ arguments: [String: Property]) async -> ToolResult {
            await catalog.resolve("scint.intent", arguments: .object([
                "intent": .string(name), "action": .string(action), "arguments": .object(arguments)
            ]), for: identity)
        }
        func expect(_ result: ToolResult, error: Bool = false, _ label: String) {
            precondition(result.isError == error, "\(label): \(result.text)")
        }
        func request(_ method: String, params: Property = [:], token: UUID? = branch.contextId) async throws -> (Int, Property) {
            var headers: [String: String] = ["Content-Type": "application/json"]
            if let token { headers["Authorization"] = "Bearer \(token.uuidString)" }
            let http = HTTPRequest(method: "POST", headers: headers,
                body: try JSONEncoder().encode(Property.object([
                    "jsonrpc": "2.0", "id": 1, "method": .string(method), "params": params
                ])), path: "/mcp")
            let response = await server.handle(http)
            return (response.statusCode, try JSONDecoder().decode(Property.self, from: response.bodyData!))
        }

        // Contract: exactly two tools over the real JSON-RPC router, including in an empty closure.
        let definitions = catalog.tools(for: identity)
        precondition(definitions.map(\.name) == ["scint.domain", "scint.intent"])
        precondition(definitions.allSatisfy { $0.inputSchema["type"] == "object" })
        precondition(DomainHandler.entry.methods.count == 9 && IntentHandler.entry.methods.count == 12)
        for version in MCPResponse.supportedVersions {
            let initialized = try await request("initialize", params: [
                "protocolVersion": .string(version), "capabilities": [:],
                "clientInfo": ["name": "regression", "version": "1"]
            ])
            precondition(initialized.1["result.protocolVersion"]?.string == version)
        }
        precondition(MCPResponse.supportedVersions.contains("2025-11-25"), "Claude's negotiated version must be supported")
        let listed = try await request("tools/list")
        precondition(listed.0 == 200)
        precondition(listed.1["result.tools"]?.array?.compactMap { $0["name"]?.string } == ["scint.domain", "scint.intent"])
        let oldTool = try await request("tools/call", params: ["name": "scint.content.list", "arguments": [:]])
        precondition(oldTool.1["error.code"] != nil, "Legacy tool names must not be callable")
        let unauthenticated = try await request("tools/list", token: nil)
        let unknown = try await request("tools/list", token: UUID())
        precondition(unauthenticated.0 == 401 && unknown.0 == 403)
        report("PASS: exactly two tools, legacy calls rejected, missing/unknown bearers rejected")

        // All schemas round-trip through the existing Property type and reject malformed envelopes.
        for definition in definitions {
            let data = try JSONEncoder().encode(definition.inputSchema)
            let decoded = try JSONDecoder().decode(Property.self, from: data)
            precondition(decoded == definition.inputSchema)
        }
        expect(await call("material", "create", ["name": .integer(3)]), error: true, "Wrong parameter type")
        expect(await call("material", "create", ["name": " "]), error: true, "Whitespace name")
        expect(await call("material", "create", ["name": "Bad", "identity": address(foreign)]), error: true, "Identity cannot be supplied as arguments")
        expect(await call("material", "run", ["ref": address(document)]), error: true, "Cross-domain action")
        let malformed = try await request("tools/call", params: ["name": "scint.domain", "arguments": []])
        precondition(malformed.1["error.code"] != nil)
        let nullNested = await catalog.resolve("scint.domain", arguments: .object([
            "domain": "material", "action": "create", "arguments": .null
        ]), for: identity)
        expect(nullNested, error: true, "Null argument object")
        report("PASS: Property schema round-trips and argument validation before mutation")

        // Reference capabilities apply to parents, children, private inputs, shared records, and types.
        precondition(Scope.permissions(for: document, in: origin).contains(.insert))
        precondition(!Scope.permissions(for: foreign, in: origin).contains(.read))
        precondition(!Scope.permissions(for: origin, in: child).contains(.read))
        precondition(Scope.permissions(for: privateInput, in: origin).isEmpty)
        precondition(!Scope.permissions(for: branch, in: origin).contains(.insert))
        precondition(Scope.permissions(for: branch, in: origin).contains(.read))
        expect(await call("material", "insert", ["ref": address(secret), "text": "Forbidden"]), error: true, "Foreign material")
        expect(await call("material", "insert", ["ref": address(branch), "text": "Forbidden"]), error: true, "Read-only transcript")
        expect(await call("material", "create", ["space": address(artifact), "name": "Forbidden"]), error: true, "Wrong target type")
        expect(await call("interface", "create", ["kind": "command", "name": "Forbidden", "source": address(secret)]), error: true, "Wrong source type")
        expect(await call("material", "insert", ["ref": address(document), "member": address(secret)]), error: true, "Foreign secondary reference")
        let spoof = Reference.Link.url(for: document)!.absoluteString.replacingOccurrences(of: "://material/", with: "://space/")
        expect(await call("material", "insert", ["ref": .string(spoof), "text": "Forbidden"]), error: true, "Forged address kind")
        Space.with(foreign) { $0.add(document) }
        expect(await call("material", "insert", ["ref": address(document), "text": "Forbidden"]), error: true, "Shared content is read-only")
        Space.with(foreign) { $0.remove(document) }
        let unboundRunner = InterfaceRunner(interface: command, origin: origin)
        expect(await unboundRunner.call(.object([String: Property]())), error: true, "Unbound runner must not bypass identity")
        let referencedCommand = Command.register("Reference argument", exec: artifact, params: [
            .argument(name: "target", type: .reference(Material.self), required: true)
        ])
        Space.with(origin) { $0.add(referencedCommand) }
        let referenceRunner = InterfaceRunner(interface: referencedCommand, origin: origin, identity: identity)
        let availableValues = try referenceRunner.supplied(.object(["target": address(document)]))
        precondition(availableValues["target"] == .reference(document))
        precondition((try? referenceRunner.supplied(.object(["target": address(secret)]))) == nil)
        precondition((try? referenceRunner.supplied(.object(["target": address(privateInput)]))) == nil)
        report("PASS: per-reference scopes, wrong kinds, secondary refs, and shared-record protection")

        // Positive edits and exact block ownership; invalid multi-field updates leave state unchanged.
        expect(await call("material", "insert", ["ref": address(document), "text": "A task", "done": false]), "Insert task")
        let task = Material.with(document, { $0.blocks.last! })!
        let block = Property.string(ContentTool.address(task))
        expect(await call("material", "insert", ["ref": address(document), "block": block, "done": true]), "Complete task")
        guard case .task(_, _, true) = Material.with(document, { $0.blocks.last! })! else { preconditionFailure("Task must be complete") }
        expect(await call("material", "insert", ["ref": address(document), "index": 9999, "text": "No"]), error: true, "Bounds checked")
        expect(await call("material", "insert", ["ref": address(document), "block": block, "index": 0, "text": "No"]), error: true, "Conflicting block selectors")
        expect(await call("material", "delete", ["ref": address(document), "block": block]), "Delete block")
        precondition(!Material.with(document, { $0.blocks.contains { ContentTool.address($0) == block.string! } })!)
        let oldName = child.descriptor.name
        expect(await call("structure", "update", ["ref": address(child), "name": "Must not apply", "harness": address(command)]), error: true, "Atomic validation")
        precondition(child.descriptor.name == oldName)
        expect(await call("structure", "update", ["ref": address(child), "add": address(origin)]), error: true, "Reject topology cycle")
        expect(await call("structure", "update", ["ref": address(child), "remove": address(secret)]), error: true, "Reject false membership")
        expect(await call("structure", "update", ["harness": .null]), error: true, "Protect active harness")
        expect(await call("interface", "delete", ["ref": address(command)]), error: true, "Protect dependencies")
        expect(await call("structure", "delete", ["ref": address(origin)]), error: true, "Protect origin")
        expect(await call("structure", "create", ["name": "New child"]), "Create child")
        let created = Space.with(origin, { $0.spaces.first { $0.descriptor.name == "New child" } })!!
        precondition(Scope.permissions(for: created, in: origin).contains(.create))
        expect(await call("material", "create", ["space": address(created), "name": "Created document", "text": "Body"]), "Create material in new child")
        expect(await call("interface", "create", ["kind": "command", "name": "Created command", "source": address(artifact),
            "parameters": [["name": "message", "type": "string", "required": true]]]), "Create command")
        let createdCommand = Scope.interfaces(in: origin).first { $0.descriptor.name == "Created command" }!
        let createdRunner = InterfaceRunner(interface: createdCommand, origin: origin, identity: identity)
        precondition(createdRunner.inputSchema["required"]?.strings == ["message"])
        expect(await call("interface", "run", ["ref": address(createdCommand)]), error: true, "Missing runtime argument fails before execution")
        expect(await call("interface", "create", ["kind": "harness", "name": "Created harness", "source": address(command), "intent": "observe"]), "Create harness")
        let createdHarness = Scope.interfaces(in: origin).first { $0.descriptor.name == "Created harness" }!
        precondition(Harness.with(createdHarness, { $0.intent }) == .observe)
        // Exercise actual deletion only in the isolated test store.
        expect(await call("interface", "delete", ["ref": address(createdCommand)]), "Delete unreferenced interface")
        precondition(Catalog.shared.get(createdCommand) == nil)
        expect(await call("structure", "create", ["name": "Disposable"]), "Create disposable space")
        let disposable = Space.with(origin, { $0.spaces.first { $0.descriptor.name == "Disposable" } })!!
        expect(await call("structure", "delete", ["ref": address(disposable)]), "Delete empty space")
        precondition(Space.with(disposable, { $0 }) == nil)
        let disposableMaterial = Material.new(origin, name: "Disposable material")
        expect(await call("material", "delete", ["ref": address(disposableMaterial)]), "Delete unshared material")
        precondition(Material.with(disposableMaterial, { $0 }) == nil)
        report("PASS: material edits, block ownership, atomic validation, topology, and new-child access")

        // Discovery preserves reads and schemas while library search grants import only.
        let list = await intent("search", "search", ["method": "list"])
        expect(list, "List scoped refs")
        precondition(list.text.contains("Child document") && !list.text.contains("Foreign document"))
        let description = await intent("search", "search", ["method": "describe", "ref": address(document)])
        expect(description, "Read a material")
        precondition(description.text.contains("scint://block/"))
        let described = await intent("search", "search", ["method": "describe", "ref": address(harness)])
        expect(described, "Describe interface schema")
        precondition(described.text.contains("arguments:") && described.text.contains("scopes:"))
        let library = await intent("search", "search", ["method": "search", "query": "Foreign", "scope": "library"])
        expect(library, "Library metadata search")
        precondition(library.text.contains("scopes: import"))
        expect(await intent("search", "search", ["method": "describe", "ref": address(secret)]), error: true, "Library search does not grant read")
        let originalOwner = Material.with(secret, { $0.origin })!
        expect(await call("structure", "update", ["add": address(secret)]), "Import published material")
        precondition(Material.with(secret, { $0.origin }) == originalOwner, "Import must preserve provenance")
        precondition(Scope.permissions(for: secret, in: origin) == [.read])
        expect(await call("structure", "update", ["remove": address(secret)]), "Detach imported material")
        expect(await intent("evaluate", "plan", [:]), error: true, "Removed plan is not callable")
        expect(await intent("observe", "start", ["harness": address(harness)]), error: true, "Intent/harness mismatch")
        let observer = Harness.register("Observer", command: command, intent: .observe)
        Space.with(origin) { $0.add(observer) }
        expect(await intent("observe", "update", ["harness": address(observer)]), error: true, "Update requires a running intent")
        report("PASS: scoped discovery, content/schema reads, import-only library results, and intent validation")

        // A tool binding cannot retain a grant or identity after a later state change.
        let bound = definitions.first { $0.name == "scint.domain" }!
        Space.with(child) { $0.remove(document) }
        expect(await bound.call(.object(["domain": "material", "action": "insert", "arguments": ["ref": address(document), "text": "No"]])), error: true, "Revoke detached reference")
        expect(await intent("compose", "stop", [:]), "Stop the active compose fixture")
        precondition((try? ToolIdentity.resolve(branch.contextId)) == nil)
        expect(await bound.call(.object(["domain": "material", "action": "create", "arguments": ["name": "No"]])), error: true, "Revoke retained tool binding")
        let stopped = try await request("tools/list")
        precondition(stopped.0 == 403)
        let replacement = try activate(origin, harness: harness)
        precondition(replacement != branch && (try? ToolIdentity.resolve(replacement.contextId)) != nil)
        precondition((try? ToolIdentity.resolve(branch.contextId)) == nil, "Old branch must stay revoked after restart")
        report("PASS: dynamic grant revocation, stopped bearer rejection, fresh identity after restart")
        report("PASS: ToolCatalog regression suite")
    }

    @MainActor private static func activate(_ space: Reference, harness: Reference) throws -> Reference {
        guard Runtime.shared.compose(space) != nil, let context = Composer.shared.context(space) else { fatalError("Fixture must compose") }
        let branch = Transcript.new(context.transcript, intent: .compose)
        Transcript.update(context.transcript) { $0.insert(branch, intent: .compose) }
        let handler = Handler(space, harness: harness, transcript: branch, arguments: [:])
        var value = Property.fromCodable(context)
        value["handlers"] = Property.fromCodables([handler])
        let active = try JSONDecoder().decode(Context.self, from: JSONEncoder().encode(value))
        Composer.shared.update(space) { $0 = active }
        return branch
    }
}
