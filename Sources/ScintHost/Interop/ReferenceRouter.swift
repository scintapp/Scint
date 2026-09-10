import AppKit
import Foundation


/// The `scint://` inbound surface.
///
/// `Reference.Link` in the runtime knows how to write and resolve a reference as a URL. It stops
/// there, because *acting* on one is a protocol, not an identity — which puts it here, beside the
/// MCP server, as the app's other way in. A URL arriving from Raycast, a Shortcut, a terminal, or
/// a click on an inline chip all land in the same place.
@MainActor enum ReferenceRouter {
    private static var handlers: [String: (Request) -> Bool] = [:]

    /// What a `scint://` URL is asking for.
    ///
    /// Both shapes parse to this: the plain `scint://command/<id>` is an `open` with no callbacks,
    /// and `scint://x-callback-url/<action>?…` carries an action, parameters and return paths.
    struct Request: Sendable {
        let action: String
        let reference: Reference?
        let parameters: [String: String]
        let success: URL?
        let error: URL?
        let cancel: URL?

        /// The type the URL claimed, when it named one. Advisory — the catalog resolved the
        /// reference, not this.
        let kind: String?
    }

    static let callbackHost = "x-callback-url"
    static let openAction = "open"

    // MARK: - Registration

    /// Registers what an action means. A handler reports whether it dealt with the request.
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

    /// Writes an x-callback URL for `action`, with optional return paths.
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
