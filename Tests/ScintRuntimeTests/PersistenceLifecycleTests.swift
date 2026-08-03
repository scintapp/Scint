@testable import AgencyRuntime
import Testing

@MainActor
@Suite("Persistence lifecycle", .serialized)
struct PersistenceLifecycleTests {
    @Test("workspace save requests before active workspace do not crash")
    func workspaceSaveBeforeActiveDoesNotCrash() async {
        await Workspaces.shared.save(Reference(Closure.self))
    }

    @Test("library save and load directories agree for functional types")
    func libraryDirectoriesMatchSavedFunctionalPaths() {
        let settings = Settings(name: "agency-runtime-tests").persistence

        let artifact = Reference(Artifact.self)
        let command = Reference(Command.self)
        let harness = Reference(Harness.self)

        Descriptor.add(artifact, name: "Artifact Path Test")
        Descriptor.add(command, name: "Command Path Test")
        Descriptor.add(harness, name: "Harness Path Test")

        #expect(settings.libraryPath(for: artifact).deletingLastPathComponent() == settings.interfaceDirectory(for: Artifact.self))
        #expect(settings.libraryPath(for: command).deletingLastPathComponent() == settings.interfaceDirectory(for: Command.self))
        #expect(settings.libraryPath(for: harness).deletingLastPathComponent() == settings.interfaceDirectory(for: Harness.self))
    }

    @Test("Values are embedded in interfaces rather than independently persisted")
    func valuesAreEmbeddedInInterfaces() {
        #expect(Runtime.shared.registry.types.allSatisfy { $0 != Value.self })
    }
}
