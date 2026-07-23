import SwiftUI

/// Lets the user pick an intro screen, an end screen, and a transition type for a
/// project — used both by the in-app preview and the export engine.
struct ProjectStyleView: View {
    @Bindable var project: Project
    @Environment(\.dismiss) private var dismiss

    @State private var introText: String
    @State private var introColor: Color
    @State private var endText: String
    @State private var endColor: Color
    @State private var transition: TransitionType

    init(project: Project) {
        self.project = project
        _introText = State(initialValue: project.introCard.text)
        _introColor = State(initialValue: Color(hex: project.introCard.colorHex))
        _endText = State(initialValue: project.endCard.text)
        _endColor = State(initialValue: Color(hex: project.endCard.colorHex))
        _transition = State(initialValue: project.transition)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L.t("style_intro_section")) {
                    TextField(L.t("style_text_placeholder"), text: $introText)
                    ColorPicker(L.t("style_color"), selection: $introColor, supportsOpacity: false)
                }
                Section(L.t("style_end_section")) {
                    TextField(L.t("style_text_placeholder"), text: $endText)
                    ColorPicker(L.t("style_color"), selection: $endColor, supportsOpacity: false)
                }
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

    private func save() {
        project.introCard = TitleCardStyle(text: introText, colorHex: introColor.hexString, duration: project.introCard.duration)
        project.endCard = TitleCardStyle(text: endText, colorHex: endColor.hexString, duration: project.endCard.duration)
        project.transition = transition
        dismiss()
    }
}
