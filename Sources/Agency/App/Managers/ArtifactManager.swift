import Foundation
import Observation
import AgencyRuntime


final class ArtifactManager {
    private var workspace: Reference?
    var showHiddenFiles: Bool = false

    init(workspace: Reference? = nil) { self.workspace = workspace }

    var roots: [Reference] {
        guard let workspace else { return [] }
        return Workspace.with(workspace) { workspace in
            workspace.components.compactMap { ref in
                guard Artifact.with(ref, {
                    if case .file(let url) = $0.kind { return url?.isFileURL == true }
                    return false
                }) == true else { return nil }
                return ref
            }
        } ?? []
    }

    @MainActor func load(runtime: Runtime, space: Reference) async {
        self.workspace = space
    }

    func isDirectory(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return false }
        return isDirectory.boolValue
    }

    func children(of entry: Artifact.Kind) -> [URL] {
        entry.children
            .map { $0 }
            .filter { child in
                guard showHiddenFiles else {
                    let hidden = (try? child.resourceValues(forKeys: Set([.isHiddenKey])))?.isHidden
                    return hidden != true
                }
                return true
            }
    }
}
