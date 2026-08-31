import Observation


/// Which reference is currently selected, so an inline one can show it.
///
/// Inline references live inside an `NSHostingView` owned by the layout manager, with no path to
/// the document's environment, so the selection is published here instead. Document UI state — it
/// rode along on the router for a while, which was convenient and wrong.
@Observable @MainActor final class ReferenceSelection {
    static let shared = ReferenceSelection()
    var selected: Reference?

    private init() {}
}
