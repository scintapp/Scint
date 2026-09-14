import Foundation


struct ActivitySummary: Query {
    static func controls(_ model: any Model) -> Controls {
        .init(
            onSelect: { item in
                guard let transcript = item.ref else { return }
                model.select(transcript)
            },
            onAction: { item in
                guard let origin = item.ref else { return }
                model.stop(origin)
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        guard let composition = model.compose(model.session.space),
              let root = Transcript.with(composition.transcript, { $0 }),
              let request = root.entries.last(where: {
                  if case .record(let chunk, _) = $0 { return chunk.origin.type == Material.self }
                  return false
              }) else { return .init() }

        var visited: Set<Reference> = []
        func records(_ ref: Reference) -> [(ref: Reference, entry: Transcript.Entry)] {
            guard visited.insert(ref).inserted,
                  let entries = Transcript.with(ref, { $0.entries }) else { return [] }
            return entries.flatMap { entry -> [(ref: Reference, entry: Transcript.Entry)] in
                if case .transcript(let branch, _, _) = entry { return records(branch) }
                return entry.created >= request.created ? [(ref, entry)] : []
            }
        }

        func item(_ ref: Reference, _ entry: Transcript.Entry) -> ItemParams? {
            guard case .record(let chunk, _) = entry else { return nil }
            return .init(ref: ref, entryId: chunk.key.id, name: "")
        }

        var response: ItemParams?
        var activity: ItemParams?
        for (ref, entry) in records(root.ref).sorted(by: { $0.entry.created < $1.entry.created }) {
            guard case .record(let chunk, _) = entry, chunk.origin.type != Material.self else { continue }
            if case .collection(let fields) = chunk.value, case .string("message")? = fields["type"] {
                response = item(ref, entry)
            } else {
                activity = item(ref, entry)
            }
        }

        return .init(ref: root.ref, sections: [
            .init(id: "response", items: [response].compactMap { $0 }),
            .init(id: "activity", items: [activity].compactMap { $0 })
        ])
    }
}
