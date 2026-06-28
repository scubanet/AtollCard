import SwiftUI

/// Placeholder for the M2 contacts feature.
struct ContactsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header

                VStack(spacing: 14) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.text2)
                    Text("Bald verfügbar")
                        .font(.atoll(size: 20, weight: .bold))
                        .foregroundStyle(Theme.text)
                    Text("Gespeicherte Kontakte und gescannte Karten erscheinen hier.")
                        .font(.atoll(size: 15))
                        .foregroundStyle(Theme.text2)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .padding(.horizontal, 20)
                .glassSurface(cornerRadius: 24)
                .padding(.top, 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .background(Theme.appBG.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Dein Netzwerk")
                .font(.atoll(size: 14, weight: .medium))
                .foregroundStyle(Theme.text2)
            Text("Kontakte")
                .font(.atoll(size: 30, weight: .bold))
                .foregroundStyle(Theme.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ContactsView()
}
