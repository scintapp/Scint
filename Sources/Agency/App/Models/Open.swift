import AgencyRuntime
import Foundation


struct Open: Equatable, Sendable {
    var sheet: Reference
    var origin: Reference?
    var entry: UUID?

    static func opening(_ sheet: Reference, from origin: Reference? = nil, entry: UUID? = nil) -> Self {
        .init(sheet: sheet, origin: origin, entry: entry)
    }
}
