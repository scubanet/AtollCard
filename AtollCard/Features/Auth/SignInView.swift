import SwiftUI

struct SignInView: View {
    @ObservedObject var authVM: AuthViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("E-Mail", text: $email)
                        .textContentType(.emailAddress)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        #endif

                    SecureField("Passwort", text: $password)
                        .textContentType(.password)
                }

                if let error = authVM.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task {
                            isSubmitting = true
                            await authVM.signIn(email: email, password: password)
                            isSubmitting = false
                        }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("Anmelden")
                        }
                    }
                    .disabled(isSubmitting || email.isEmpty || password.isEmpty)
                }
            }
            .navigationTitle("AtollCard")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}

#Preview {
    SignInView(authVM: AuthViewModel(authenticator: AppStores.preview.authenticator))
}
