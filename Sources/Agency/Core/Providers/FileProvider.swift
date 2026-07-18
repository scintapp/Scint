import Foundation
import Observation
import AgencyRuntime


@MainActor final class FileProvider {
    var showHidden: Bool = false
    var workspace: Reference
    var artifacts: [Reference] {
        Workspace.with(workspace) { workspace in
            workspace.artifacts.compactMap { ref in
                guard Artifact.with(ref, {
                    if case .file(let url) = $0.handler { return url?.isFileURL == true }
                    return false
                }) == true else { return nil }
                return ref
            }
        } ?? []
    }

    init(_ workspace: Reference) { self.workspace = workspace }

    func children(for artifact: Artifact.Handler) -> [URL] {
        artifact.children
            .map { $0 }
            .filter { child in
                guard showHidden else {
                    let hidden = (try? child.resourceValues(forKeys: Set([.isHiddenKey])))?.isHidden
                    return hidden != true
                }
                return true
            }
    }

    func directory(at url: URL) -> Bool {
        var dir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &dir) else { return false }
        return dir.boolValue
    }
}
