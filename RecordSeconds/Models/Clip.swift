import Foundation
import SwiftData
import AVFoundation

@Model
final class Clip {
    var id: UUID = UUID()
    /// Filename inside the app's Documents/Videos directory (see `VideoStore`).
    var filename: String = ""
    var duration: Double = 1
    var createdAt: Date = Date()
    /// Position within the parent project; lower sorts first.
    var sortIndex: Int = 0

    var project: Project?

    init(filename: String, duration: Double, sortIndex: Int) {
        self.id = UUID()
        self.filename = filename
        self.duration = duration
        self.createdAt = Date()
        self.sortIndex = sortIndex
    }

    var fileURL: URL { VideoStore.videosDirectory.appendingPathComponent(filename) }
}

/// Where captured clip video files live on disk. SwiftData stores only the filename;
/// the actual `.mov` files are plain files in Documents/Videos.
enum VideoStore {
    static var videosDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Videos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func newFileURL() -> URL {
        videosDirectory.appendingPathComponent("\(UUID().uuidString).mov")
    }

    static func delete(_ clip: Clip) {
        try? FileManager.default.removeItem(at: clip.fileURL)
    }

    /// Moves a freshly recorded/imported movie file into permanent storage and
    /// creates its `Clip`, appended to the end of `project`.
    ///
    /// The real recorded length is read back from the file rather than assumed from the
    /// settings value — `maxRecordedDuration` stops on a frame boundary, so an actual
    /// clip is never exactly 1.000s.
    @discardableResult
    static func saveCapturedClip(from tempURL: URL, into project: Project, duration: Double, modelContext: ModelContext) async throws -> Clip {
        let destination = newFileURL()
        try FileManager.default.moveItem(at: tempURL, to: destination)

        let actualDuration = (try? await AVURLAsset(url: destination).load(.duration).seconds) ?? duration
        let clipDuration = actualDuration.isFinite && actualDuration > 0 ? actualDuration : duration

        let nextIndex = (project.clips.map(\.sortIndex).max() ?? -1) + 1
        let clip = Clip(filename: destination.lastPathComponent, duration: clipDuration, sortIndex: nextIndex)
        // Insert before wiring the relationship so both sides live in the same context,
        // then flush explicitly — the capture screen dismisses immediately after this
        // and must not race SwiftData's autosave.
        modelContext.insert(clip)
        clip.project = project
        project.lastUsedAt = Date()
        try modelContext.save()
        return clip
    }
}
