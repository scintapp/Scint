import Foundation


struct Outline {
    let ref: Reference
    let outlines: Reference

    var spaces: [Reference] {
        Runtime.shared.all(as: Space.self).compactMap { space, value in
            space != outlines && value.materials.contains(ref) ? space : nil
        }
    }

    var state: Composition.State {
        let states = spaces.map { $0.context?.state ?? .inactive }
        for state in [Composition.State.failed, .working, .active, .completed] where states.contains(state) { return state }
        return .inactive
    }

    var tasks: (done: Int, total: Int) {
        let tasks = (Material.with(ref, { $0.blocks }) ?? []).compactMap { block -> Bool? in
            if case .task(_, _, let completed) = block { return completed }
            return nil
        }
        return (tasks.filter { $0 }.count, tasks.count)
    }
}
