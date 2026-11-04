import Foundation
import Network
import Observation

/// Monitors network connectivity status
@Observable
@MainActor
final class NetworkMonitor {
    
    // MARK: - Singleton
    
    static let shared = NetworkMonitor()
    
    // MARK: - Observable Properties
    
    var isConnected = true
    var connectionType: NWInterface.InterfaceType?
    
    // MARK: - Properties
    
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    // MARK: - Initialization
    
    private init() {
        monitor = NWPathMonitor()
        startMonitoring()
    }

    init(startMonitoring: Bool) {
        monitor = NWPathMonitor()
        if startMonitoring {
            self.startMonitoring()
        }
    }
    
    // MARK: - Monitoring
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            let isConnected = path.status == .satisfied
            let connectionType = path.availableInterfaces.first?.type
            DispatchQueue.main.async {
                guard let self else { return }
                self.isConnected = isConnected
                self.connectionType = connectionType

                if ConfigLoader.shared.enableDebugLogging {
                    let status = isConnected ? "Connected" : "Disconnected"
                    dlog("NetworkMonitor", "\(status)")
                    if let type = connectionType {
                        dlog("NetworkMonitor", "Connection type: \(type)")
                    }
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    /// Stop monitoring
    func stopMonitoring() {
        monitor.cancel()
    }
    
    deinit {
        monitor.cancel()
    }
}
