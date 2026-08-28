import Foundation


struct Serialization {
    let origin: Reference
    let branch: Reference
    var intent: Harness.Intent? = nil

    private var showsRelated: Bool { intent == .compose }
    private var showsObserved: Bool { intent == .observe }

    static let handleLength = 8

    static func handle(for ref: Reference) -> String {
        String(ref.storageId.uuidString.lowercased().replacingOccurrences(of: "-", with: "").prefix(handleLength))
    }

    static func sheets(in origin: Reference) -> [(handle: String, ref: Reference)] {
        guard let closure = Space.with(origin, { $0.closure }) ?? Workspace.with(origin, { $0.closure })
        else { return [] }
        return (Closure.with(closure, { $0.materials }) ?? [])
            .filter { !$0.descriptor.tags.contains("input") }
            .map { (handle(for: $0), $0) }
    }

    private var preamble: String {
        var lines = [
            "- **Space** — the scoped environment you are working in."
        ]
        if showsRelated {
            lines.append("- **Related Spaces** — spaces contained by this one, shown as summaries. Their contents are not included here.")
        }
        if showsObserved {
            lines.append("- **Observed** — the recent activity of the space you are watching.")
        }
        lines.append("- **Content** — sheets belonging to this space, listed by name and handle. Load one with the content tool to read its body.")
        lines.append("- **Thread** — the chronological record of this space, including earlier turns.")

        return """
        Scint organizes work into spaces. A space holds content you can read, capabilities \
        you can invoke, and a thread recording what has happened in it.

        \(lines.joined(separator: "\n"))

        Your tools are scoped to this space. Everything below describes it.
        """
    }

    private var closure: Reference? {
        Space.with(origin, { $0.closure }) ?? Workspace.with(origin, { $0.closure })
    }

    private var space: String {
        let descriptor = origin.descriptor
        let description = descriptor.description.trimmingCharacters(in: .whitespacesAndNewlines)
        return description.isEmpty
            ? "\(descriptor.name)\n\n_No description has been written for this space._"
            : "\(descriptor.name) — \(description)"
    }

    private var related: [String] {
        let children = Space.with(origin, { $0.spaces }) ?? Workspace.with(origin, { $0.spaces }) ?? []
        let summaries = children.map { ref -> String in
            let descriptor = ref.descriptor
            let description = descriptor.description.trimmingCharacters(in: .whitespacesAndNewlines)
            return description.isEmpty ? "- \(descriptor.name)" : "- \(descriptor.name) — \(description)"
        }
        let bridged = Runtime.shared.adjacent(from: origin).map { route, target, _ in
            "- \(target.descriptor.name) (via \(route.ref.descriptor.name))"
        }
        return summaries + bridged
    }

    private var content: [String] {
        Self.sheets(in: origin).map { handle, ref in
            let description = ref.descriptor.description.trimmingCharacters(in: .whitespacesAndNewlines)
            return description.isEmpty
                ? "- \(ref.descriptor.name) [\(handle)]"
                : "- \(ref.descriptor.name) [\(handle)] — \(description)"
        }
    }

    private func entries(from start: Reference) -> [Transcript.Entry] {
        var root = start
        var depth = 0
        while depth < 64,
              let owner = Transcript.with(root, { $0.origin }),
              owner.type == Transcript.self {
            root = owner
            depth += 1
        }

        var refs = [root]
        refs += Transcript.with(root, { $0.entries })?.compactMap { entry -> Reference? in
            guard case .transcript(_, let ref, _) = entry else { return nil }
            return ref
        } ?? []
        if !refs.contains(start) { refs.append(start) }

        return refs
            .flatMap { Transcript.with($0, { $0.entries }) ?? [] }
            .sorted { $0.created < $1.created }
    }

    private func thread(from start: Reference) -> [String] {
        entries(from: start).compactMap(line)
    }

    private var observed: [String] {
        guard let value = Space.with(origin, { $0.config["target"] })
                ?? Workspace.with(origin, { $0.config["target"] }),
              case .reference(let target) = value
        else { return [] }

        let roots = Space.with(target, { $0.transcripts }) ?? Workspace.with(target, { $0.transcripts }) ?? []
        guard let root = roots.sorted(by: { $0.descriptor.created > $1.descriptor.created }).first,
              let recent = Transcript.with(root, { $0.entries })?.reversed().compactMap({ entry -> Reference? in
                  guard case .transcript(_, let ref, _) = entry else { return nil }
                  return ref
              }).first
        else { return [] }

        return thread(from: recent)
    }

    private func line(_ entry: Transcript.Entry) -> String? {
        let time = entry.created.formatted(date: .omitted, time: .shortened)

        switch entry {
            case .event(_, let signal, _):
                switch signal {
                    case .updated(let value):
                        switch TranscriptContent(value) {
                            case .message(let text): return turn(time, "agent", text)
                            case .tool(let name, let verb): return turn(time, "agent", "\(verb) \(name)")
                            case .reasoning, nil: return nil
                        }
                    case .failed(let value): return turn(time, "system", value.rendered.joined(separator: " "))
                    case .completed(let value): return value.flatMap { turn(time, "system", $0.rendered.joined(separator: " ")) }
                    case .composed, .started, .stopped: return nil
                }

            case .value(let key, _, _) where key == "context": return nil
            case .value(let key, let value, _):
                let text = value.rendered.joined(separator: " ")
                return key == "input" ? turn(time, "user", text) : turn(time, "system", "\(key) = \(text)")

            case .material(let ref, _):
                return turn(time, "user", Runtime.shared.rendered(ref))

            case .transcript: return nil
        }
    }

    private func turn(_ time: String, _ role: String, _ text: String) -> String? {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return nil }
        return "[\(time)] \(role): \(body)"
    }

    var rendered: String {
        var sections = ["# Scint\n\n\(preamble)", "## Space\n\n\(space)"]

        if showsRelated {
            let related = self.related
            if !related.isEmpty { sections.append("## Related Spaces\n\n\(related.joined(separator: "\n"))") }
        }

        if showsObserved {
            let observed = self.observed
            if !observed.isEmpty { sections.append("## Observed\n\n\(observed.joined(separator: "\n"))") }
        }

        let content = self.content
        if !content.isEmpty { sections.append("## Content\n\n\(content.joined(separator: "\n"))") }

        let thread = self.thread(from: branch)
        if !thread.isEmpty { sections.append("## Thread\n\n\(thread.joined(separator: "\n"))") }

        return sections.joined(separator: "\n\n")
    }
}
