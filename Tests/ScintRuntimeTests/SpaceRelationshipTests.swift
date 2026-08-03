@testable import AgencyRuntime
import Foundation
import Testing


@MainActor
@Suite("Space relationships", .serialized)
struct SpaceRelationshipTests {
    @Test("new children persist reciprocal parent relationships")
    func childAttachmentIsReciprocal() {
        let parent = Space.new("Attachment Parent \(UUID())")
        let child = Space.new("Attachment Child \(UUID())", owner: parent)

        #expect(Space.with(child, { $0.space }) == parent)
        #expect(Space.with(parent, { $0.spaces.contains(child) }) == true)
    }

    @Test("moving a child updates both parents")
    func childReattachmentIsReciprocal() {
        let first = Space.new("First Parent \(UUID())")
        let second = Space.new("Second Parent \(UUID())")
        let child = Space.new("Moved Child \(UUID())", owner: first)

        Space.update(child) { $0.attach(to: second) }

        #expect(Space.with(child, { $0.space }) == second)
        #expect(Space.with(first, { $0.spaces.contains(child) }) == false)
        #expect(Space.with(second, { $0.spaces.contains(child) }) == true)
    }

    @Test("attaching a space to a workspace links both sides")
    func workspaceAttachmentIsReciprocal() {
        let workspace = Workspace.new("Root Workspace \(UUID())")
        Workspaces.shared.store(for: workspace.ref)?.add(workspace.ref, workspace)
        let parent = Space.new("Root Parent \(UUID())")
        let child = Space.new("Workspace Root \(UUID())", owner: parent)

        Workspace.with(workspace.ref, { $0 })?.add(child)

        #expect(Space.with(child, { $0.space }) == workspace.ref)
        #expect(Space.with(parent, { $0.spaces.contains(child) }) == false)
        #expect(Workspace.with(workspace.ref, { $0.spaces.contains(child) }) == true)
    }

    @Test("restructuring a workspace root keeps its children in the workspace")
    func restructuringRootWeldsRelationships() {
        let workspace = Workspace.new("Weld Workspace \(UUID())")
        Workspaces.shared.store(for: workspace.ref)?.add(workspace.ref, workspace)
        let removed = Space.new("Weld Root \(UUID())", owner: workspace.ref)
        let child = Space.new("Weld Root Child \(UUID())", owner: removed)

        Space.with(removed, { $0 })?.restructure()

        #expect(Space.with(child, { $0.space }) == workspace.ref)
        #expect(Workspace.with(workspace.ref, { $0.spaces.contains(child) }) == true)
        #expect(Workspace.with(workspace.ref, { $0.spaces.contains(removed) }) == false)
    }

    @Test("restructuring a space welds its children to its parent")
    func restructuringWeldsRelationships() {
        let parent = Space.new("Weld Parent \(UUID())")
        let removed = Space.new("Weld Middle \(UUID())", owner: parent)
        let child = Space.new("Weld Child \(UUID())", owner: removed)

        Space.with(removed, { $0 })?.restructure()

        #expect(Space.with(child, { $0.space }) == parent)
        #expect(Space.with(parent, { $0.spaces.contains(child) }) == true)
        #expect(Space.with(parent, { $0.spaces.contains(removed) }) == false)
    }

    @Test("artifact relationships are closure content")
    func artifactsAreClosureContent() {
        let space = Space.new("Artifact Content \(UUID())")
        let artifact = Artifact.register("Artifact \(UUID())", URL(fileURLWithPath: "/tmp/artifact"))
        let closure = Space.with(space, { $0.closure })!
        Space.with(space, { $0 })?.add(artifact)

        #expect(Closure.with(closure, { $0.content.contains(artifact) }) == true)
        #expect(Closure.with(closure, { $0.interfaces.contains(artifact) }) == false)
        #expect(Closure.with(closure, { $0.artifacts.contains(artifact) }) == true)

        Space.with(space, { $0 })?.remove(artifact)

        #expect(Closure.with(closure, { $0.content.contains(artifact) }) == false)
    }
}
