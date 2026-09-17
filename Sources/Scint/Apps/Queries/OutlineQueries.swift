import SwiftUI


struct OutlinesList: Query {
    static func controls(_ model: any Model) -> Controls {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                return model.session.selection.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                model.select(ref)
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        let home = model.session.outlines
        let scope = model.session.selection.structure

        let outlines = (Space.with(home, { $0 })?.materials ?? [])
            .map { Outline(ref: $0, outlines: home) }
            .filter { outline in
                guard let scope, scope != home else { return true }
                return outline.spaces.contains(scope)
            }

        let groups: [(Composition.State, String)] = [
            (.failed, "Needs You"),
            (.working, "Working"),
            (.active, "Watching"),
            (.inactive, "Idle"),
            (.completed, "Done")
        ]

        return .init(
            id: "outlines",
            sections: groups.compactMap { state, name in
                let items = outlines.filter { $0.state == state }.map { outline in
                    let tasks = outline.tasks
                    return ItemParams(
                        ref: outline.ref,
                        name: outline.ref.descriptor.name,
                        description: tasks.total > 0 ? "\(tasks.done)/\(tasks.total)" : ""
                    )
                }
                return items.isEmpty ? nil : SectionParams(id: name.lowercased(), name: name, items: items)
            }
        )
    }
}
