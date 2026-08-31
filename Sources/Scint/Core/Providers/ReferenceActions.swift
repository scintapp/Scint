import AppKit
import SwiftUI


@Observable @MainActor final class ReferenceSelection {
    static let shared = ReferenceSelection()
    var selected: Reference?
    private init() {}
}

@MainActor enum ReferenceActions {
    @discardableResult
    static func open(_ ref: Reference, in model: any Model) -> Bool {
        if let url = Artifact.with(ref, { $0.handler.url }) ?? nil { return open(url) }
        model.select(ref)
        return true
    }

    private static func open(_ url: URL) -> Bool {
        guard url.isFileURL else { return NSWorkspace.shared.open(url) }
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        guard exists else { return false }
        if isDirectory.boolValue, url.pathExtension.lowercased() != "app" { NSWorkspace.shared.open(url) }
        else { NSWorkspace.shared.activateFileViewerSelecting([url]) }
        return true
    }
}
