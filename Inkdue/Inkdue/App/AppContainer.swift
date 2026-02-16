import SwiftData

struct AppContainer {
    let modelContainer: ModelContainer
    let repository: any AppRepository
    let syncService: any AppSyncServiceProtocol

    static let live: AppContainer = {
        let schema = Schema([
            Item.self,
            AppState.self,
            WordItem.self,
            WordSRS.self,
            ReviewEvent.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let modelContainer = try ModelContainer(for: schema, configurations: [configuration])
            let repository = SwiftDataAppRepository(modelContainer: modelContainer)
            let syncService = AppSyncService(repository: repository)
            return AppContainer(
                modelContainer: modelContainer,
                repository: repository,
                syncService: syncService
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}
