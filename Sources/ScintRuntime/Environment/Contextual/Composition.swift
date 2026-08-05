import Foundation


public struct Composition: Codable, Sendable {
    let structure: Reference

    enum State: Codable, Sendable, Equatable { case inactive, active, running, completed, failed }

    var context: Context? { Composer.shared.context(origin) }
    var intents: [Context.Intent] { context?.intents ?? [] }
    var harness: Reference? { context?.harness?.ref }
    var transcript: Reference { context?.transcript ?? origin }

    var state: State {
        guard let context else { return .inactive }
        if !context.intents.isEmpty { return .running }
        guard let signal = Transcript.with(context.transcript, { transcript in
            transcript.entries.reversed().compactMap { entry -> Signal? in
                guard case .signal(let signal, _, _) = entry else { return nil }
                return signal
            }.first
        }) ?? nil else { return .active }

        switch signal {
            case .composed:
                return .inactive

            case .started, .updated:
                return .active

            case .completed:
                return .completed

            case .failed:
                return .failed
        }
    }
}
