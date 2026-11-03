import UIKit

/// Screen-level orientation control. SwiftUI has no per-view orientation API,
/// so the app delegate reports `supported` and screens request changes here.
enum AppOrientation {
    private static var isPhone: Bool { UIDevice.current.userInterfaceIdiom == .phone }

    private(set) static var supported: UIInterfaceOrientationMask =
        UIDevice.current.userInterfaceIdiom == .phone ? .allButUpsideDown : .all

    /// Locks iPhone to portrait while `locked` is true. iPad is never locked.
    static func setPortraitLocked(_ locked: Bool) {
        guard isPhone else { return }
        let mask: UIInterfaceOrientationMask = locked ? .portrait : .allButUpsideDown
        guard mask != supported else { return }
        supported = mask

        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            if locked {
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
            }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        AppOrientation.supported
    }
}
