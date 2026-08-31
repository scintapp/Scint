import AppKit
import SwiftUI


/// What opening a reference actually does.
///
/// Selecting it in the session was the same gesture for everything, which is only right for the
/// things a session can show. An artifact is a link — to a file, a folder, a page, an app — and
/// opening one should open the thing it points at, the way opening it anywhere else would.
@MainActor enum ReferenceActions {
    @discardableResult
    static func open(_ ref: Reference, in model: any Model) -> Bool {
        // Artifacts point outward. Everything else lives in the session, so the session shows it.
        if let url = Artifact.with(ref, { $0.handler.url }) ?? nil {
            return open(url)
        }

        model.select(ref)
        return true
    }

    /// Reveals a file in the Finder and hands anything else to the system.
    ///
    /// A directory or a file gets revealed rather than launched: opening a `.swift` in whatever
    /// claims that extension is rarely what someone meant by following a reference to it.
    private static func open(_ url: URL) -> Bool {
        guard url.isFileURL else { return NSWorkspace.shared.open(url) }

        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        guard exists else { return false }

        if isDirectory.boolValue, url.pathExtension.lowercased() != "app" {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
        return true
    }
}
