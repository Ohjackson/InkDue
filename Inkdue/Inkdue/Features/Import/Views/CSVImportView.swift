import SwiftUI

struct CSVImportView: View {
    @StateObject private var viewModel: CSVImportViewModel

    init(viewModel: CSVImportViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    inputSection
                    actionSection
                    previewSection
                    resultSection
                }
                .padding(16)
            }
            .navigationTitle("CSV Import")
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Paste CSV")
                .font(.headline)

            TextEditor(text: rawTextBinding)
                .frame(minHeight: 180)
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
        }
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Button("Preview") {
                    viewModel.send(.buildPreview)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.state.canPreview)

                Button("Confirm") {
                    viewModel.send(.confirmImport)
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.state.canConfirm)
            }

            if let errorMessage = viewModel.state.errorMessage {
                AppBannerView(
                    content: AppErrorHandler.actionFailureBanner(
                        title: "Import failed",
                        message: errorMessage,
                        actionTitle: nil
                    ),
                    onAction: nil,
                    onClose: { viewModel.send(.clearError) }
                )
            }
        }
    }

    private var previewSection: some View {
        Group {
            if let preview = viewModel.state.preview {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Preview Summary")
                        .font(.headline)

                    summaryRow(title: "Added", value: preview.summary.addedCount)
                    summaryRow(
                        title: "Skipped duplicates",
                        value: preview.summary.skippedDuplicateCount
                    )
                    summaryRow(
                        title: "Skipped invalid",
                        value: preview.summary.skippedInvalidCount
                    )

                    if !preview.ignoredColumns.isEmpty {
                        Text("Ignored columns: \(preview.ignoredColumns.joined(separator: ", "))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var resultSection: some View {
        Group {
            if let result = viewModel.state.lastCommitResult {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Import Result")
                        .font(.headline)

                    summaryRow(title: "Added", value: result.addedCount)
                    summaryRow(
                        title: "Skipped duplicates",
                        value: result.skippedDuplicateCount
                    )
                    summaryRow(
                        title: "Skipped invalid",
                        value: result.skippedInvalidCount
                    )
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func summaryRow(title: String, value: Int) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(value)")
                .fontWeight(.semibold)
        }
        .font(.subheadline)
    }

    private var rawTextBinding: Binding<String> {
        Binding(
            get: { viewModel.state.rawText },
            set: { viewModel.send(.updateRawText($0)) }
        )
    }
}

#Preview {
    CSVImportView(
        viewModel: CSVImportViewModel(
            repository: AppContainer.live.repository
        )
    )
}
