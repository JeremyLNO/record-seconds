import Foundation

/// Supported in-app languages. The picker lets the user switch at runtime; the choice
/// persists and takes priority over the system language (falls back to system, then EN).
enum AppLanguage: String, CaseIterable, Identifiable {
    case en, fr, es, de, pt
    var id: String { rawValue }

    var flag: String {
        switch self {
        case .en: return "🇬🇧"
        case .fr: return "🇫🇷"
        case .es: return "🇪🇸"
        case .de: return "🇩🇪"
        case .pt: return "🇵🇹"
        }
    }

    var name: String {
        switch self {
        case .en: return "English"
        case .fr: return "Français"
        case .es: return "Español"
        case .de: return "Deutsch"
        case .pt: return "Português"
        }
    }

    var locale: Locale { Locale(identifier: rawValue) }

    static let storageKey = "app.language.override"

    /// First device-preferred language we support, else English.
    static var systemDefault: AppLanguage {
        for id in Locale.preferredLanguages {
            let code = Locale(identifier: id).language.languageCode?.identifier ?? ""
            if let lang = AppLanguage(rawValue: code) { return lang }
        }
        return .en
    }

    /// User override (if any) takes priority over the system language.
    static var current: AppLanguage {
        if let raw = UserDefaults.standard.string(forKey: storageKey),
           let lang = AppLanguage(rawValue: raw) { return lang }
        return systemDefault
    }
}

/// Tiny in-app localization table (key -> per-language string). A runtime lookup
/// table (rather than .xcstrings/.lproj) is what lets the language picker take effect
/// immediately, without relaunching the app.
enum L {
    static func t(_ key: String, _ lang: AppLanguage = .current) -> String {
        table[key]?[lang] ?? table[key]?[.en] ?? key
    }

    static func clipCount(_ n: Int, _ lang: AppLanguage = .current) -> String {
        let unit = n == 1 ? t("unit_clip", lang) : t("unit_clips", lang)
        return "\(n) \(unit)"
    }

