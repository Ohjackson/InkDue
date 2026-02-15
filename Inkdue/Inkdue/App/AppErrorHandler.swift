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

    static func bannerContent(for state: AppViewState) -> AppBannerContent? {
        guard case let .error(errorState) = state else {
            return nil
        }
        return bannerContent(for: errorState)
    }
}
