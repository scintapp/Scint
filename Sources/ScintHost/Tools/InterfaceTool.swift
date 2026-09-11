import Foundation


struct InterfaceTool: Tool {
    let origin: Reference
    let action: Operation

    enum Operation: String, Sendable, CaseIterable {
        case read, call
    }

    static let readLimit = 40_000

    var namespace: ToolNamespace { .interfaces }
    var value: String { action.rawValue }

    var title: String {
        switch action {
            case .read: "Read artifact"
            case .call: "Call interface"
        }
    }

    var summary: String {
        switch action {
            case .read:
                "What an artifact points at: a file's contents, a folder's listing, or an address."
            case .call:
                "Run a command or harness. Use scint.interfaces.describe first to see what it takes."
        }
    }

    var parameters: [ToolParameter] {
        switch action {
            case .read:
                [.reference("interface", "The artifact to read.")]
            case .call:
                [
                    .reference("interface", "The command or harness to run."),
                    .object("arguments", "Its arguments, shaped as scint.interfaces.describe reports.", required: false),
                ]
        }
    }

    @MainActor
    static func all(in origin: Reference) -> [InterfaceTool] {
        guard !Scope.members(of: .interfaces, in: origin).isEmpty else { return [] }
        return Operation.allCases.map { InterfaceTool(origin: origin, action: $0) }
    }

    func call(_ arguments: Properties) async -> ToolResult {
        let resolved = await MainActor.run { resolve(arguments) }
        guard let interface = resolved else {
            return .failure("An address for an interface in this space is required. Use scint.interfaces.list.")
        }

        switch action {
            case .read:
                return await MainActor.run { read(interface) }
            case .call:
                let runnable = await MainActor.run {
                    interface.type is Command.Type || interface.type is Harness.Type
                }
                guard runnable else {
                    return .failure("\(interface.descriptor.name) is an artifact. Read it instead of calling it.")
                }
                let supplied = arguments["arguments"]?.properties ?? .object([String: Property]())
                return await InterfaceRunner(interface: interface, origin: origin).call(supplied)
        }
    }

    // MARK: - Reading

    @MainActor
    private func read(_ interface: Reference) -> ToolResult {
        guard let handler = Artifact.with(interface, { $0.handler }) else {
            return .failure("\(interface.descriptor.name) is a \(CatalogTool.kind(interface)). Call it instead of reading it.")
        }
        guard let url = handler.url else { return .failure("\(interface.descriptor.name) has no address.") }

        switch handler {
            case .directory:
                let children = handler.children.compactMap { $0.url?.path(percentEncoded: false) }
                guard !children.isEmpty else { return .ok("\(url.path(percentEncoded: false)) is empty.") }
                return .ok(children.joined(separator: "\n"))

            case .file, .script, .skill, .image:
                return read(url, named: interface.descriptor.name)

            case .app, .bookmark, .executable:
                // Nothing to read: these are things to run or to visit, and the address is what a
                // caller needs in order to do either.
                return .ok(url.absoluteString)
        }
    }

    private func read(_ url: URL, named name: String) -> ToolResult {
        guard url.isFileURL else { return .ok(url.absoluteString) }
        guard let data = try? Data(contentsOf: url) else {
            return .failure("\(name) could not be read at \(url.path(percentEncoded: false)).")
        }
        guard let text = String(data: data, encoding: .utf8) else {
            return .ok("\(url.path(percentEncoded: false)) is \(data.count) bytes of binary content.")
        }
        guard text.count > Self.readLimit else { return .ok(text) }
        return .ok(
            String(text.prefix(Self.readLimit))
                + "\n\n[Scint: truncated at \(Self.readLimit) characters of \(text.count).]"
        )
    }

    @MainActor
    private func resolve(_ arguments: Properties) -> Reference? {
        guard let supplied = arguments["interface"]?.string, !supplied.isEmpty,
              let ref = Reference.Link.reference(in: supplied) ?? Reference.Link.resolve(supplied),
              Scope.reachable(ref, in: origin)
        else { return nil }
        return ref
    }
}
