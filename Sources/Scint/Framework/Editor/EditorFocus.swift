import SwiftUI
import ScintRuntime


@MainActor @Observable final class EditorFocus {
    struct Target: Hashable {
        let id: AnyHashable
        var occurrence = 0
    }

    struct Placement: Equatable {
        var entry: Exit?
        var caret: Int?
        let request = UUID()
    }

    let ref: Reference
    private(set) var target: Target?
    private(set) var placement: Placement?
    private var caret: Int?

    init(_ ref: Reference) { self.ref = ref }

    private var io: EditorIO { EditorIO(ref: ref) }

    var editing: Target? { placement == nil ? nil : target }
    var selected: Target? { placement == nil ? target : nil }

    var targets: [Target] {
        var seen: [AnyHashable: Int] = [:]
        return io.body.map { block in
            defer { seen[block.id, default: 0] += 1 }
            return Target(id: block.id, occurrence: seen[block.id, default: 0])
        }
    }

    func edit(_ target: Target, entry: Exit? = nil, caret: Int? = nil) {
        self.target = target
        placement = Placement(entry: entry, caret: caret)
    }

    func select(_ target: Target?, caret: Int? = nil) {
        self.target = target
        placement = nil
        self.caret = caret
    }

    func resume() {
        guard let selected else { return }
        edit(selected, entry: .previous, caret: caret)
    }

    func enter(_ target: Target, from exit: Exit) {
        guard let block = io.block(target.id) else { return }
        if EditorIO.edits(block) { edit(target, entry: exit) }
        else { select(target) }
    }

    func move(from target: Target, _ exit: Exit) -> Bool {
        let targets = targets, offset = exit == .next ? 1 : -1
        guard self.target == target, let index = targets.firstIndex(of: target) else { return false }
        guard targets.indices.contains(index + offset) else { return exit == .next && append() }
        if placement == nil, let block = io.block(target.id), EditorIO.edits(block) { select(targets[index + offset]) }
        else { enter(targets[index + offset], from: exit) }
        return true
    }

    func key(_ selector: Selector) -> Bool {
        switch selector {
            case #selector(NSResponder.deleteBackward(_:)), #selector(NSResponder.deleteForward(_:)): deleteSelection()
            case #selector(NSResponder.moveUp(_:)): moveSelection(.previous)
            case #selector(NSResponder.moveDown(_:)): moveSelection(.next)
            case #selector(NSResponder.insertNewline(_:)): editSelection(opening: true)
            case #selector(NSResponder.cancelOperation(_:)): editSelection(opening: false)
            default: false
        }
    }

    private func moveSelection(_ exit: Exit) -> Bool {
        guard let selected else { return false }
        _ = move(from: selected, exit)
        return true
    }

    private func editSelection(opening: Bool) -> Bool {
        guard let selected, let block = io.block(selected.id), let index = targets.firstIndex(of: selected) else { return false }
        if EditorIO.edits(block) { resume() }
        else if opening {
            let paragraph = Block.paragraph(UUID(), ""), position = io.position(index) + 1
            ScintRuntime.Document.update(ref) { $0.insert(paragraph, at: position) }
            edit(.init(id: paragraph.id), entry: .next)
        }
        else { select(nil) }
        return true
    }

    private func deleteSelection() -> Bool {
        guard let selected, let index = targets.firstIndex(of: selected) else { return false }
        let position = io.position(index)
        ScintRuntime.Document.update(ref) { $0.delete(at: position) }
        let remaining = targets
        select(nil)
        if remaining.indices.contains(index) { enter(remaining[index], from: .next) }
        else if !append(), index > 0 { enter(remaining[index - 1], from: .previous) }
        return true
    }

    @discardableResult func append() -> Bool {
        if case .paragraph? = io.body.last { return false }
        let paragraph = Block.paragraph(UUID(), "")
        ScintRuntime.Document.update(ref) { $0.insert(paragraph, at: nil) }
        edit(.init(id: paragraph.id), entry: .next)
        return true
    }

    func split(_ target: Target, _ before: String, _ after: String) -> Bool {
        guard let block = io.block(target.id) else { return false }
        switch (block, before.isEmpty && after.isEmpty) {
            case (.task, true): remove(target, then: .next)
            case (.task, false): edit(.init(id: io.splitTask(target.id, before, after)), entry: .next)
            default: edit(.init(id: io.split(target.id, before, after)), entry: .next)
        }
        return true
    }

    func join(_ target: Target) -> Bool {
        let targets = targets
        guard let index = targets.firstIndex(of: target), let block = io.block(target.id) else { return false }
        if case .task(_, let text, _) = block {
            guard text.isEmpty else { return false }
            remove(target, then: .previous)
            return true
        }
        guard index > 0 else { return false }
        if let seam = io.join(target.id, into: targets[index - 1].id) { edit(.init(id: seam.id), caret: seam.caret) }
        else if io.text(of: target.id).isEmpty { remove(target, then: .previous) }
        else { enter(targets[index - 1], from: .previous) }
        return true
    }

    func insert(_ blocks: [Block], into target: Target, at offset: Int) {
        let continued = io.insert(blocks, into: target.id, at: offset)
        guard let last = blocks.last else { return }
        let body = io.body, targets = targets
        if let index = targets.firstIndex(of: .init(id: last.id)), body.indices.contains(index + 1), let text = EditorIO.markdown(body[index + 1]), text.isEmpty || continued {
            return enter(targets[index + 1], from: .next)
        }
        let paragraph = Block.paragraph(UUID(), "")
        io.insert(paragraph, after: last.id)
        edit(.init(id: paragraph.id), entry: .next)
    }

    private func remove(_ target: Target, then exit: Exit) {
        guard let index = targets.firstIndex(of: target) else { return }
        io.delete(target.id)
        let remaining = targets, destination = exit == .next ? index : index - 1
        if remaining.indices.contains(destination) { enter(remaining[destination], from: exit) }
        else if exit == .next { append() }
    }
}
