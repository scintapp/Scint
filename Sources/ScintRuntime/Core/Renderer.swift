import Foundation


struct Renderer {
    let origin: Reference
    var transcript: Reference

    private var closure: Reference? { Space.with(origin, { $0.closure }) }

    private var preamble: String? {
        """
        You are working in a space: an environment holding documents you can read and \
        capabilities you can invoke. Everything below is a summary — use your tools to \
        reach the current state of anything you need.

        Capabilities are available to you as tools. Call them directly.
        """
    }

    static func evaluation(_ origin: Reference, transcript: Reference, input: String) -> String {
        let map = Renderer(origin: origin, transcript: transcript)
        return map.assemble([
            map.preamble,
            map.content(),
            map.interfaces(),
            map.thread(limit: 12),
            map.input(input)
        ])
    }

    private func assemble(_ sections: [String?]) -> String {
        sections.compactMap { $0 }.joined(separator: "\n\n")
    }

    private func content() -> String? {
        guard let closure, let materials = Closure.with(closure, { $0.materials }) else { return nil }
        let lines = materials
            .filter { !$0.descriptor.tags.contains("input") && $0.descriptor.published }
            .map { ref -> String in
                let description = ref.descriptor.description.trimmingCharacters(in: .whitespacesAndNewlines)
                let address = Reference.Link.url(for: ref)?.absoluteString ?? ref.id.uuidString
                return description.isEmpty
                ? "- \(ref.descriptor.name) — \(address)"
                : "- \(ref.descriptor.name) — \(address)\n  \(description)"
            }
        guard !lines.isEmpty else { return nil }
        let usage = "Read one with `scint.content.read`, or `scint.content.list` for everything here. "
            + "Every tool takes an address."
        return "## Documents\n\n\(usage)\n\n\(lines.joined(separator: "\n"))"
    }

    private func interfaces() -> String? {
        guard let closure, let record = Closure.with(closure, { $0 }) else { return nil }
        let lines = (record.harnesses + record.commands)
            .filter { $0.descriptor.published }
            .sorted { $0.descriptor.name < $1.descriptor.name }
            .map { ref -> String in
                let description = ref.descriptor.description.trimmingCharacters(in: .whitespacesAndNewlines)
                let address = Reference.Link.url(for: ref)?.absoluteString ?? ref.id.uuidString
                return description.isEmpty
                ? "- \(ref.descriptor.name) — \(address)"
                : "- \(ref.descriptor.name) — \(address)\n  \(description)"
            }
        guard !lines.isEmpty else { return nil }
        let usage = "Run one with `scint.interfaces.call`, after `scint.interfaces.describe` for what it takes."
        return "## Capabilities\n\n\(usage)\n\n\(lines.joined(separator: "\n"))"
    }

    private func thread(limit: Int) -> String? {
        guard let records = Transcript.with(transcript, { $0.records }) else { return nil }
        let turns = records.compactMap(turn)
        guard !turns.isEmpty else { return nil }
        return "## Thread\n\n\(turns.suffix(limit).joined(separator: "\n\n"))"
    }

    private func turn(_ chunk: Chunk) -> String? {
        guard let text = text(chunk.value)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty
        else { return nil }
        return chunk.origin.type == Material.self ? "**Request** — \(text)" : "**Response** — \(text)"
    }

    private func text(_ value: Value) -> String? {
        switch value {
            case .string(let text): return text
            case .collection(let fields):
                guard case .string(let text)? = fields["text"] else { return nil }
                return text
            default: return nil
        }
    }

    private func input(_ input: String) -> String? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : "## Request\n\n\(text)"
    }
}

extension Renderer {
    static func value(_ value: Value) -> [String] {
        switch value {
        case .bool(let value): return [String(value)]
        case .date(let value): return [Value.formatter.string(from: value)]
        case .integer(let value): return [String(value)]
        case .decimal(let value): return [String(describing: value)]
        case .string(let value): return [value]
            case .sequence(let values), .range(let values): return values.flatMap { Renderer.value($0) }
        case .collection(let values):
                return values.keys.sorted().flatMap { key -> [String] in
                    guard let value = values[key] else { return [] }
                    return Renderer.value(value).map { "\(key)=\($0)" }
                }
            case .reference(let ref):
                let rendered = Renderer.reference(ref)
                return rendered.isEmpty ? [] : [rendered]
        }
    }

    static func reference(_ ref: Reference) -> String {
        switch ref.type {
            case is Artifact.Type: return Artifact.with(ref, { $0.rendered }) ?? ""
            case is Command.Type: return Command.with(ref, { $0.rendered }) ?? ""
            case is Harness.Type: return Harness.with(ref, { $0.rendered }) ?? ""
            case is Material.Type: return Material.with(ref, { $0.rendered }) ?? ""
            case is Transcript.Type: return Transcript.with(ref, { $0.rendered }) ?? ""
            case is Closure.Type: return Closure.with(ref, { $0.rendered }) ?? ""
            case is Bridge.Type: return Bridge.with(ref, { $0.rendered }) ?? ""
            case is Space.Type: return Space.with(ref, { $0.rendered }) ?? ""
            default: return ""
        }
    }
}
