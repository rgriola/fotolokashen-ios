import AuthenticationServices
import UIKit

final class AuthPresentationContextProvider: NSObject, @MainActor ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let activeScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }

        guard let activeScene,
              let window = activeScene.windows.first(where: { $0.isKeyWindow })
                ?? activeScene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}
