import SwiftUI

struct AppBannerContent: Equatable {
    let style: AppBannerStyle
    let title: String
    let message: String
    let actionTitle: String?
    let isBlocking: Bool
}

enum AppBannerStyle: Equatable {
    case info
    case warning
    case error

    var iconName: String {
        switch self {
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.octagon.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }

    var backgroundColor: Color {
        tintColor.opacity(0.12)
    }
}

struct AppBannerView: View {
    let content: AppBannerContent
    var onAction: (() -> Void)?
    var onClose: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: content.style.iconName)
                .font(.headline)
                .foregroundStyle(content.style.tintColor)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(content.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(content.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let actionTitle = content.actionTitle, let onAction {
                    Button(actionTitle, action: onAction)
                        .font(.footnote.weight(.semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(content.style.tintColor)
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 8)

            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(content.style.backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(content.style.tintColor.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

#Preview {
    VStack(spacing: 0) {
        AppBannerView(
            content: AppBannerContent(
                style: .warning,
                title: "Sync paused",
                message: "Network is unstable. Continue with local data.",
                actionTitle: "Retry",
                isBlocking: false
            ),
            onAction: {},
            onClose: {}
        )

        Spacer()
    }
}
