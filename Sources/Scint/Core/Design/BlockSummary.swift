import Foundation


struct BlockSummary {
    static func firstPreview(_ entries: [Material.Block]) -> String {
        var snippets: [String] = []

        for entry in entries {
            switch entry {
                case .text(_, let text):
                    let lines = text
                        .components(separatedBy: .newlines)
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

                    for line in lines where !line.isEmpty {
                        var isHeading = false

                        for level in 1...6 {
                            if line.hasPrefix(String(repeating: "#", count: level) + " ") {
                                isHeading = true
                                break
                            }
                        }

                        if isHeading { continue }

                        var snippet = line

                        for prefix in ["> ", "- [ ] ", "- [x] ", "- [X] ", "- "] where snippet.hasPrefix(prefix) {
                            snippet.removeFirst(prefix.count)
                            break
                        }

                        let trimmed = snippet.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty { snippets.append(trimmed) }
                        if snippets.count == 2 { return snippets.joined(separator: "\n") }
                    }
                case .task(_, let text, let done):
                    snippets.append("[\(done ? "x" : " ")] \(text)")
                case .artifact(let ref):
                    snippets.append(Artifact.with(ref, { $0.name }) ?? "")
                case .command(let ref):
                    snippets.append(Command.with(ref, { $0.name }) ?? "")
                case .material(let ref):
                    snippets.append(Material.with(ref, { $0.name }) ?? "")
            }

            snippets = snippets
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if snippets.count >= 2 { return snippets.prefix(2).joined(separator: "\n") }
        }

        return snippets.prefix(2).joined(separator: "\n")
    }

    static func commandDescription(_ ref: Reference) -> String {
        Command.with(ref, { $0.description }) ?? ""
    }

    static func materialFacts(_ entries: [Material.Block]) -> [String] {
        let texts = entries.filter { if case .text = $0 { true } else { false } }.count
        let tasks = entries.filter { if case .task = $0 { true } else { false } }.count
        let done = entries.filter { if case .task(_, _, true) = $0 { true } else { false } }.count
        let artifacts = entries.filter { if case .artifact = $0 { true } else { false } }.count
        let interfaces = entries.filter { if case .command = $0 { true } else { false } }.count

        return [
            texts == 0 ? nil : "\(texts) note\(texts == 1 ? "" : "s")",
            tasks == 0 ? nil : "\(done)/\(tasks) tasks",
            artifacts == 0 ? nil : "\(artifacts) artifact\(artifacts == 1 ? "" : "s")",
            interfaces == 0 ? nil : "\(interfaces) interface\(interfaces == 1 ? "" : "s")"
        ].compactMap(\.self)
    }
}
