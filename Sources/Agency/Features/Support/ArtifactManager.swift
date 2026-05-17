import Foundation
import Observation
import AgencyRuntime


final class ArtifactManager {
    var roots: [Reference] = []
    var showHiddenFiles: Bool = false

    init(roots: [Reference] = []) { self.roots = roots }

    func load(runtime: Runtime, space: Reference) async {
        guard let closure = Space.with(space, { $0 })?.closure else { return }
        self.roots = Closure.with(closure) { closure in
            closure.components.compactMap { ref in
                if Artifact.with(ref, {
                    if $0.entry.type == "file" { return true }
                    return false
                }) == true { return ref }
                return nil
            }
        }!
    }

    func isDirectory(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return false }
        return isDirectory.boolValue
    }

    func children(of entry: Artifact.Entry) -> [URL] {
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
