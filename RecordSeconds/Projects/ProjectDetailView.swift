import SwiftUI
import SwiftData

struct ProjectDetailView: View {
    @Bindable var project: Project

    @Environment(\.modelContext) private var modelContext
    @State private var editMode: EditMode = .inactive
    @State private var selection = Set<PersistentIdentifier>()
    @State private var playingClip: Clip?
    @State private var showStyle = false
    @State private var showPreview = false
    @State private var showExport = false

    var body: some View {
        Group {
            if project.orderedClips.isEmpty {
                emptyState
            } else {
                clipList
            }
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { project.lastUsedAt = Date() }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if editMode == .active {
                    Button(role: .destructive) { deleteSelected() } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(selection.isEmpty)
                }
                EditButton()
                Menu {
                    Button { showStyle = true } label: { Label(L.t("project_style"), systemImage: "paintbrush") }
                    Button { showPreview = true } label: { Label(L.t("project_preview"), systemImage: "play.rectangle") }
                        .disabled(project.orderedClips.isEmpty)
                    Button { showExport = true } label: { Label(L.t("project_export"), systemImage: "square.and.arrow.up") }
                        .disabled(project.orderedClips.isEmpty)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .environment(\.editMode, $editMode)
        .sheet(item: $playingClip) { clip in
            ClipPlayerSheet(clip: clip)
        }
        .sheet(isPresented: $showStyle) { ProjectStyleView(project: project) }
        .sheet(isPresented: $showPreview) { ProjectPreviewPlayer(project: project) }
        .sheet(isPresented: $showExport) { ExportView(project: project) }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.badge.plus")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(L.t("project_no_clips_title"))
                .font(.headline)
            Text(L.t("project_no_clips_message"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var clipList: some View {
        List(selection: $selection) {
            ForEach(project.orderedClips) { clip in
                HStack(spacing: 12) {
                    VideoThumbnailView(url: clip.fileURL)
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: "%.0fs", clip.duration)).font(.headline)
                        Text(clip.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture { if editMode == .inactive { playingClip = clip } }
                .tag(clip.persistentModelID)
            }
            .onMove(perform: move)
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = project.orderedClips
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, clip) in reordered.enumerated() { clip.sortIndex = index }
    }

    private func deleteSelected() {
        let toDelete = project.clips.filter { selection.contains($0.persistentModelID) }
        for clip in toDelete {
            VideoStore.delete(clip)
            modelContext.delete(clip)
        }
        selection.removeAll()
        editMode = .inactive
    }
}

private struct ClipPlayerSheet: View {
    let clip: Clip
    var body: some View {
        ClipPlayerView(url: clip.fileURL)
            .ignoresSafeArea()
    }
}
