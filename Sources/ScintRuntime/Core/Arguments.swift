import Foundation


/// Marshals declared values into the argument vector handed to the service.
///
/// Deliberately not `Renderer`. Rendering produces prose for a person or a model to read, and
/// answers to legibility. Marshalling produces argv for whatever tool sits on the far side of the
/// XPC service, and answers to that tool's parser — a different contract, failing in a different
/// way. The two agreed often enough to share one function, which is how a prompt formatter came
/// to decide how processes are invoked.
///
/// Everything about the shape of an invocation is decided here and nowhere else.
enum Arguments {

    /// One declared value, flattened into zero or more argv elements.
    static func marshal(_ value: Value) -> [String] {
        switch value {
            case .bool(let value): return [String(value)]
            case .integer(let value): return [String(value)]
            case .decimal(let value): return [String(describing: value)]
            case .string(let value): return [value]
            case .date(let value): return [Value.formatter.string(from: value)]
            case .sequence(let values), .range(let values): return values.flatMap(marshal)
            case .reference(let ref): return address(ref)

            // A single-key collection is how a flag and its value are declared together. Joining
            // them with `=` keeps them one element, which GNU-style and clap-style parsers accept;
            // tools with hand-rolled parsers want two elements instead, and have no way to say so
            // yet. Until they do, those belong in the command as fixed pairs.
            case .collection(let values):
                return values.keys.sorted().flatMap { key -> [String] in
                    guard let value = values[key] else { return [] }
                    return marshal(value).map { "\(key)=\($0)" }
                }
        }
    }

    /// Several declared values in declaration order.
    static func marshal(_ values: [Value]) -> [String] { values.flatMap(marshal) }

    /// What a process can actually act on: a file path for an artifact, an address for anything
    /// else. Prose rendering answers this with a name and a description, which reads well in a
    /// prompt and means nothing to an argument parser.
    private static func address(_ ref: Reference) -> [String] {
        if ref.type is Artifact.Type {
            guard let path = Artifact.with(ref, { $0.rendered }), !path.isEmpty else { return [] }
            return [path]
        }
        guard let url = Reference.Link.url(for: ref) else { return [] }
        return [url.absoluteString]
    }
}
