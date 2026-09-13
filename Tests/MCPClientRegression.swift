import Foundation
import MCP
@testable import Scint

@main struct MCPClientRegression {
    @MainActor static func main() async throws {
        let space = Space.new("SDK client fixture")
        let executable = Artifact.register("Fixture", URL(fileURLWithPath: "/usr/bin/true"))
        let command = Command.register("Fixture", exec: executable)
        let harness = Harness.register("Fixture", command: command, intent: .compose)
        Space.with(space) { $0.add(harness) }
        Space.update(space) { $0.harness = harness }
        _ = Runtime.shared.compose(space)
        let context = Composer.shared.context(space)!
        let branch = Transcript.new(context.transcript, intent: .compose)
        Transcript.update(context.transcript) { $0.insert(branch, intent: .compose) }
        let handler = Handler(space, harness: harness, transcript: branch, arguments: [:])
        let bearer = handler.environment["SCINT_CONTEXT"]!
        var fixture = Property.fromCodable(context)
        fixture["handlers"] = Property.fromCodables([handler])
        let running = try JSONDecoder().decode(type(of: context), from: JSONEncoder().encode(fixture))
        Composer.shared.update(space) { $0 = running }

        let server = ContextServer()
        let network = NetworkServer()
        try await network.start(port: 0) { await server.handle($0) }
        defer { network.stop() }
        let transport = HTTPClientTransport(endpoint: URL(string: "http://127.0.0.1:\(network.port!)/mcp")!, streaming: false,
            requestModifier: { @Sendable request in
                var request = request
                request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
                return request
            })
        let client = MCP.Client(name: "Scint regression", version: "1")
        let initialized = try await client.connect(transport: transport)
        precondition(initialized.protocolVersion == "2025-11-25", "Must negotiate the real SDK's version")
        let listed = try await client.listTools()
        precondition(listed.tools.map(\.name).sorted() == ["scint.domain", "scint.intent"])
        let result = try await client.callTool(name: "scint.intent", arguments: [
            "intent": .string("search"), "action": .string("search"),
            "arguments": .object(["method": .string("list")])
        ])
        precondition(result.isError != true && !result.content.isEmpty)
        let created = try await client.callTool(name: "scint.domain", arguments: [
            "domain": .string("material"), "action": .string("create"),
            "arguments": .object(["name": .string("Client-created material"), "text": .string("MCP round trip")])
        ])
        precondition(created.isError != true && !created.content.isEmpty)
        precondition(Space.with(space) { $0.materials.contains { $0.descriptor.name == "Client-created material" } } == true)
        await client.disconnect()
        print("PASS: real MCP SDK over loopback HTTP negotiates 2025-11-25, authenticates with the existing handler environment, lists both tools, and calls Domain and Intent")
    }
}
