import SwiftUI
import SwiftData

struct ProjectListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.sortIndex) private var projects: [Project]

    @State private var newProjectName = ""
    @State private var isCreating = false
    @State private var isRenaming = false
    @State private var renamingProject: Project?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            Group {
                if projects.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle(L.t("tab_projects"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { isCreating = true } label: { Image(systemName: "plus") }
                }
            }
            .alert(L.t("project_new_title"), isPresented: $isCreating) {
                TextField(L.t("project_name_placeholder"), text: $newProjectName)
                Button(L.t("cancel"), role: .cancel) { newProjectName = "" }
                Button(L.t("add")) { createProject() }
            }
            .alert(L.t("rename"), isPresented: $isRenaming, presenting: renamingProject) { project in
                TextField(L.t("project_name_placeholder"), text: $renameText)
                Button(L.t("cancel"), role: .cancel) {}
                Button(L.t("save")) { project.name = renameText }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(L.t("project_empty_title"))
                .font(.headline)
            Text(L.t("project_empty_message"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button(L.t("project_new_title")) { isCreating = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        List {
            ForEach(projects) { project in
                NavigationLink(value: project) {
                    row(for: project)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { delete(project) } label: {
                        Label(L.t("delete"), systemImage: "trash")
                    }
                    Button {
                        renameText = project.name
                        renamingProject = project
                        isRenaming = true
                    } label: {
                        Label(L.t("rename"), systemImage: "pencil")
                    }
                    .tint(.orange)
                }
            }
            .onMove(perform: move)
        }
        .navigationDestination(for: Project.self) { project in
            ProjectDetailView(project: project)
        }
    }

    private func row(for project: Project) -> some View {
        HStack(spacing: 12) {
            VideoThumbnailView(url: project.orderedClips.first?.fileURL)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name).font(.headline)
                Text(L.clipCount(project.clips.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func createProject() {
        let name = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        newProjectName = ""
        guard !name.isEmpty else { return }
        let project = Project(name: name, sortIndex: (projects.map(\.sortIndex).max() ?? -1) + 1)
        modelContext.insert(project)
    }

    private func delete(_ project: Project) {
        for clip in project.clips { VideoStore.delete(clip) }
        modelContext.delete(project)
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = projects
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, project) in reordered.enumerated() { project.sortIndex = index }
    }
}
