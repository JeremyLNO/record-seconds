import Foundation
import SwiftData

/// A transition played between every clip (and around the intro/end screens) when
/// previewing or exporting a project. `.dissolve` is a plain AVFoundation opacity
/// ramp on overlapping tracks — no custom video compositor needed.
enum TransitionType: String, CaseIterable, Identifiable, Codable {
    case cut
    case dissolve
    var id: String { rawValue }

    var duration: TimeInterval {
        switch self {
        case .cut: return 0
        case .dissolve: return 0.35
        }
    }

    var label: String {
        switch self {
        case .cut: return L.t("transition_cut")
        case .dissolve: return L.t("transition_dissolve")
        }
    }
}

/// Look of a generated title card: either the default Crazy Bee Labs honeycomb pattern
/// or a plain solid colour.
enum TitleCardTheme: String, CaseIterable, Identifiable, Codable {
    case honeycomb
    case solid
    var id: String { rawValue }

    var label: String {
        switch self {
        case .honeycomb: return L.t("card_theme_honeycomb")
        case .solid: return L.t("card_theme_solid")
        }
    }
}

/// A generated title card (intro or end screen): text over the honeycomb pattern by
/// default, or over `colorHex` when the solid theme is picked.
struct TitleCardStyle: Codable, Equatable {
    var text: String
    var colorHex: String
    var duration: TimeInterval
    /// Optional so cards persisted before themes existed still decode — those predate the
    /// honeycomb look and are treated as the new default.
    private var themeRaw: String?

    var theme: TitleCardTheme {
        get { themeRaw.flatMap(TitleCardTheme.init) ?? .honeycomb }
        set { themeRaw = newValue.rawValue }
    }

    init(text: String, colorHex: String, duration: TimeInterval, theme: TitleCardTheme = .honeycomb) {
        self.text = text
        self.colorHex = colorHex
        self.duration = duration
        self.themeRaw = theme.rawValue
    }

    static func intro(named projectName: String) -> TitleCardStyle {
        TitleCardStyle(text: projectName, colorHex: "1C1C1E", duration: 1.5)
    }

    static func end() -> TitleCardStyle {
        TitleCardStyle(text: L.t("title_card_end_default"), colorHex: "1C1C1E", duration: 1.5)
    }
}

@Model
final class Project {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
    /// Position in the project list; lower sorts first.
    var sortIndex: Int = 0
    /// Last time this project was opened or captured into — used for "last used project"
    /// quick-capture routing.
    var lastUsedAt: Date = Date()

    var transitionRaw: String = TransitionType.dissolve.rawValue
    private var introCardData: Data?
    private var endCardData: Data?

    /// Intro/end cards can be switched off, but only with a license — `VideoExporter`
    /// re-imposes them on the free trial rather than trusting these flags.
    var includesIntroCard: Bool = true
    var includesEndCard: Bool = true

    @Relationship(deleteRule: .cascade, inverse: \Clip.project)
    var clips: [Clip] = []

    var transition: TransitionType {
        get { TransitionType(rawValue: transitionRaw) ?? .dissolve }
        set { transitionRaw = newValue.rawValue }
    }

    var introCard: TitleCardStyle {
        get { (try? introCardData.map { try JSONDecoder().decode(TitleCardStyle.self, from: $0) }) ?? .intro(named: name) }
        set { introCardData = try? JSONEncoder().encode(newValue) }
    }

    var endCard: TitleCardStyle {
        get { (try? endCardData.map { try JSONDecoder().decode(TitleCardStyle.self, from: $0) }) ?? .end() }
        set { endCardData = try? JSONEncoder().encode(newValue) }
    }

    var orderedClips: [Clip] { clips.sorted { $0.sortIndex < $1.sortIndex } }

    init(name: String, sortIndex: Int) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.lastUsedAt = Date()
        self.sortIndex = sortIndex
        self.transitionRaw = TransitionType.dissolve.rawValue
    }
}
