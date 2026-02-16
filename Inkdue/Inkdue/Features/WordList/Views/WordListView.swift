import SwiftUI

struct WordListView: View {
    @StateObject private var viewModel: WordListViewModel
    var onListChanged: (() -> Void)?

    init(
        viewModel: WordListViewModel,
        onListChanged: (() -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onListChanged = onListChanged
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                controlsSection
                contentSection
            }
            .padding(16)
        }
        .navigationTitle("Word List")
        .onAppear {
            viewModel.send(.onAppear)
        }
    }

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Search term or meaning", text: searchTextBinding)
                .textFieldStyle(.roundedBorder)

            Toggle("Include archived", isOn: includeArchivedBinding)
                .font(.subheadline)

            Text("Study Day \(viewModel.state.currentStudyDayIndex)")
                .font(.footnote)
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
                    title: "Word list failed",
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
                Text("Loading word list...")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 220)

        case .normal:
            rowsSection

        case .empty:
            emptySection

        case .error:
            VStack(alignment: .leading, spacing: 8) {
                Text("Could not load words.")
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

    @ViewBuilder
    private var rowsSection: some View {
        let rows = viewModel.state.filteredRows
        if rows.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("No words matched.")
                    .font(.headline)
                Text("Adjust search text or archived filter.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            VStack(spacing: 10) {
                ForEach(rows) { row in
                    NavigationLink {
                        WordDetailView(
                            viewModel: viewModel.makeWordDetailViewModel(wordId: row.id),
                            onWordChanged: {
                                viewModel.send(.reload)
                                onListChanged?()
                            }
                        )
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(row.term)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(row.meaning)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(row.subtitle)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.top, 6)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No words yet.")
                .font(.headline)
            Text("Import CSV from Home to create your first words.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var searchTextBinding: Binding<String> {
        Binding(
            get: { viewModel.state.searchText },
            set: { viewModel.send(.updateSearchText($0)) }
        )
    }

    private var includeArchivedBinding: Binding<Bool> {
        Binding(
            get: { viewModel.state.includeArchived },
            set: { viewModel.send(.setIncludeArchived($0)) }
        )
    }
}

#Preview {
    NavigationStack {
        WordListView(viewModel: WordListViewModel(repository: AppContainer.live.repository))
    }
}
