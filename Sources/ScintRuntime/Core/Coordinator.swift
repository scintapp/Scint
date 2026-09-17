import Foundation
import OSLog


actor Coordinator {
    static let shared = Coordinator()
    private static let logger = Logger(subsystem: "com.kaechle.scint", category: "Persistence")
    private var spaceDirty: Set<Reference> = []
    private var libraryDirty: Set<Reference> = []
    private var updates: [Reference: Date] = [:]
    private var task: Task<Void, Never>?

    func updated(_ ref: Reference) {
        updates[ref] = .now
        mark(ref)
        debounce()
    }

    private func mark(_ ref: Reference) {
        switch ref.type {
            case is any Structural.Type: spaceDirty.insert(ref)
            case is any Malleable.Type, is any Functional.Type: libraryDirty.insert(ref)
            default: return
        }
    }

    func flush() async {
        task?.cancel()
        task = nil

        let updates = self.updates
        self.updates.removeAll()
        await MainActor.run { Catalog.shared.stamp(updates) }

        let spaceRefs = spaceDirty
        let libraryRefs = libraryDirty
        spaceDirty.removeAll()
        libraryDirty.removeAll()

        var failed = false
        if !spaceRefs.isEmpty {
            do { try await Workspaces.shared.save() }
            catch {
                spaceDirty.formUnion(spaceRefs)
                failed = true
                Self.logger.error("Autosave failed for space: \(String(describing: error), privacy: .public)")
            }
        }
        if !libraryRefs.isEmpty {
            do { try await Library.shared.save(libraryRefs) }
            catch {
                libraryDirty.formUnion(libraryRefs)
                failed = true
                Self.logger.error("Autosave failed for library: \(String(describing: error), privacy: .public)")
            }
        }
        if failed { debounce() }
    }

    private func debounce() {
        task?.cancel()
        task = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await flush()
        }
    }
}
