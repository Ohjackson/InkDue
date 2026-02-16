import SwiftUI

struct LunchSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: LunchSessionViewModel
    var onSessionCompleted: (() -> Void)?

    init(
        viewModel: LunchSessionViewModel,
        onSessionCompleted: (() -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onSessionCompleted = onSessionCompleted
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                contentSection
            }
            .padding(16)
        }
        .navigationTitle("Lunch")
        .sheet(isPresented: importSheetBinding) {
            CSVImportView(viewModel: viewModel.makeCSVImportViewModel())
        }
        .onAppear {
            viewModel.send(.onAppear)
        }
        .onChange(of: viewModel.state.didCompleteSession) { _, didComplete in
            guard didComplete else { return }
            onSessionCompleted?()
            dismiss()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Add words for tonight")
                .font(.headline)
            Text("Study Day \(viewModel.state.currentStudyDayIndex)")
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
        if let errorMessage = viewModel.state.errorMessage {
            AppBannerView(
                content: AppBannerContent(
                    style: .error,
                    title: "Lunch session failed",
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

        case .normal:
            projectionSection
            importSection
            completeSection

        case let .empty(emptyState):
            projectionSection
            emptySection(emptyState)
            importSection
            completeSection

        case .error:
            errorSection
        }
    }

    private var loadingSection: some View {
        VStack(spacing: 8) {
            ProgressView()
            Text("Loading lunch data...")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private var projectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Projected Evening Queue")
                .font(.headline)
            summaryRow(title: "Total queue", value: viewModel.state.projectedEveningQueueCount)
            summaryRow(title: "New words", value: viewModel.state.projectedEveningNewCount)
            Text(
                "Policy: max \(SchedulerPolicy.eveningQueueCap) queue, up to \(SchedulerPolicy.maxNewPerStudyDay) new per study day."
            )
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var importSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Import")
                .font(.headline)
            Text("Paste CSV to stage new words for this evening.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Open CSV Import") {
                viewModel.send(.tapImport)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.state.canOpenImport)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var completeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("When import is done, move to evening.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Complete Lunch") {
                viewModel.send(.completeSession)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.state.canCompleteSession)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func emptySection(_ emptyState: AppEmptyState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            switch emptyState {
            case .noWord:
                Text("No words yet.")
                    .font(.headline)
                Text("Import CSV now to create today's evening queue.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case .noQueue:
                Text("Lunch queue is empty.")
                    .font(.headline)
                Text("Import words to stage new evening items.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var errorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Could not load lunch data.")
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

    private func summaryRow(title: String, value: Int) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(value)")
                .fontWeight(.semibold)
        }
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
    NavigationStack {
        LunchSessionView(
            viewModel: LunchSessionViewModel(repository: AppContainer.live.repository)
        )
    }
}
