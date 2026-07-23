import Foundation
import Observation
import AgencyRuntime


@MainActor final class FileProvider {
    var showHidden: Bool = false
    var workspace: Reference
    var artifacts: [Reference] {
        Workspace.with(workspace) { workspace in
            workspace.artifacts.filter { ref in
                Artifact.with(ref) {
                    switch $0.handler {
                        case .directory, .file: true
                        default: false
                    }
                } == true
            }
        } ?? []
    }

    init(_ workspace: Reference) { self.workspace = workspace }

    func children(for artifact: Artifact.Handler) -> [Artifact.Handler] {
        artifact.children
            .filter { child in
                guard let url = child.url else { return false }
                guard showHidden else {
                    let hidden = (try? url.resourceValues(forKeys: Set([.isHiddenKey])))?.isHidden
                    return hidden != true
                }
                return true
            }
    }
}
