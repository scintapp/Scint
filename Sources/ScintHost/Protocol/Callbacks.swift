import Foundation
import AppKit


@MainActor enum CallbackTrigger {
    static let action = "trigger"

    static func handle(_ request: CallbackRouter.Request) -> Bool {
        guard let ref = request.reference else { return false }
        do {
            try start(ref, with: request.parameters)
            return true
        } catch {
            NSLog("Scint: trigger failed for \(ref.descriptorId): \(String(describing: error))")
            return false
        }
    }

    static func start(_ ref: Reference, with parameters: [String: String]) throws {
        guard ref.type == Space.self || ref.type == Workspace.self,
              let harness = (Space.with(ref, { $0.harness }) ?? Workspace.with(ref, { $0.harness })) ?? nil
                else { throw CallbackError.invalidTrigger(ref) }

        let declared = Harness.with(harness, { $0.parameters }) ?? []

        for (name, value) in try bind(parameters, against: declared) {
            if ref.type == Space.self { Space.with(ref, { $0.configure(value, for: name) }) }
            else { Workspace.with(ref, { $0.configure(value, for: name) }) }
        }

        guard Runtime.shared.start(ref) != nil else { throw CallbackError.dispatchFailed(ref) }
    }

    private static func bind(_ parameters: [String: String], against declared: [Harness.Parameter]) throws -> [String: Value] {
        let templates = declared.reduce(into: [String: Value]()) { templates, parameter in
            switch parameter {
                case .argument(let name, let type, _, _): templates[name] = type
                case .requirement(let name, let type, _): templates[name] = type
                case .target(let name, let type, _): templates[name] = type
                case .command: break
            }
        }

        return try parameters.reduce(into: [String: Value]()) { values, entry in
            guard let template = templates[entry.key]
                    else { throw ParsingError.unexpectedArguments([entry.key]) }
            values[entry.key] = try template.construct(read(entry.value, as: template), name: entry.key)
        }
    }

    private static func read(_ text: String, as template: Value) -> Value {
        switch template {
            case .reference:
                guard let ref = Reference.Link.reference(in: text) ?? Reference.Link.resolve(text)
                        else { return .string(text) }
                return .reference(ref)

            case .sequence(let values) where values.count == 1:
                return read(text, as: values[0])

            case .collection(let values) where values.count == 1:
                return read(text, as: values.values.first!)

            default:
                return .string(text)
        }
    }
}

@MainActor enum CallbackRouter {
    private static var handlers: [String: (Request) -> Bool] = [:]

    struct Request: Sendable {
        let action: String
        let reference: Reference?
        let parameters: [String: String]
        let success: URL?
        let error: URL?
        let cancel: URL?
        let kind: String?
    }

    static let callbackHost = "x-callback-url"
    static let openAction = "open"

    static func register(_ action: String, handler: @escaping (Request) -> Bool) {
        handlers[action] = handler
    }

    @discardableResult
    static func handle(_ url: URL) -> Bool {
        guard let request = parse(url) else { return false }
        return handle(request)
    }

    @discardableResult
    static func handle(_ request: Request) -> Bool {
        let handled = handlers[request.action]?(request) ?? false
        if let callback = handled ? request.success : request.error { NSWorkspace.shared.open(callback) }
        return handled
    }

    @discardableResult
    static func open(_ ref: Reference) -> Bool {
        handle(
            Request(
                action: openAction,
                reference: ref,
                parameters: [:],
                success: nil,
                error: nil,
                cancel: nil,
                kind: nil
            )
        )
    }

    static func parse(_ url: URL) -> Request? {
        guard url.scheme?.lowercased() == Reference.Link.scheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                else { return nil }

        let host = (components.host ?? "").lowercased()
        var query = Dictionary(
            (components.queryItems ?? []).compactMap { item in item.value.map { (item.name, $0) } },
            uniquingKeysWith: { _, last in last }
        )

        guard host == callbackHost else {
            return Request(
                action: openAction,
                reference: Reference.Link.reference(in: url),
                parameters: query,
                success: nil,
                error: nil,
                cancel: nil,
                kind: host.isEmpty ? nil : host
            )
        }

        let success = query.removeValue(forKey: "x-success").flatMap(URL.init(string:))
        let failure = query.removeValue(forKey: "x-error").flatMap(URL.init(string:))
        let cancel = query.removeValue(forKey: "x-cancel").flatMap(URL.init(string:))
        let reference = query.removeValue(forKey: "ref").flatMap(Reference.Link.resolve)
        let kind = query.removeValue(forKey: "kind")

        return Request(
            action: components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")),
            reference: reference,
            parameters: query,
            success: success,
            error: failure,
            cancel: cancel,
            kind: kind
        )
    }

    static func callback(
        _ action: String,
        for ref: Reference? = nil,
        parameters: [String: String] = [:],
        success: URL? = nil,
        error: URL? = nil,
        cancel: URL? = nil
    ) -> URL? {
        var components = URLComponents()
        components.scheme = Reference.Link.scheme
        components.host = callbackHost
        components.path = "/\(action)"

        var items = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        if let ref { items.append(URLQueryItem(name: "ref", value: ref.descriptorId.uuidString.lowercased())) }
        if let success { items.append(URLQueryItem(name: "x-success", value: success.absoluteString)) }
        if let error { items.append(URLQueryItem(name: "x-error", value: error.absoluteString)) }
        if let cancel { items.append(URLQueryItem(name: "x-cancel", value: cancel.absoluteString)) }

        components.queryItems = items.sorted { $0.name < $1.name }
        return components.url
    }
}

