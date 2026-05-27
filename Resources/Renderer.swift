import Foundation
import AgencyRuntime

enum Renderer {
    static func render(_ refs: [Reference]) -> String {
        var components: [String] = []
        var interfaces: [String] = []
        var structures: [String] = []

        for ref in refs {
            switch ref.type {
            case is Artifact.Type: components.append(render(ref, Artifact.self))
            case is Sheet.Type: components.append(render(ref, Sheet.self))
            case is Transcript.Type: components.append(render(ref, Transcript.self))
            case is Control.Type: interfaces.append(render(ref, Control.self))
            case is Route.Type: structures.append(render(ref, Route.self))
            case is Closure.Type: structures.append(render(ref, Closure.self))
            case is Space.Type: structures.append(render(ref, Space.self))
            case is Workspace.Type: structures.append(render(ref, Workspace.self))
            default: break
            }
        }

        return [components, interfaces]
            .map { $0.joined(separator: "\n\n") }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n---\n\n")
    }

    public static func render<T: Malleable>(_ ref: Reference, _ type: T.Type) -> String {
        T.with(ref, { $0.rendered }) ?? ""
    }

    public static func render<T: Functional>(_ ref: Reference, _ type: T.Type) -> String {
        T.with(ref, { $0.rendered }) ?? ""
    }

    public static func render<T: Structural>(_ ref: Reference, _ type: T.Type) -> String {
        T.with(ref, { $0.rendered }) ?? ""
    }
}
