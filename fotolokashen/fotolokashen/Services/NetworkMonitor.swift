import Foundation
import Network
import Combine

/// Monitors network connectivity status
class NetworkMonitor: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = NetworkMonitor()
    
    // MARK: - Published Properties
    
    @Published var isConnected: Bool = true
    @Published var connectionType: NWInterface.InterfaceType?
    
    // MARK: - Properties
    
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    // MARK: - Initialization
    
    private init() {
        monitor = NWPathMonitor()
        startMonitoring()
    }
    
    // MARK: - Monitoring
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = path.availableInterfaces.first?.type
                
                if ConfigLoader.shared.enableDebugLogging {
                    let status = path.status == .satisfied ? "Connected" : "Disconnected"
                    print("[NetworkMonitor] \(status)")
                    if let type = self?.connectionType {
                        print("[NetworkMonitor] Connection type: \(type)")
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
