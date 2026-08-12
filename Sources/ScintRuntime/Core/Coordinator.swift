import Foundation


actor Coordinator {
    static let shared = Coordinator()
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
        print("[TEMP flush] workspace=\(workspaceRefs.count) library=\(libraryRefs.count)") // TEMP
        if !workspaceRefs.isEmpty {
            do { try await Workspaces.shared.save(workspaceRefs) }
            catch {
                workspaceDirty.formUnion(workspaceRefs)
                failed = true
                print("Autosave failed for workspace: \(error)")
            }
        }
        if !libraryRefs.isEmpty {
            do { try await Library.shared.save(libraryRefs) }
            catch {
                libraryDirty.formUnion(libraryRefs)
                failed = true
                print("Autosave failed for library: \(error)")
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
