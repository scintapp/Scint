import AgencyRuntime
import Foundation


struct Focus: Equatable, Sendable {
    var ref: Reference
    var origin: Reference?
    var entry: UUID?
    var url: URL?

    func focused(_ ref: Reference) -> Bool {
        self.ref == ref && entry == nil && url == nil
    }

    func focused(_ ref: Reference, _ entry: UUID?) -> Bool {
        guard let entry else { return focused(ref) }
        return self.ref == ref && self.entry == entry
    }

    func focused(_ ref: Reference, _ url: URL?) -> Bool {
        guard let url else { return focused(ref) }
        return self.ref == ref && self.url == url
    }

    func focused(_ ref: Reference, entry: UUID?, url: URL?) -> Bool {
        if let url { return focused(ref, url) }
        if let entry { return focused(ref, entry) }
        return focused(ref)
    }

    static func focusing(_ ref: Reference, from origin: Reference? = nil, entry: UUID? = nil, url: URL? = nil) -> Self {
        .init(ref: ref, origin: origin, entry: entry, url: url)
    }
}
