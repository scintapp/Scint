import Foundation
import OSLog


actor Coordinator {
    static let shared = Coordinator()
    private static let logger = Logger(subsystem: "com.kaechle.scint", category: "Persistence")
    private var workspaceDirty: Set<Reference> = []
    private var libraryDirty: Set<Reference> = []
    private var task: Task<Void, Never>?

    func schedule(_ ref: Reference) {
        switch ref.type {
            case is any Structural.Type:
                workspaceDirty.insert(ref)
            case is any Malleable.Type, is any Functional.Type:
                libraryDirty.insert(ref)
            default: return
        }

        debounce()
    }

    func flush() async {
        task?.cancel()
        task = nil
        let workspaceRefs = workspaceDirty
        let libraryRefs = libraryDirty
        workspaceDirty.removeAll()
        libraryDirty.removeAll()

        var failed = false
        if !workspaceRefs.isEmpty {
            do { try await Workspaces.shared.save(workspaceRefs) }
            catch {
                workspaceDirty.formUnion(workspaceRefs)
                failed = true
                Self.logger.error("Autosave failed for workspace: \(String(describing: error), privacy: .public)")
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
