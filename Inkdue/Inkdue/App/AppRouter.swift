import SwiftUI

struct AppRouter {
    @ViewBuilder
    func makeRootView(
        repository: any AppRepository,
        syncService: any AppSyncServiceProtocol
    ) -> some View {
        HomeView(
            viewModel: HomeViewModel(
                repository: repository,
                syncService: syncService
            )
        )
    }
}
