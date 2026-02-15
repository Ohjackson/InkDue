import SwiftUI

struct AppRouter {
    @ViewBuilder
    func makeRootView(repository: any AppRepository) -> some View {
        CSVImportView(
            viewModel: CSVImportViewModel(repository: repository)
        )
    }
}
