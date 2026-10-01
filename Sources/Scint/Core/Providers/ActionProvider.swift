import Foundation
import SwiftUI
import UniformTypeIdentifiers
import ScintRuntime


@Observable @MainActor final class ReferenceSelection {
    static let shared = ReferenceSelection()
    var selected: Reference?
    private init() {}
}

enum PanelContext: CaseIterable, Sendable { case canvas, editor, navigator, search, settings }
enum SurfaceContext: CaseIterable, Sendable { case activity, harness, documents, node, tasks, transcript }
enum SearchAction: String, CaseIterable, Sendable { case search, disclose, activate }
enum StructureAction: String, CaseIterable, Sendable { case new, update, add, remove, attach, detach, delete }
enum ContentAction: String, CaseIterable, Sendable { case new, update, open, insert, clear, remove, delete }
enum InterfaceAction: String, CaseIterable, Sendable { case register, run, remove, unregister }
enum CompositionAction: String, CaseIterable, Sendable { case compose, resolve, start, stop }

@MainActor enum ReferenceAction {
    @discardableResult
    static func open(_ ref: Reference) -> Bool {
        if let url = Artifact.with(ref, { $0.handler.url }) ?? nil { return open(url) }
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
