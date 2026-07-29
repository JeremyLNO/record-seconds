import SwiftUI

private enum PreviewItem: Identifiable {
    case title(image: UIImage, duration: TimeInterval)
    case clip(Clip)

    var id: String {
        switch self {
        case .title(_, let duration): return "title-\(duration)"
        case .clip(let clip): return clip.id.uuidString
        }
    }

    var duration: TimeInterval {
        switch self {
        case .title(_, let duration): return duration
        case .clip(let clip): return clip.duration
        }
    }
}

/// Plays a project back-to-back — intro screen, every clip in order, end screen —
/// each shown for its exact configured duration before auto-advancing. This is a
/// quick "does it flow well" preview; the real transition (cut vs. dissolve) is
/// rendered frame-accurately by the export engine, not approximated here.
struct ProjectPreviewPlayer: View {
    let project: Project
    @Environment(\.dismiss) private var dismiss

    @State private var items: [PreviewItem] = []
    @State private var index = 0
    @State private var isReady = false
    @State private var showsWatermark = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if isReady, !items.isEmpty {
                content(for: items[index])
                    .id(items[index].id)
                    .task(id: items[index].id) { await advanceAfterDelay() }
            } else {
                ProgressView().tint(.white)
            }

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.black.opacity(0.4), in: Circle())
                    }
                    Spacer()
                    progressDots
                }
                .padding()
                Spacer()
            }

            if showsWatermark {
                GeometryReader { geo in
                    VStack {
                        Spacer()
                        Watermark.Badge(cardHeight: geo.size.height)
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, geo.size.height * Watermark.bottomInsetRatio)
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .task { await buildItems() }
    }

    private var progressDots: some View {
        HStack(spacing: 4) {
            ForEach(items.indices, id: \.self) { i in
                Capsule()
                    .fill(i == index ? Color.white : Color.white.opacity(0.35))
                    .frame(width: i == index ? 16 : 6, height: 6)
            }
        }
    }

    @ViewBuilder
    private func content(for item: PreviewItem) -> some View {
        switch item {
        case .title(let image, _):
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        case .clip(let clip):
            SingleShotPlayerView(url: clip.fileURL)
        }
    }

    private func advanceAfterDelay() async {
        try? await Task.sleep(nanoseconds: UInt64(items[index].duration * 1_000_000_000))
        guard !Task.isCancelled else { return }
        if index < items.count - 1 {
            index += 1
        } else {
            dismiss()
        }
    }

    @MainActor
    private func buildItems() async {
        let size = CGSize(width: 720, height: 1280)
        // Mirror exactly what an export would produce, so the preview is honest about
        // both the cards and the watermark.
        let plan = ExportPlan(project: project, isPaid: AppLicense.isPaid)
        showsWatermark = plan.showsWatermark

        var built: [PreviewItem] = []
        if plan.includesIntro {
            built.append(.title(image: TitleCardRenderer.image(for: project.introCard, size: size),
                                duration: project.introCard.duration))
        }
        built += project.orderedClips.map { PreviewItem.clip($0) }
        if plan.includesEnd {
            built.append(.title(image: TitleCardRenderer.image(for: project.endCard, size: size),
                                duration: project.endCard.duration))
        }
        items = built
        isReady = true
    }
}
