import AppKit
import Foundation
import ScintRuntime


@MainActor enum CallbackParser {
    struct Request: Sendable {
        let action: String
        let parameters: [String: Property]
        let success: URL?
        let error: URL?
    }

    static func parse(_ url: URL) -> Request? {
        guard url.scheme?.lowercased() == Reference.Link.scheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let tool = ToolRegistry.tools.first(where: { $0.method.name == components.host?.lowercased() })
                else { return nil }

        var query = Dictionary(
            (components.queryItems ?? []).compactMap { item in item.value.map { (item.name, $0) } },
            uniquingKeysWith: { _, last in last }
        )

        let success = query.removeValue(forKey: "x-success").flatMap(URL.init(string:))
        let failure = query.removeValue(forKey: "x-error").flatMap(URL.init(string:))
        query.removeValue(forKey: "x-cancel")
        query.removeValue(forKey: "kind")

        let verb = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if !verb.isEmpty { query["verb"] = verb }
        let properties = tool.method.schema.object?["properties"]?.object ?? [:]

        func argument(_ key: String, _ text: String) -> Property {
            guard properties[key]?.object?["type"]?.string != "string",
                  let value = try? JSONDecoder().decode(Property.self, from: Data(text.utf8))
            else { return .string(text) }
            return value
        }

        return Request(
            action: tool.method.name,
            parameters: Dictionary(uniqueKeysWithValues: query.map { ($0.key, argument($0.key, $0.value)) }),
            success: success,
            error: failure
        )
    }
}

@MainActor enum CallbackHandler {
    static func handle(_ url: URL?, model: ScintModel?) {
        guard let url else { return }
        guard let request = CallbackParser.parse(url) else {
            guard let ref = Reference.Link.reference(in: url), !ReferenceAction.open(ref) else { return }
            model?.model(for: .studio).select(ref)
            return
        }

        func open(_ callback: URL?, _ fields: [String: Property]) {
            guard let callback, var components = URLComponents(url: callback, resolvingAgainstBaseURL: false) else { return }
            var items = URLComponents()
            items.queryItems = fields.map { key, value in
                URLQueryItem(name: key, value: value.string ?? (try? JSONEncoder().encode(value)).flatMap { String(data: $0, encoding: .utf8) })
            }
            let query = items.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
            components.percentEncodedQuery = [components.percentEncodedQuery, query].compactMap { $0 }.joined(separator: "&")
            if let url = components.url { NSWorkspace.shared.open(url) }
        }

        Task {
            do {
                guard let space = model?.data.scint else { throw ToolError(message: "Scint is still loading.") }
                guard let result = try await ToolRegistry.call(request.action, request.parameters, in: space)
                else { throw ToolError(message: "Unknown tool: \(request.action).") }
                open(request.success, result.object ?? ["result": result])
            } catch {
                open(request.error, ["errorMessage": .string((error as? ToolError)?.message ?? error.localizedDescription)])
            }
        }
    }
}
