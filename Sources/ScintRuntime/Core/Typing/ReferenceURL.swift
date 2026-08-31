import Foundation


/// A live runtime object addressed as a URL.
///
/// `scint://command/9f3a1c2e-…` is a pointer to something in the library. It survives as plain
/// text, so it can sit in a document, a log, a commit message, a tool result, or someone else's
/// text editor, and still resolve back to the object it names. Anything that can carry a URL can
/// carry a reference.
///
/// This is the same kind of thing as `Reference.handle` — a stable external name — which is why it
/// lives here rather than in `Environment`. It knows nothing about what anyone does with one:
/// actions, callbacks and routing are an interop concern and live in `ScintHost`.
///
/// **The descriptor id is the address.** A `Reference` carries five ids and cannot be rebuilt from
/// a URL — constructing one would mint a new identity rather than address the existing record. But
/// `Catalog` indexes descriptors, so one lookup returns the real reference. The type name in the
/// host position is for whoever reads the URL; the catalog is the authority, so a URL survives its
/// object being re-typed.
///
/// Every registered type is addressable, not a hand-picked few: the name comes from `Registry`.
enum ReferenceURL {
    static let scheme = "scint"

    static func url(for ref: Reference) -> URL? {
        guard let host = host(for: ref) else { return nil }
        return URL(string: "\(scheme)://\(host)/\(ref.descriptorId.uuidString.lowercased())")
    }

    /// The markdown to splice into a document. Falls back to the object's own name.
    static func markdown(for ref: Reference, name: String? = nil) -> String? {
        guard let url = url(for: ref) else { return nil }
        return "[\(label(name ?? Catalog.shared.get(ref)?.name ?? "Reference"))](\(url.absoluteString))"
    }

    static func isReference(_ string: String) -> Bool {
        URL(string: string)?.scheme?.lowercased() == scheme
    }

    static func reference(in string: String) -> Reference? {
        guard let url = URL(string: string) else { return nil }
        return reference(in: url)
    }

    /// Resolves the object a URL names, from either shape: `scint://kind/<id>` or any URL carrying
    /// a `ref` query item.
    static func reference(in url: URL) -> Reference? {
        guard url.scheme?.lowercased() == scheme else { return nil }

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let query = components.queryItems?.first(where: { $0.name == "ref" })?.value,
           let found = resolve(query) {
            return found
        }

        return url.pathComponents.last { $0 != "/" }.flatMap(resolve)
    }

    /// Resolves a descriptor id, however it was written.
    static func resolve(_ id: String) -> Reference? {
        guard let descriptorId = UUID(uuidString: id) else { return nil }
        return Catalog.shared.get(descriptorId)
    }

    /// The type name used in the host position, from the registry rather than a fixed list — so
    /// every registered type is addressable.
    static func host(for ref: Reference) -> String? {
        guard let type = ref.type else { return nil }
        return String(describing: type).lowercased()
    }

    /// Brackets and newlines would end a markdown link early, so they never reach the label.
    private static func label(_ name: String) -> String {
        let cleaned = name
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? "Reference" : cleaned
    }
}
