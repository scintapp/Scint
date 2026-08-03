@testable import AgencyRuntime
import Testing


@MainActor
@Suite("Catalog index", .serialized)
struct CatalogIndexTests {
    @Test("catalog get returns descriptors by reference")
    func catalogGetReturnsDescriptorsByReference() {
        let ref = Reference(Sheet.self)
        defer { _ = Catalog.shared.delete(ref) }

        Descriptor.add(ref, name: "Scratch", tags: ["sheet"])

        let descriptor = Catalog.shared.get(ref)
        #expect(descriptor?.name == "Scratch")
        #expect(descriptor?.origin == ref)
    }

    @Test("catalog does not synthesize missing descriptors")
    func catalogDoesNotSynthesizeMissingDescriptors() {
        let ref = Reference(Sheet.self)
        #expect(Catalog.shared.get(ref) == nil)
    }
}
