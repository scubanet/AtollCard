import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @ObservedObject var authVM: AuthViewModel
    @State private var currentNonce: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("AtollCard")
                .font(.atoll(size: 30, weight: .bold))
                .foregroundStyle(Theme.text)
            SignInWithAppleButton(.signIn) { request in
                let nonce = NonceGenerator.randomNonceString()
                currentNonce = nonce
                request.requestedScopes = [.fullName, .email]
                request.nonce = NonceGenerator.sha256(nonce)
            } onCompletion: { result in
                handle(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .frame(maxWidth: 320)
            if let msg = authVM.errorMessage {
                Text(msg).font(.atoll(size: 13)).foregroundStyle(.red)
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.appBG.ignoresSafeArea())
    }

    private func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            authVM.errorMessage = error.localizedDescription
        case .success(let auth):
            guard
                let cred = auth.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = cred.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8),
                let nonce = currentNonce
            else {
                authVM.errorMessage = "Apple-Anmeldung unvollständig."
                return
            }
            let fullName = [cred.fullName?.givenName, cred.fullName?.familyName]
                .compactMap { $0 }.joined(separator: " ")
            Task {
                await authVM.signIn(idToken: idToken, nonce: nonce)
                if let uid = authVM.userId, !fullName.isEmpty {
                    await ProfileNameUpdater.update(displayName: fullName, userId: uid)
                }
            }
        }
    }
}

#Preview {
    SignInView(authVM: AuthViewModel(authenticator: AppStores.preview.authenticator))
}
