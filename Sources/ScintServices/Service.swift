import Darwin
import Foundation
import ScintRuntime


final class ServiceDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: ServiceProviding.self)
        newConnection.remoteObjectInterface = NSXPCInterface(with: ServiceHandling.self)
        let daemon = ServiceDaemon(connection: newConnection)
        newConnection.exportedObject = daemon
        newConnection.invalidationHandler = { NSLog("Client connection invalidated") }
        newConnection.resume()
        return true
    }
}

@main
struct Service {
    static func main() {
        _ = ProcessStore.shared
        let listener = NSXPCListener(machServiceName: "com.kaechle.scintd")
        let delegate = ServiceDelegate()
        listener.delegate = delegate
        listener.resume()
        RunLoop.main.run()
    }
}

