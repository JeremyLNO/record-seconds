import SwiftUI
import SwiftData
import CrazyBeeLicense

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Query(sort: \Project.sortIndex) private var projects: [Project]

    var body: some View {
        NavigationStack {
            Form {
                captureSection
                quickCaptureSection
                languageSection
                notificationsSection
                accountSection
                licenseSection
                supportSection
                Section {
                    BrandFooter()
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle(L.t("settings"))
        }
    }

    // MARK: - Capture

    private var captureSection: some View {
        Section(L.t("settings_capture")) {
            Picker(L.t("settings_video_quality"), selection: $settings.videoQuality) {
                ForEach(VideoQuality.allCases) { quality in
                    Text(quality.label).tag(quality)
                }
            }
            VStack(alignment: .leading) {
                Text(L.t("settings_clip_duration"))
                HStack {
                    Slider(value: $settings.clipDuration, in: 1...3, step: 1)
                    Text(String(format: "%.0fs", settings.clipDuration))
                        .font(.subheadline.monospacedDigit())
                        .frame(width: 32, alignment: .trailing)
                }
            }
        }
    }

    // MARK: - Quick capture

    private var quickCaptureSection: some View {
        Section(L.t("quick_capture_button_label")) {
            Picker(L.t("settings_quick_capture_target"), selection: $settings.quickCaptureMode) {
                ForEach(QuickCaptureMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            if settings.quickCaptureMode == .defaultProject {
                Picker(L.t("quick_capture_mode_default"), selection: $settings.quickCaptureDefaultProjectID) {
                    Text(L.t("settings_no_default_project")).tag(UUID?.none)
                    ForEach(projects) { project in
                        Text(project.name).tag(Optional(project.id))
                    }
                }
            }
        }
    }

    // MARK: - Language

    private var languageSection: some View {
        Section(L.t("settings_language")) {
            Picker(L.t("settings_language"), selection: Binding(
                get: { settings.languageOverride },
                set: { settings.languageOverride = $0 }
            )) {
                Text(L.t("settings_language_system")).tag(AppLanguage?.none)
                ForEach(AppLanguage.allCases) { lang in
                    Text("\(lang.flag) \(lang.name)").tag(Optional(lang))
                }
            }
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        Section(L.t("settings_notifications")) {
            Toggle(L.t("settings_notifications"), isOn: $settings.notificationsEnabled)
                .onChange(of: settings.notificationsEnabled) { _, newValue in
                    OneSignalConfig.setEnabled(newValue)
                }
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        Section {
            NavigationLink(L.t("settings_account")) { AccountView() }
            Text(L.t("account_optional_note"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - License

    private var licenseSection: some View {
        Section(L.t("settings_license")) {
            LicenseSettingsView(manager: AppLicense.manager)
        }
    }

    // MARK: - Support

    private var supportSection: some View {
        Section {
            Link(destination: AppInfo.supportURL) {
                Label(L.t("settings_support_ideas"), systemImage: "questionmark.circle")
            }
        }
    }
}
