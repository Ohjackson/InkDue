import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel

    init(viewModel: SettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                contentSection
            }
            .padding(16)
        }
        .navigationTitle("Settings")
        .onAppear {
            viewModel.send(.onAppear)
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        if let errorMessage = viewModel.state.errorMessage {
            AppBannerView(
                content: AppBannerContent(
                    style: .error,
                    title: "Settings load failed",
                    message: errorMessage,
                    actionTitle: "Retry",
                    isBlocking: false
                ),
                onAction: { viewModel.send(.reload) },
                onClose: { viewModel.send(.clearError) }
            )
        }

        switch viewModel.state.appViewState {
        case .loading:
            loadingSection

        case .normal, .empty:
            syncSection
            preferencesSection
            dataSection
            aboutSection

        case .error:
            errorSection
        }
    }

    private var loadingSection: some View {
        VStack(spacing: 8) {
            ProgressView()
            Text("Loading settings...")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }

    private var syncSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sync")
                .font(.headline)

            settingRow(title: "Status", value: viewModel.state.syncStatusMessage)

            if let lastSyncAttemptAt = viewModel.state.lastSyncAttemptAt {
                settingRow(
                    title: "Last attempt",
                    value: lastSyncAttemptAt.formatted(
                        Date.FormatStyle(date: .abbreviated, time: .shortened)
                    )
                )
            } else {
                settingRow(title: "Last attempt", value: "Not yet")
            }

            if let lastSyncSuccessAt = viewModel.state.lastSyncSuccessAt {
                settingRow(
                    title: "Last success",
                    value: lastSyncSuccessAt.formatted(
                        Date.FormatStyle(date: .abbreviated, time: .shortened)
                    )
                )
            } else {
                settingRow(title: "Last success", value: "Not yet")
            }

            settingRow(title: "Retry count", value: "\(viewModel.state.syncRetryCount)")

            Button(viewModel.state.manualSyncButtonTitle) {
                viewModel.send(.runManualSync)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.state.canRunManualSync)

            Text("Manual sync has a short cooldown to avoid repeated retries.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preferences")
                .font(.headline)

            settingRow(
                title: "Max New Per Study Day",
                value: "\(SchedulerPolicy.maxNewPerStudyDay)"
            )
            settingRow(
                title: "Evening Queue Cap",
                value: "\(SchedulerPolicy.eveningQueueCap)"
            )
            settingRow(
                title: "Failed Chunk Cap",
                value: "\(SchedulerPolicy.maxFailedChunk)"
            )
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Data")
                .font(.headline)

            settingRow(title: "Study Day", value: "\(viewModel.state.currentStudyDayIndex)")
            settingRow(title: "Current Phase", value: viewModel.state.phaseTitle)
            settingRow(title: "Active Words", value: "\(viewModel.state.activeWordCount)")
            settingRow(title: "Archived Words", value: "\(viewModel.state.archivedWordCount)")
            settingRow(title: "Reviewed Today", value: "\(viewModel.state.todayReviewCount)")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(.headline)

            settingRow(title: "Version", value: viewModel.state.appVersion)
            settingRow(title: "Build", value: viewModel.state.buildNumber)
            settingRow(title: "Bundle ID", value: viewModel.state.bundleIdentifier)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var errorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Could not load settings.")
                .font(.headline)
            Button("Retry") {
                viewModel.send(.reload)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func settingRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

#Preview {
    NavigationStack {
        SettingsView(
            viewModel: SettingsViewModel(
                repository: AppContainer.live.repository,
                syncService: AppContainer.live.syncService
            )
        )
    }
}
