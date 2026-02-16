import SwiftUI

struct WordDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: WordDetailViewModel
    var onWordChanged: (() -> Void)?

    init(
        viewModel: WordDetailViewModel,
        onWordChanged: (() -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onWordChanged = onWordChanged
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                formSection
                archiveSection
            }
            .padding(16)
        }
        .navigationTitle("Word Detail")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    viewModel.send(.saveChanges)
                }
                .disabled(!viewModel.state.canSave)
            }
        }
        .onAppear {
            viewModel.send(.onAppear)
        }
        .onChange(of: viewModel.state.changeToken) { _, _ in
            onWordChanged?()
        }
        .onChange(of: viewModel.state.didArchiveAndClose) { _, didClose in
            guard didClose else { return }
            dismiss()
        }
    }

    @ViewBuilder
    private var formSection: some View {
        if let errorMessage = viewModel.state.errorMessage {
            AppBannerView(
                content: AppBannerContent(
                    style: .error,
                    title: "Word update failed",
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
            VStack(spacing: 8) {
                ProgressView()
                Text("Loading word detail...")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 180)

        case .normal, .empty:
            VStack(alignment: .leading, spacing: 12) {
                field(title: "Term", text: termBinding)
                field(title: "Meaning", text: meaningBinding)
                editorField(title: "Example", text: exampleBinding, minHeight: 90)
                editorField(title: "Example Meaning", text: exampleMeaningBinding, minHeight: 90)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

        case .error:
            VStack(alignment: .leading, spacing: 8) {
                Text("Could not load word detail.")
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
    }

    private var archiveSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.state.isArchived {
                Text("This word is archived.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Unarchive") {
                    viewModel.send(.unarchiveWord)
                }
                .buttonStyle(.bordered)
            } else {
                Text("Archive removes this word from learning queues.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Archive") {
                    viewModel.send(.archiveWord)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func field(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func editorField(title: String, text: Binding<String>, minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            TextEditor(text: text)
                .frame(minHeight: minHeight)
                .padding(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
        }
    }

    private var termBinding: Binding<String> {
        Binding(
            get: { viewModel.state.term },
            set: { viewModel.send(.updateTerm($0)) }
        )
    }

    private var meaningBinding: Binding<String> {
        Binding(
            get: { viewModel.state.meaning },
            set: { viewModel.send(.updateMeaning($0)) }
        )
    }

    private var exampleBinding: Binding<String> {
        Binding(
            get: { viewModel.state.example },
            set: { viewModel.send(.updateExample($0)) }
        )
    }

    private var exampleMeaningBinding: Binding<String> {
        Binding(
            get: { viewModel.state.exampleMeaning },
            set: { viewModel.send(.updateExampleMeaning($0)) }
        )
    }
}

#Preview {
    NavigationStack {
        WordDetailView(
            viewModel: WordDetailViewModel(
                repository: AppContainer.live.repository,
                wordId: UUID()
            )
        )
    }
}
