import AgencyRuntime
import Foundation


enum Focus: Equatable, Sendable {
    case content(Reference)
    case structure(Reference)
    case interface(Reference)
    case entry(UUID)
    case url(URL)
    case nothing
}
