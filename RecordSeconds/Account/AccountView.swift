import SwiftUI

/// Optional "create a CrazyBeeLabs account" screen, reachable from Settings. Entirely
/// separate from app licensing — this is just for the account itself.
struct AccountView: View {
    @ObservedObject private var client = AccountClient.shared

    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var isRegistering = true
    @State private var errorMessage: String?

    var body: some View {
        Form {
            if let signedInEmail = client.email {
                Section {
                    Label(signedInEmail, systemImage: "person.crop.circle.fill")
                    Button(L.t("account_sign_out"), role: .destructive) { client.signOut() }
                }
            } else {
                Section {
                    Picker("", selection: $isRegistering) {
                        Text(L.t("account_create")).tag(true)
                        Text(L.t("account_sign_in")).tag(false)
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    if isRegistering {
                        TextField(L.t("account_name_placeholder"), text: $name)
                    }
                    TextField(L.t("account_email_placeholder"), text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    SecureField(L.t("account_password_placeholder"), text: $password)
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.caption)
                }
                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        if client.isWorking {
                            ProgressView()
                        } else {
                            Text(isRegistering ? L.t("account_create") : L.t("account_sign_in"))
                        }
                    }
                    .disabled(client.isWorking || email.isEmpty || password.isEmpty)
                }
            }
        }
        .navigationTitle(L.t("settings_account"))
    }

    private func submit() async {
        errorMessage = nil
        do {
            if isRegistering {
                try await client.register(email: email, password: password, name: name)
            } else {
                try await client.login(email: email, password: password)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
