import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel

    init(viewModel: HomeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerSection
                    contentSection
                }
                .padding(16)
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.send(.tapImport)
                    } label: {
                        Label("Import CSV", systemImage: "square.and.arrow.down")
                    }
                }
            }
            .sheet(isPresented: importSheetBinding) {
                CSVImportView(viewModel: viewModel.makeCSVImportViewModel())
            }
            .onAppear {
                viewModel.send(.onAppear)
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Today only.")
                .font(.headline)
            Text(
                "Study Day \(viewModel.state.currentStudyDayIndex) · \(viewModel.state.phaseTitle)"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var contentSection: some View {
        switch viewModel.state.appViewState {
        case let .loading(loadingState):
            loadingSection(loadingState)

        case .normal:
            dashboardSection
            sessionActionSection

        case let .empty(emptyState):
            dashboardSection
            sessionActionSection
            emptySection(emptyState)

        case .error:
            if let bannerContent = AppErrorHandler.bannerContent(for: viewModel.state.appViewState) {
                AppBannerView(
                    content: bannerContent,
                    onAction: { viewModel.send(.reload) },
                    onClose: nil
                )
            }
            retrySection
        }
    }

    private func loadingSection(_ loadingState: AppLoadingState) -> some View {
        VStack(alignment: .center, spacing: 10) {
            ProgressView()
            Text(loadingState == .initialData ? "Loading data..." : "Refreshing...")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }

    private var dashboardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today Overview")
                .font(.headline)

            metricRow(
                title: "Words",
                value: viewModel.state.totalWordCount,
                detail: "Active items"
            )
            metricRow(
                title: "Morning queue",
                value: viewModel.state.morningQueueCount,
                detail: "Failed: \(viewModel.state.morningFailedCount)"
            )
            metricRow(
                title: "Evening queue",
                value: viewModel.state.eveningQueueCount,
                detail: "New: \(viewModel.state.eveningNewCount)"
            )
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var sessionActionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Session")
                .font(.headline)

            if viewModel.state.currentPhase == .morning {
                NavigationLink {
                    MorningSessionView(
                        viewModel: viewModel.makeMorningSessionViewModel(),
                        onSessionCompleted: { viewModel.send(.reload) }
                    )
                } label: {
                    HStack {
                        Text("Start Morning")
                        Spacer()
                        Text("\(viewModel.state.morningQueueCount) cards")
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.state.canStartMorningSession)
            } else if viewModel.state.currentPhase == .lunch {
                NavigationLink {
                    LunchSessionView(
                        viewModel: viewModel.makeLunchSessionViewModel(),
                        onSessionCompleted: { viewModel.send(.reload) }
                    )
                } label: {
                    HStack {
                        Text("Start Lunch")
                        Spacer()
                        Text("New: \(viewModel.state.eveningNewCount)")
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.state.canStartLunchSession)
            } else {
                Text("Current phase is \(viewModel.state.phaseTitle). Morning starts when phase returns to morning.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func metricRow(title: String, value: Int, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.secondary)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(value)")
                .font(.headline.weight(.semibold))
        }
    }

    private func emptySection(_ emptyState: AppEmptyState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            switch emptyState {
            case .noWord:
                Text("No words yet.")
                    .font(.headline)
                Text("Paste CSV to stage new words for today's evening.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case .noQueue:
                Text("Today's queue is empty.")
                    .font(.headline)
                Text("Add words at lunch or import CSV to prepare next sessions.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button("Open CSV Import") {
                viewModel.send(.tapImport)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var retrySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Could not load home data.")
                .font(.headline)
            Text("Try loading again. Local data remains unchanged.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

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

    private var importSheetBinding: Binding<Bool> {
        Binding(
            get: { viewModel.state.isImportSheetPresented },
            set: { isPresented in
                if !isPresented {
                    viewModel.send(.dismissImport)
                }
            }
        )
    }
}

#Preview {
    HomeView(
        viewModel: HomeViewModel(repository: AppContainer.live.repository)
    )
}
