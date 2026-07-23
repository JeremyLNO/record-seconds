import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.sortIndex) private var projects: [Project]
    @StateObject private var settings = AppSettings.shared
    @StateObject private var reviewPrompt = ReviewPromptManager()

    @State private var quickCaptureTarget: Project?
    @State private var showNeedsProjectAlert = false

    var body: some View {
        TabView {
            ProjectListView()
                .tabItem { Label(L.t("tab_projects"), systemImage: "square.stack.3d.up.fill") }
            SettingsView()
                .tabItem { Label(L.t("tab_settings"), systemImage: "gearshape.fill") }
        }
        .overlay(alignment: .bottom) {
            QuickCaptureButton { startQuickCapture() }
                .padding(.bottom, 64)
        }
        .fullScreenCover(item: $quickCaptureTarget) { project in
            CameraCaptureView(project: project)
        }
        .alert(L.t("quick_capture_needs_project_title"), isPresented: $showNeedsProjectAlert) {
            Button(L.t("done")) {}
        } message: {
            Text(L.t("quick_capture_needs_project_message"))
        }
        .onAppear {
            seedDefaultProjectIfNeeded()
            reviewPrompt.presentIfDue()
        }
        .sheet(isPresented: $reviewPrompt.isPresented) {
            ReviewPromptView(manager: reviewPrompt)
        }
    }

    /// First-ever launch: pre-create one project so the app isn't empty and quick
    /// capture always has somewhere to go. Gated by a UserDefaults flag rather than
    /// `projects.isEmpty` so deliberately deleting all projects later doesn't bring
    /// this one back.
    private func seedDefaultProjectIfNeeded() {
        let key = "seeding.hasCreatedDefaultProject"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        guard projects.isEmpty else { return }
        modelContext.insert(Project(name: "my video project", sortIndex: 0))
    }

    private func startQuickCapture() {
        guard !projects.isEmpty else {
            showNeedsProjectAlert = true
            return
        }
        switch settings.quickCaptureMode {
        case .lastUsedProject:
            quickCaptureTarget = projects.max { $0.lastUsedAt < $1.lastUsedAt }
        case .defaultProject:
            if let id = settings.quickCaptureDefaultProjectID,
               let match = projects.first(where: { $0.id == id }) {
                quickCaptureTarget = match
            } else {
                quickCaptureTarget = projects.max { $0.lastUsedAt < $1.lastUsedAt }
            }
        }
    }
}
