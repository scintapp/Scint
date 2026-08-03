import Foundation


actor Coordinator {
    static let shared = Coordinator()
    private var workspaceDirty = false
    private var libraryDirty: Set<Reference> = []
    private var changed: Set<Reference> = []
    private var task: Task<Void, Never>?

    func schedule(_ ref: Reference) {
        switch ref.type {
            case is any Structural.Type:
                workspaceDirty = true
                changed.insert(ref)
            case is any Malleable.Type, is any Functional.Type:
                libraryDirty.insert(ref)
                changed.insert(ref)
            default: return
        }

        debounce()
    }

    func flush() async {
        task?.cancel()
        task = nil
        let saveWorkspace = workspaceDirty
        let refs = libraryDirty
        let changes = changed
        workspaceDirty = false
        libraryDirty.removeAll()
        changed.removeAll()

        var failed = false
        if saveWorkspace {
            do { try await Workspaces.shared.save() }
            catch {
                workspaceDirty = true
                failed = true
                print("Autosave failed for workspace: \(error)")
            }
        }
        if !refs.isEmpty {
            do { try await Library.shared.save(refs) }
            catch {
                libraryDirty.formUnion(refs)
                failed = true
                print("Autosave failed for library: \(error)")
            }
        }
        for ref in changes { Composer.shared.changed(ref) }
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
