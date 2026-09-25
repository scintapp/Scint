import Foundation
import ScintRuntime


enum SearchTool {
    enum Strategy { case research, locate, update }
    enum Target { case content, file, link }

    static func search(_ query: String) async throws -> SearchResults {
        fatalError("TODO")
    }
}
