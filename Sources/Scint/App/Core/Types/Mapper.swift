import SwiftUI


@MainActor protocol Mapper {
    static func controls(_ model: any Model) -> Controls
    static func parameters(_ model: any Model) -> Params
}

extension Mapper {
    static func controls(_ model: any Model) -> Controls { .init() }
    static func parameters(_ model: any Model) -> Params { .init() }
}