    static let table: [String: [AppLanguage: String]] = [
        // MARK: General
        "save":   [.en: "Save", .fr: "Enregistrer", .es: "Guardar", .de: "Speichern", .pt: "Guardar"],
        "cancel": [.en: "Cancel", .fr: "Annuler", .es: "Cancelar", .de: "Abbrechen", .pt: "Cancelar"],
        "delete": [.en: "Delete", .fr: "Supprimer", .es: "Eliminar", .de: "Löschen", .pt: "Eliminar"],
        "done":   [.en: "Done", .fr: "OK", .es: "Listo", .de: "Fertig", .pt: "Concluído"],
        "add":    [.en: "Add", .fr: "Ajouter", .es: "Añadir", .de: "Hinzufügen", .pt: "Adicionar"],
        "edit":   [.en: "Edit", .fr: "Modifier", .es: "Editar", .de: "Bearbeiten", .pt: "Editar"],
        "rename": [.en: "Rename", .fr: "Renommer", .es: "Renombrar", .de: "Umbenennen", .pt: "Renomear"],
        "close":  [.en: "Close", .fr: "Fermer", .es: "Cerrar", .de: "Schließen", .pt: "Fechar"],
        "yes":    [.en: "Yes", .fr: "Oui", .es: "Sí", .de: "Ja", .pt: "Sim"],
        "no":     [.en: "No", .fr: "Non", .es: "No", .de: "Nein", .pt: "Não"],
        "continue": [.en: "Continue", .fr: "Continuer", .es: "Continuar", .de: "Weiter", .pt: "Continuar"],
        "share":  [.en: "Share", .fr: "Partager", .es: "Compartir", .de: "Teilen", .pt: "Partilhar"],
        "settings": [.en: "Settings", .fr: "Réglages", .es: "Ajustes", .de: "Einstellungen", .pt: "Definições"],

        // MARK: Tabs
        "tab_projects": [.en: "Projects", .fr: "Projets", .es: "Proyectos", .de: "Projekte", .pt: "Projetos"],
        "tab_settings": [.en: "Settings", .fr: "Réglages", .es: "Ajustes", .de: "Einstellungen", .pt: "Definições"],

        // MARK: Settings — general
        "settings_support_ideas": [.en: "Support & ideas", .fr: "Support et idées", .es: "Ayuda e ideas", .de: "Support & Ideen", .pt: "Apoio e ideias"],
        "settings_license": [.en: "License", .fr: "Licence", .es: "Licencia", .de: "Lizenz", .pt: "Licença"],
        "settings_language": [.en: "Language", .fr: "Langue", .es: "Idioma", .de: "Sprache", .pt: "Idioma"],
        "settings_account": [.en: "Account", .fr: "Compte", .es: "Cuenta", .de: "Konto", .pt: "Conta"],
        "settings_notifications": [.en: "Notifications", .fr: "Notifications", .es: "Notificaciones", .de: "Benachrichtigungen", .pt: "Notificações"],
        "settings_capture": [.en: "Capture", .fr: "Capture", .es: "Captura", .de: "Aufnahme", .pt: "Captura"],

        // MARK: Transitions / title cards
        "transition_cut": [.en: "Cut", .fr: "Coupe franche", .es: "Corte", .de: "Schnitt", .pt: "Corte"],
        "transition_dissolve": [.en: "Dissolve", .fr: "Fondu", .es: "Disolución", .de: "Überblendung", .pt: "Dissolvência"],
        "title_card_end_default": [.en: "The End", .fr: "Fin", .es: "Fin", .de: "Ende", .pt: "Fim"],

        // MARK: Onboarding
        "onboarding_trial_title": [.en: "Your 7-day free trial has started", .fr: "Votre essai gratuit de 7 jours a commencé", .es: "Tu prueba gratuita de 7 días ha comenzado", .de: "Ihre 7-tägige kostenlose Testversion hat begonnen", .pt: "O seu teste gratuito de 7 dias começou"],
        "onboarding_trial_body": [.en: "Every feature is unlocked for 7 days — no payment info needed.", .fr: "Toutes les fonctionnalités sont débloquées pendant 7 jours — aucune information de paiement requise.", .es: "Todas las funciones están desbloqueadas durante 7 días — no se requiere información de pago.", .de: "Alle Funktionen sind 7 Tage lang freigeschaltet — keine Zahlungsangaben erforderlich.", .pt: "Todas as funcionalidades estão desbloqueadas durante 7 dias — sem necessidade de dados de pagamento."],
        "onboarding_get_started": [.en: "Get started", .fr: "Commencer", .es: "Empezar", .de: "Los geht's", .pt: "Começar"],

        // MARK: License paywall features
        "license_feature_projects_title": [.en: "Unlimited projects", .fr: "Projets illimités", .es: "Proyectos ilimitados", .de: "Unbegrenzte Projekte", .pt: "Projetos ilimitados"],
        "license_feature_projects_detail": [.en: "Create as many second-a-day projects as you like.", .fr: "Créez autant de projets « une seconde par jour » que vous voulez.", .es: "Crea tantos proyectos de un segundo al día como quieras.", .de: "Erstellen Sie so viele Ein-Sekunde-Projekte, wie Sie möchten.", .pt: "Crie tantos projetos de um segundo por dia quantos quiser."],
        "license_feature_transitions_title": [.en: "Transitions & title cards", .fr: "Transitions et écrans de titre", .es: "Transiciones y tarjetas de título", .de: "Übergänge & Titelkarten", .pt: "Transições e cartões de título"],
        "license_feature_transitions_detail": [.en: "Custom intro, end screen and dissolve transitions.", .fr: "Écran d'intro, de fin et transitions en fondu personnalisés.", .es: "Introducción, pantalla final y transiciones de disolución personalizadas.", .de: "Individuelles Intro, Endbildschirm und Überblend-Übergänge.", .pt: "Introdução, ecrã final e transições de dissolução personalizadas."],
        "license_feature_export_title": [.en: "Export & share", .fr: "Export et partage", .es: "Exportar y compartir", .de: "Export & Teilen", .pt: "Exportar e partilhar"],
        "license_feature_export_detail": [.en: "Save your movie to Photos and share it anywhere.", .fr: "Enregistrez votre film dans Photos et partagez-le partout.", .es: "Guarda tu película en Fotos y compártela donde quieras.", .de: "Speichern Sie Ihren Film in Fotos und teilen Sie ihn überall.", .pt: "Guarde o seu filme em Fotos e partilhe-o em qualquer lugar."],

        // MARK: Quick capture
        "quick_capture_mode_last_used": [.en: "Last used project", .fr: "Dernier projet utilisé", .es: "Último proyecto usado", .de: "Zuletzt verwendetes Projekt", .pt: "Último projeto utilizado"],
        "quick_capture_mode_default": [.en: "Default project", .fr: "Projet par défaut", .es: "Proyecto predeterminado", .de: "Standardprojekt", .pt: "Projeto predefinido"],
        "quick_capture_needs_project_title": [.en: "Create a project first", .fr: "Créez d'abord un projet", .es: "Crea primero un proyecto", .de: "Zuerst ein Projekt erstellen", .pt: "Crie primeiro um projeto"],
        "quick_capture_needs_project_message": [.en: "Quick capture needs at least one project to save the clip into.", .fr: "La capture rapide a besoin d'au moins un projet pour y enregistrer le clip.", .es: "La captura rápida necesita al menos un proyecto en el que guardar el clip.", .de: "Für die Schnellaufnahme ist mindestens ein Projekt erforderlich, in dem der Clip gespeichert wird.", .pt: "A captura rápida precisa de pelo menos um projeto para guardar o clipe."],

        // MARK: Review prompt
        "review_prompt_title": [.en: "Enjoying Video One Sec?", .fr: "Vous aimez Video One Sec ?", .es: "¿Te gusta Video One Sec?", .de: "Gefällt Ihnen Video One Sec?", .pt: "Está a gostar do Video One Sec?"],
        "review_prompt_message": [.en: "Let us know how it's going.", .fr: "Dites-nous comment ça se passe.", .es: "Cuéntanos cómo te va.", .de: "Sagen Sie uns, wie es läuft.", .pt: "Diga-nos como está a correr."],
        "quick_capture_button_label": [.en: "Quick capture", .fr: "Capture rapide", .es: "Captura rápida", .de: "Schnellaufnahme", .pt: "Captura rápida"],

        // MARK: Capture
        "capture_permission_denied": [.en: "Camera access is required to record clips. Enable it in Settings.", .fr: "L'accès à la caméra est nécessaire pour filmer. Activez-le dans Réglages.", .es: "Se requiere acceso a la cámara para grabar clips. Actívalo en Ajustes.", .de: "Für die Aufnahme von Clips ist Kamerazugriff erforderlich. Aktivieren Sie ihn in den Einstellungen.", .pt: "É necessário acesso à câmara para gravar clipes. Ative-o nas Definições."],
        "capture_recording": [.en: "REC", .fr: "REC", .es: "REC", .de: "REC", .pt: "REC"],
        "capture_clip_saved": [.en: "Clip saved", .fr: "Clip enregistré", .es: "Clip guardado", .de: "Clip gespeichert", .pt: "Clipe guardado"],
        "capture_error_recording": [.en: "That clip couldn't be recorded. Please try again.", .fr: "Ce clip n'a pas pu être enregistré. Veuillez réessayer.", .es: "No se pudo grabar ese clip. Inténtalo de nuevo.", .de: "Dieser Clip konnte nicht aufgenommen werden. Bitte versuchen Sie es erneut.", .pt: "Não foi possível gravar esse clipe. Tente novamente."],
        "capture_simulator_no_camera": [.en: "No camera available here. Import a video instead to try the flow.", .fr: "Pas de caméra disponible ici. Importez une vidéo pour tester le flux.", .es: "No hay cámara disponible aquí. Importa un vídeo para probar el flujo.", .de: "Hier ist keine Kamera verfügbar. Importieren Sie stattdessen ein Video, um den Ablauf zu testen.", .pt: "Não há câmara disponível aqui. Importe um vídeo para testar o fluxo."],
        "capture_import_from_photos": [.en: "Import from Photos", .fr: "Importer depuis Photos", .es: "Importar desde Fotos", .de: "Aus Fotos importieren", .pt: "Importar de Fotos"],

        // MARK: Projects
        "project_new_title": [.en: "New project", .fr: "Nouveau projet", .es: "Nuevo proyecto", .de: "Neues Projekt", .pt: "Novo projeto"],
        "project_name_placeholder": [.en: "Project name", .fr: "Nom du projet", .es: "Nombre del proyecto", .de: "Projektname", .pt: "Nome do projeto"],
        "project_empty_title": [.en: "No projects yet", .fr: "Pas encore de projet", .es: "Aún no hay proyectos", .de: "Noch keine Projekte", .pt: "Ainda sem projetos"],
        "project_empty_message": [.en: "Create a project — daily life, a trip, anything — and start collecting one-second clips.", .fr: "Créez un projet — vie quotidienne, voyage, ce que vous voulez — et commencez à collectionner des clips d'une seconde.", .es: "Crea un proyecto — vida diaria, un viaje, lo que sea — y empieza a coleccionar clips de un segundo.", .de: "Erstellen Sie ein Projekt — Alltag, eine Reise, was auch immer — und beginnen Sie, Ein-Sekunden-Clips zu sammeln.", .pt: "Crie um projeto — vida diária, uma viagem, qualquer coisa — e comece a colecionar clipes de um segundo."],
        "unit_clip": [.en: "clip", .fr: "clip", .es: "clip", .de: "Clip", .pt: "clipe"],
        "unit_clips": [.en: "clips", .fr: "clips", .es: "clips", .de: "Clips", .pt: "clipes"],
        "project_style": [.en: "Intro, end & transition", .fr: "Intro, fin et transition", .es: "Introducción, fin y transición", .de: "Intro, Ende & Übergang", .pt: "Introdução, fim e transição"],
        "project_preview": [.en: "Preview movie", .fr: "Aperçu du film", .es: "Vista previa de la película", .de: "Film-Vorschau", .pt: "Pré-visualizar filme"],
        "project_export": [.en: "Export movie", .fr: "Exporter le film", .es: "Exportar película", .de: "Film exportieren", .pt: "Exportar filme"],
        "project_no_clips_title": [.en: "No clips yet", .fr: "Pas encore de clip", .es: "Aún no hay clips", .de: "Noch keine Clips", .pt: "Ainda sem clipes"],
        "project_no_clips_message": [.en: "Use quick capture to add your first one-second clip to this project.", .fr: "Utilisez la capture rapide pour ajouter votre premier clip d'une seconde à ce projet.", .es: "Usa la captura rápida para añadir tu primer clip de un segundo a este proyecto.", .de: "Verwenden Sie die Schnellaufnahme, um Ihren ersten Ein-Sekunden-Clip zu diesem Projekt hinzuzufügen.", .pt: "Use a captura rápida para adicionar o seu primeiro clipe de um segundo a este projeto."],

        // MARK: Style picker
        "style_intro_section": [.en: "Intro screen", .fr: "Écran d'intro", .es: "Pantalla de introducción", .de: "Startbildschirm", .pt: "Ecrã de introdução"],
        "style_end_section": [.en: "End screen", .fr: "Écran de fin", .es: "Pantalla final", .de: "Endbildschirm", .pt: "Ecrã final"],
        "style_transition_section": [.en: "Transition", .fr: "Transition", .es: "Transición", .de: "Übergang", .pt: "Transição"],
        "style_text_placeholder": [.en: "Text", .fr: "Texte", .es: "Texto", .de: "Text", .pt: "Texto"],
        "style_color": [.en: "Background color", .fr: "Couleur de fond", .es: "Color de fondo", .de: "Hintergrundfarbe", .pt: "Cor de fundo"],

        // MARK: Export
        "export_in_progress": [.en: "Rendering your movie…", .fr: "Rendu du film en cours…", .es: "Renderizando tu película…", .de: "Ihr Film wird gerendert…", .pt: "A processar o seu filme…"],
        "export_saved_to_photos": [.en: "Saved to Photos", .fr: "Enregistré dans Photos", .es: "Guardado en Fotos", .de: "In Fotos gespeichert", .pt: "Guardado em Fotos"],
        "export_error_no_clips": [.en: "Add at least one clip before exporting.", .fr: "Ajoutez au moins un clip avant d'exporter.", .es: "Añade al menos un clip antes de exportar.", .de: "Fügen Sie vor dem Export mindestens einen Clip hinzu.", .pt: "Adicione pelo menos um clipe antes de exportar."],
        "export_error_generic": [.en: "Something went wrong while exporting.", .fr: "Une erreur est survenue lors de l'export.", .es: "Algo salió mal durante la exportación.", .de: "Beim Export ist ein Fehler aufgetreten.", .pt: "Ocorreu um erro durante a exportação."],
        "export_error_photos_denied": [.en: "Allow access to Photos in Settings to save your movie.", .fr: "Autorisez l'accès à Photos dans Réglages pour enregistrer votre film.", .es: "Permite el acceso a Fotos en Ajustes para guardar tu película.", .de: "Erlauben Sie den Zugriff auf Fotos in den Einstellungen, um Ihren Film zu speichern.", .pt: "Permita o acesso a Fotos nas Definições para guardar o seu filme."],

        // MARK: Account
        "account_create": [.en: "Create account", .fr: "Créer un compte", .es: "Crear cuenta", .de: "Konto erstellen", .pt: "Criar conta"],
        "account_sign_in": [.en: "Sign in", .fr: "Se connecter", .es: "Iniciar sesión", .de: "Anmelden", .pt: "Iniciar sessão"],
        "account_sign_out": [.en: "Sign out", .fr: "Se déconnecter", .es: "Cerrar sesión", .de: "Abmelden", .pt: "Terminar sessão"],
        "account_name_placeholder": [.en: "Name", .fr: "Nom", .es: "Nombre", .de: "Name", .pt: "Nome"],
        "account_email_placeholder": [.en: "Email", .fr: "E-mail", .es: "Correo electrónico", .de: "E-Mail", .pt: "E-mail"],
        "account_password_placeholder": [.en: "Password", .fr: "Mot de passe", .es: "Contraseña", .de: "Passwort", .pt: "Palavra-passe"],
        "account_error_generic": [.en: "Something went wrong. Please try again.", .fr: "Une erreur est survenue. Veuillez réessayer.", .es: "Algo salió mal. Inténtalo de nuevo.", .de: "Etwas ist schiefgelaufen. Bitte versuchen Sie es erneut.", .pt: "Ocorreu um erro. Tente novamente."],
        "account_optional_note": [.en: "Optional — separate from your app license.", .fr: "Facultatif — indépendant de votre licence d'application.", .es: "Opcional: independiente de tu licencia de la app.", .de: "Optional — unabhängig von Ihrer App-Lizenz.", .pt: "Opcional — independente da sua licença da app."],

        // MARK: Settings — capture & quick capture
        "settings_video_quality": [.en: "Video quality", .fr: "Qualité vidéo", .es: "Calidad de vídeo", .de: "Videoqualität", .pt: "Qualidade de vídeo"],
        "settings_clip_duration": [.en: "Clip duration", .fr: "Durée du clip", .es: "Duración del clip", .de: "Clip-Dauer", .pt: "Duração do clipe"],
        "settings_quick_capture_target": [.en: "Save quick captures to", .fr: "Enregistrer les captures rapides dans", .es: "Guardar capturas rápidas en", .de: "Schnellaufnahmen speichern in", .pt: "Guardar capturas rápidas em"],
        "settings_no_default_project": [.en: "None set", .fr: "Aucun défini", .es: "Ninguno definido", .de: "Keines festgelegt", .pt: "Nenhum definido"],
        "settings_language_system": [.en: "System default", .fr: "Langue du système", .es: "Idioma del sistema", .de: "Systemsprache", .pt: "Idioma do sistema"],
    ]
}
