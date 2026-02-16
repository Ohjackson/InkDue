import Foundation

enum AppErrorHandler {
    static func bannerContent(for error: AppErrorState) -> AppBannerContent {
        switch error {
        case .sync:
            return AppBannerContent(
                style: .warning,
                title: "Sync failed",
                message: "Sync stopped, but local study is still available.",
                actionTitle: "Retry",
                isBlocking: false
            )

        case .save:
            return AppBannerContent(
                style: .error,
                title: "Save failed",
                message: "Could not save changes to local storage.",
                actionTitle: "Retry",
                isBlocking: true
            )

        case .dataCorruption:
            return AppBannerContent(
                style: .error,
                title: "Data unavailable",
                message: "Data could not be loaded. Recovery is required.",
                actionTitle: "Recover",
                isBlocking: true
            )
        }
    }

    static func bannerContent(
        for state: AppViewState,
        messageOverride: String? = nil
    ) -> AppBannerContent? {
        guard case let .error(errorState) = state else {
            return nil
        }

        let base = bannerContent(for: errorState)
        guard let messageOverride, !messageOverride.isEmpty else {
            return base
        }

        return AppBannerContent(
            style: base.style,
            title: base.title,
            message: messageOverride,
            actionTitle: base.actionTitle,
            isBlocking: base.isBlocking
        )
    }

    static func actionFailureBanner(
        title: String,
        message: String,
        actionTitle: String? = "Retry"
    ) -> AppBannerContent {
        AppBannerContent(
            style: .error,
            title: title,
            message: message,
            actionTitle: actionTitle,
            isBlocking: false
        )
    }
}
