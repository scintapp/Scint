import Foundation


struct Renderer {
    let origin: Reference
    let transcript: Reference

    static func evaluation(_ origin: Reference, transcript: Reference, input: String) -> String {
        let map = Renderer(origin: origin, transcript: transcript)
        return map.compose([
            map.preamble,
            map.content(),
            map.interfaces(),
            map.thread(limit: 12),
            map.request(input)
        ])
    }

    private func compose(_ sections: [String?]) -> String {
        sections.compactMap { $0 }.joined(separator: "\n\n")
    }

    private var closure: Reference? {
        Space.with(origin, { $0.closure }) ?? Workspace.with(origin, { $0.closure })
    }

    private var preamble: String? {
        """
        You are working in a space: an environment holding documents you can read and \
        capabilities you can invoke. Everything below is a summary — use your tools to \
        reach the current state of anything you need.

        Capabilities are available to you as tools. Call them directly.
        """
    }

    private func content() -> String? {
        guard let closure, let materials = Closure.with(closure, { $0.materials }) else { return nil }
        let lines = materials
            .filter { !$0.descriptor.tags.contains("input") && $0.descriptor.published }
            .map { ref -> String in
                let description = ref.descriptor.description.trimmingCharacters(in: .whitespacesAndNewlines)
                return description.isEmpty
                    ? "- \(ref.descriptor.name) [\(ref.handle)]"
                    : "- \(ref.descriptor.name) [\(ref.handle)] — \(description)"
            }
        guard !lines.isEmpty else { return nil }
        let usage = "Load one with `Scint.content.load`, or `Scint.content.list` for its blocks and task states."
        return "## Documents\n\n\(usage)\n\n\(lines.joined(separator: "\n"))"
    }

    private func interfaces() -> String? {
        guard let closure, let record = Closure.with(closure, { $0 }) else { return nil }
        let lines = (record.harnesses + record.commands)
            .filter { $0.descriptor.published }
            .sorted { $0.descriptor.name < $1.descriptor.name }
            .map { ref -> String in
                let description = ref.descriptor.description.trimmingCharacters(in: .whitespacesAndNewlines)
                return description.isEmpty ? "- \(ref.descriptor.name)" : "- \(ref.descriptor.name) — \(description)"
            }
        return lines.isEmpty ? nil : "## Capabilities\n\n\(lines.joined(separator: "\n"))"
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

    private func request(_ input: String) -> String? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : "## Request\n\n\(text)"
    }
}
