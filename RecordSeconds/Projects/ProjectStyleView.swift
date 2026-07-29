import SwiftUI

/// Lets the user pick an intro screen, an end screen, and a transition type for a
/// project — used both by the in-app preview and the export engine.
///
/// Turning the intro/end cards off is a licensed feature: on the free trial the toggles
/// are shown but locked, so the capability is discoverable without being usable.
struct ProjectStyleView: View {
    @Bindable var project: Project
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var introText: String
    @State private var introColor: Color
    @State private var introTheme: TitleCardTheme
    @State private var endText: String
    @State private var endColor: Color
    @State private var endTheme: TitleCardTheme
    @State private var transition: TransitionType
    @State private var includesIntro: Bool
    @State private var includesEnd: Bool

    private let isPaid = AppLicense.isPaid

    init(project: Project) {
        self.project = project
        _introText = State(initialValue: project.introCard.text)
        _introColor = State(initialValue: Color(hex: project.introCard.colorHex))
        _introTheme = State(initialValue: project.introCard.theme)
        _endText = State(initialValue: project.endCard.text)
        _endColor = State(initialValue: Color(hex: project.endCard.colorHex))
        _endTheme = State(initialValue: project.endCard.theme)
        _transition = State(initialValue: project.transition)
        _includesIntro = State(initialValue: project.includesIntroCard)
        _includesEnd = State(initialValue: project.includesEndCard)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(L.t("style_include_intro"), isOn: $includesIntro)
                        .disabled(!isPaid)
                    Toggle(L.t("style_include_end"), isOn: $includesEnd)
                        .disabled(!isPaid)
                    if !isPaid { paidHint }
                }

                Section(L.t("style_intro_section")) {
                    cardEditor(text: $introText, color: $introColor, theme: $introTheme)
                }
                .disabled(!includesIntro && isPaid)

                Section(L.t("style_end_section")) {
                    cardEditor(text: $endText, color: $endColor, theme: $endTheme)
                }
                .disabled(!includesEnd && isPaid)

                Section(L.t("style_transition_section")) {
                    Picker(L.t("style_transition_section"), selection: $transition) {
                        ForEach(TransitionType.allCases) { type in
                            Text(type.label).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle(L.t("project_style"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("save")) { save() }
                }
            }
        }
    }

    @ViewBuilder
    private func cardEditor(text: Binding<String>, color: Binding<Color>, theme: Binding<TitleCardTheme>) -> some View {
        TextField(L.t("style_text_placeholder"), text: text)
        Picker(L.t("style_theme"), selection: theme) {
            ForEach(TitleCardTheme.allCases) { option in
                Text(option.label).tag(option)
            }
        }
        .pickerStyle(.segmented)
        // The honeycomb theme draws its own palette, so the colour picker only applies
        // to the solid theme.
        if theme.wrappedValue == .solid {
            ColorPicker(L.t("style_color"), selection: color, supportsOpacity: false)
        }
    }

    private var paidHint: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(L.t("style_cards_locked"), systemImage: "lock.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button(L.t("style_get_license")) { openURL(AppLicense.manager.purchaseURL) }
                .font(.caption.weight(.semibold))
        }
    }

    private func save() {
        project.introCard = TitleCardStyle(
            text: introText,
            colorHex: introColor.hexString,
            duration: project.introCard.duration,
            theme: introTheme
        )
        project.endCard = TitleCardStyle(
            text: endText,
            colorHex: endColor.hexString,
            duration: project.endCard.duration,
            theme: endTheme
        )
        project.transition = transition
        // Only a licensed user can actually change these; the export re-checks anyway.
        if isPaid {
            project.includesIntroCard = includesIntro
            project.includesEndCard = includesEnd
        }
        dismiss()
    }
}
