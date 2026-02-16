import SwiftUI

struct AppRouter {
    @ViewBuilder
    func makeRootView(repository: any AppRepository) -> some View {
        HomeView(
            viewModel: HomeViewModel(repository: repository)
        )
    }
}
