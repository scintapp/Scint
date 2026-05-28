import AgencyRuntime
import Foundation
import Darwin


final class HarnessDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: HarnessProviding.self)
        newConnection.remoteObjectInterface = NSXPCInterface(with: HarnessHandling.self)
        let daemon = HarnessDaemon(connection: newConnection)
        newConnection.exportedObject = daemon
        newConnection.invalidationHandler = { NSLog("Client connection invalidated") }
        newConnection.resume()
        return true
    }
}

@main
struct Harness {
    static func main() {
        _ = ProcessStore.shared
        let listener = NSXPCListener(machServiceName: "com.kaechle.agencyd")
        let delegate = HarnessDelegate()
        listener.delegate = delegate
        listener.resume()
        RunLoop.main.run()
    }
}

