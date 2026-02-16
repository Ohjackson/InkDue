import SwiftUI

struct MorningSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: MorningSessionViewModel
    var onSessionCompleted: (() -> Void)?

    init(
        viewModel: MorningSessionViewModel,
        onSessionCompleted: (() -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onSessionCompleted = onSessionCompleted
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                progressSection
                contentSection
            }
            .padding(16)
        }
        .navigationTitle("Morning")
        .onAppear {
            viewModel.send(.onAppear)
        }
        .onChange(of: viewModel.state.didCompleteSession) { _, didComplete in
            guard didComplete else { return }
            onSessionCompleted?()
            dismiss()
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Light recovery session")
                .font(.headline)
            Text("Card \(viewModel.state.progressText)")
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
        if let appErrorBanner = AppErrorHandler.bannerContent(
            for: viewModel.state.appViewState,
            messageOverride: viewModel.state.errorMessage
        ) {
            AppBannerView(
                content: appErrorBanner,
                onAction: { viewModel.send(.reload) },
                onClose: { viewModel.send(.clearError) }
            )
        } else if let errorMessage = viewModel.state.errorMessage {
            AppBannerView(
                content: AppErrorHandler.actionFailureBanner(
                    title: "Morning session failed",
                    message: errorMessage,
                ),
                onAction: { viewModel.send(.reload) },
                onClose: { viewModel.send(.clearError) }
            )
        }

        switch viewModel.state.appViewState {
        case .loading:
            loadingSection

        case .normal:
            if let card = viewModel.state.currentCard {
                cardSection(card)
                reviewButtonsSection
            } else {
                completionSection
            }

        case .empty:
            emptySection
            completionSection

        case .error:
            errorSection
        }
    }

    private var loadingSection: some View {
        VStack(spacing: 8) {
            ProgressView()
            Text("Loading morning queue...")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private func cardSection(_ card: MorningSessionCard) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(card.sourceTitle)
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.14))
                    .clipShape(Capsule())

                Spacer()
                Text("Step \(card.step)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text(card.term)
                .font(.title2.weight(.semibold))

            Text(card.meaning)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var reviewButtonsSection: some View {
        HStack(spacing: 10) {
            Button("Again") {
                viewModel.send(.submitReview(.again))
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.state.canSubmitReview)

            Button("Correct") {
                viewModel.send(.submitReview(.correct))
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.state.canSubmitReview)
        }
    }

    private var completionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Morning summary")
                .font(.headline)
            summaryRow(title: "Reviewed", value: viewModel.state.reviewedCount)
            summaryRow(title: "Correct", value: viewModel.state.correctCount)
            summaryRow(title: "Again", value: viewModel.state.againCount)

            Button("Complete Morning") {
                viewModel.send(.completeSession)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.state.canCompleteSession)
            .padding(.top, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var emptySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Morning queue is empty.")
                .font(.headline)
            Text("Complete this phase to continue with lunch.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var errorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Could not load morning data.")
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
}

#Preview {
    NavigationStack {
        MorningSessionView(
            viewModel: MorningSessionViewModel(repository: AppContainer.live.repository)
        )
    }
}
