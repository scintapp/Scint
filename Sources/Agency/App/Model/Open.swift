import AgencyRuntime
import Foundation


struct Open: Equatable, Sendable {
    var sheets: [Reference] = []
    var transcripts: [Reference] = []
    var sheet: Reference? { sheets.last }

    @discardableResult
    mutating func open(_ ref: Reference) -> Bool {
        switch ref.type {
            case is Sheet.Type:
                if !sheets.contains(ref) { sheets.append(ref) }
                return true
            case is Transcript.Type:
                if !transcripts.contains(ref) { transcripts.append(ref) }
                return true
            default:
                return false
        }
    }

    @discardableResult
    mutating func close(_ ref: Reference) -> Bool {
        let sheetsCount = sheets.count
        let transcriptsCount = transcripts.count
        sheets.removeAll { $0 == ref }
        transcripts.removeAll { $0 == ref }
        return sheets.count != sheetsCount || transcripts.count != transcriptsCount
    }
}
