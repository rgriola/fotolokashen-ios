import SwiftUI

/// Top-of-screen banner that displays the current `ErrorPresenter.banner`.
struct ErrorBanner: View {
    let error: AppError
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: error.severity.systemImage)
                .foregroundStyle(error.severity.tint)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                if !error.title.isEmpty {
                    Text(error.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                Text(error.message)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if let retry = error.retry {
                Button("Retry") {
                    retry()
                    onDismiss()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.brand)
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(error.severity.tint.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 12)
    }
}

/// View modifier that attaches the global `ErrorPresenter` UI (banner + alert).
/// Apply once at the app root (e.g., on `ContentView`).
struct ErrorPresenterModifier: ViewModifier {
    @ObservedObject private var presenter = ErrorPresenter.shared

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let banner = presenter.banner {
                    ErrorBanner(error: banner) {
                        presenter.dismissBanner()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: presenter.banner)
                    .padding(.top, 8)
                }
            }
            .alert(
                presenter.alert?.title.isEmpty == false ? (presenter.alert?.title ?? "") : "Error",
                isPresented: Binding(
                    get: { presenter.alert != nil },
                    set: { if !$0 { presenter.dismissAlert() } }
                ),
                presenting: presenter.alert
            ) { error in
                if let retry = error.retry {
                    Button("Retry") { retry() }
                }
                Button("OK", role: .cancel) {}
            } message: { error in
                Text(error.message)
            }
    }
}

extension View {
    /// Attach the global `ErrorPresenter` UI (banner + alert) to this view.
    /// Apply once at the app root.
    func errorPresenter() -> some View {
        modifier(ErrorPresenterModifier())
    }
}
