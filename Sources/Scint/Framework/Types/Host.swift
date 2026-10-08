import SwiftUI
import ScintRuntime


typealias Values = [AnyHashable: AnyHashable]

protocol HostSurface: CaseIterable, Identifiable {}

@MainActor protocol Host: AnyObject {
    associatedtype HostSurface
    var state: StateContainer { get set }
    var surface: HostSurface { get set }
    func controls(_ model: any Model) -> Controls
    func parameters(_ model: any Model) -> Params
}

extension Host {
    func controls(_ model: any Model) -> Controls { .init() }
    func parameters(_ model: any Model) -> Params { .init() }

    var bindable: Bindable<StateContainer> {
        @Bindable var state = self.state
        return $state
    }
}

protocol Frame: Host {
    associatedtype Surface
    func surface(_ model: AppModel) -> Surface
}

protocol Panel: Host {
    associatedtype Surface
    func surface(_ model: any Model) -> Surface
}
