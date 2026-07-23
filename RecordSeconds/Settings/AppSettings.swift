import Foundation
import AVFoundation
import Combine

enum VideoQuality: String, CaseIterable, Identifiable, Codable {
    case sd, hd720, hd1080, uhd4k
    var id: String { rawValue }

    var preset: AVCaptureSession.Preset {
        switch self {
        case .sd: return .vga640x480
        case .hd720: return .hd1280x720
        case .hd1080: return .hd1920x1080
        case .uhd4k: return .hd4K3840x2160
        }
    }

    var label: String {
        switch self {
        case .sd: return "480p"
        case .hd720: return "720p"
        case .hd1080: return "1080p"
        case .uhd4k: return "4K"
        }
    }
}

/// Where the persistent quick-capture button sends a new clip.
enum QuickCaptureMode: String, CaseIterable, Identifiable, Codable {
    case lastUsedProject
    case defaultProject
    var id: String { rawValue }

    var label: String {
        switch self {
        case .lastUsedProject: return L.t("quick_capture_mode_last_used")
        case .defaultProject: return L.t("quick_capture_mode_default")
        }
    }
}

/// App-wide settings, persisted in UserDefaults. A single observable instance is
/// shared across the capture flow and the Settings screen.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Keys {
        static let quality = "settings.videoQuality"
        static let clipDuration = "settings.clipDuration"
        static let quickCaptureMode = "settings.quickCaptureMode"
        static let quickCaptureDefaultProjectID = "settings.quickCaptureDefaultProjectID"
        static let languageOverride = AppLanguage.storageKey
        static let notificationsEnabled = "settings.notificationsEnabled"
    }

    private let defaults: UserDefaults

    @Published var videoQuality: VideoQuality {
        didSet { defaults.set(videoQuality.rawValue, forKey: Keys.quality) }
    }
    /// Fixed recording length, 1-3 seconds.
    @Published var clipDuration: Double {
        didSet { defaults.set(clipDuration, forKey: Keys.clipDuration) }
    }
    @Published var quickCaptureMode: QuickCaptureMode {
        didSet { defaults.set(quickCaptureMode.rawValue, forKey: Keys.quickCaptureMode) }
    }
    @Published var quickCaptureDefaultProjectID: UUID? {
        didSet { defaults.set(quickCaptureDefaultProjectID?.uuidString, forKey: Keys.quickCaptureDefaultProjectID) }
    }
    @Published var languageOverride: AppLanguage? {
        didSet { defaults.set(languageOverride?.rawValue, forKey: Keys.languageOverride) }
    }
    @Published var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.videoQuality = VideoQuality(rawValue: defaults.string(forKey: Keys.quality) ?? "") ?? .hd1080
        let storedDuration = defaults.double(forKey: Keys.clipDuration)
        self.clipDuration = storedDuration > 0 ? storedDuration : 1
        self.quickCaptureMode = QuickCaptureMode(rawValue: defaults.string(forKey: Keys.quickCaptureMode) ?? "") ?? .lastUsedProject
        self.quickCaptureDefaultProjectID = defaults.string(forKey: Keys.quickCaptureDefaultProjectID).flatMap(UUID.init)
        self.languageOverride = defaults.string(forKey: Keys.languageOverride).flatMap(AppLanguage.init)
        self.notificationsEnabled = defaults.object(forKey: Keys.notificationsEnabled) != nil ? defaults.bool(forKey: Keys.notificationsEnabled) : false
    }
}
