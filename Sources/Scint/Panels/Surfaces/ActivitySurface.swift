import SwiftUI


extension Harness.Intent {
    var forms: (label: String, running: String, completed: String) {
        switch self {
            case .compose: ("Compose", "Composing", "Composed")
            case .dispatch: ("Dispatch", "Dispatching", "Dispatched")
            case .observe: ("Observe", "Observing", "Observed")
            case .evaluate: ("Evaluate", "Evaluating", "Evaluated")
            case .search: ("Research", "Researching", "Researched")
        }
    }
}

