import Foundation
import Observation


@MainActor final class FileProvider {
//    var showHidden: Bool = false
//    var workspace: Reference

//    init(_ workspace: Reference) { self.workspace = workspace }


//    var artifacts: [Reference] {
//        Workspace.with(workspace) { workspace in
//            workspace.artifacts.filter { ref in
//                Artifact.with(ref) {
//                    switch $0.handler {
//                        case .directory, .file: true
//                        default: false
//                    }
//                } == true
//            }
//        } ?? []
//    }

    func artifacts(_ workspace: Reference) -> [Reference] {
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

    func children(for artifact: Artifact.Handler) -> [Artifact.Handler] {
        artifact.children
            .filter { child in
                guard let url = child.url else { return false }
                return true
            }
    }
}
