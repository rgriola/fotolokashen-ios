import SwiftUI
import UIKit

// MARK: - Profile Banner

/// Reusable banner view for profile headers.
/// - `bannerURL`: optional URL for the banner image
/// - `onEdit`: if provided, shows a camera edit button (owner mode)
/// - `onDelete`: if provided (and banner exists), shows a delete X button (owner mode)
struct ProfileBannerView: View {
    let bannerURL: URL?
    var hasBannerImage: Bool = false
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?

    var body: some View {
        Group {
            if let bannerURL {
                AsyncImage(url: bannerURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 120)
                            .clipped()
                    case .failure:
                        bannerPlaceholder
                    default:
                        bannerPlaceholder
                            .overlay(ProgressView())
                    }
                }
            } else {
                bannerPlaceholder
            }
        }
        .overlay(alignment: .topTrailing) {
            if hasBannerImage, let onDelete {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                        .padding(8)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .clipped()
    }

    private var bannerPlaceholder: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.brandPurple.opacity(0.6), .brandPurple.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: 120)
    }
}

// MARK: - Profile Avatar

/// Reusable avatar view for profile headers.
/// - `avatarURL`: optional URL for the avatar image
/// - `initials`: fallback text shown in the circle placeholder
/// - `onEdit`: if provided, shows a camera overlay button (owner mode)
/// - `editMenuContent`: if provided, attaches a context menu (owner mode)
struct ProfileAvatarView<MenuContent: View>: View {
    let avatarURL: URL?
    let initials: String
    var onEdit: (() -> Void)?
    var editMenuContent: (() -> MenuContent)?

    var body: some View {
        let avatarContent = ZStack(alignment: .bottomTrailing) {
            Group {
                if let avatarURL {
                    AsyncImage(url: avatarURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 68, height: 68)
                                .clipped()
                        case .failure:
                            avatarPlaceholder
                        default:
                            avatarPlaceholder
                                .overlay(ProgressView())
                        }
                    }
                } else {
                    avatarPlaceholder
                }
            }
            .frame(width: 68, height: 68)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 3))

            if let onEdit {
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                        .padding(5)
                        .background(Color.brandPurple)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                }
                .offset(x: 2, y: 2)
            }
        }

        if let editMenuContent {
            avatarContent
                .contextMenu { editMenuContent() }
        } else {
            avatarContent
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color.brandPurple)
            .frame(width: 68, height: 68)
            .overlay(
                Text(initials)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            )
    }
}

/// Convenience initializer without context menu
extension ProfileAvatarView where MenuContent == EmptyView {
    init(avatarURL: URL?, initials: String, onEdit: (() -> Void)? = nil) {
        self.avatarURL = avatarURL
        self.initials = initials
        self.onEdit = onEdit
        self.editMenuContent = nil
    }
}

// MARK: - Profile Stat Item

/// Reusable stat display (count + label) used in followers/following bars.
struct ProfileStatItem: View {
    let count: Int
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Form Field

/// Reusable labeled text field / text editor for profile forms.
struct FormField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var isMultiline: Bool = false
    var maxLength: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            if isMultiline {
                TextEditor(text: $text)
                    .frame(minHeight: 80, maxHeight: 120)
                    .padding(4)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                    .onChange(of: text) { _, newValue in
                        if maxLength > 0 && newValue.count > maxLength {
                            text = String(newValue.prefix(maxLength))
                        }
                    }
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: text) { _, newValue in
                        if maxLength > 0 && newValue.count > maxLength {
                            text = String(newValue.prefix(maxLength))
                        }
                    }
            }

            if maxLength > 0 {
                Text("\(text.count)/\(maxLength)")
                    .font(.caption2)
                    .foregroundColor(text.count >= maxLength ? .destructive : .secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}

// MARK: - Image Picker

/// UIImagePickerController wrapper for selecting photos from the library.
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        picker.sourceType = .photoLibrary
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let edited = info[.editedImage] as? UIImage {
                parent.image = edited
            } else if let original = info[.originalImage] as? UIImage {
                parent.image = original
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
