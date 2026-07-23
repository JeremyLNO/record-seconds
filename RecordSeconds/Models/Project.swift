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

/// A generated title card (intro or end screen) rendered from text over a solid color.
struct TitleCardStyle: Codable, Equatable {
    var text: String
    var colorHex: String
    var duration: TimeInterval

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
