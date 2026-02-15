import SwiftData

struct AppContainer {
    let modelContainer: ModelContainer

    static let live: AppContainer = {
        let schema = Schema([
            Item.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let modelContainer = try ModelContainer(for: schema, configurations: [configuration])
            return AppContainer(modelContainer: modelContainer)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}
