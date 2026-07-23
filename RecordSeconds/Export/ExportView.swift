import SwiftUI

struct ExportView: View {
    let project: Project
    @Environment(\.dismiss) private var dismiss

    @State private var progress: Double = 0
    @State private var exportedURL: URL?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                if let exportedURL {
                    successState(url: exportedURL)
                } else if let errorMessage {
                    errorState(message: errorMessage)
                } else {
                    exportingState
                }
                Spacer()
            }
            .padding()
            .navigationTitle(L.t("project_export"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("close")) { dismiss() }
                }
            }
        }
        .task { await runExport() }
    }

    private var exportingState: some View {
        VStack(spacing: 16) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .frame(width: 220)
            Text(L.t("export_in_progress"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func successState(url: URL) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text(L.t("export_saved_to_photos"))
                .font(.headline)
                .multilineTextAlignment(.center)
            ShareLink(item: url) {
                Label(L.t("share"), systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }

    private func runExport() async {
        do {
            let url = try await VideoExporter.exportAndSaveToPhotos(project: project) { value in
                Task { @MainActor in progress = value }
            }
            exportedURL = url
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
