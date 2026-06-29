import SwiftUI

/// Kontakte tab — lists leads captured via the user's shared profile.
struct ContactsView: View {
    @StateObject private var vm: ConnectionsViewModel

    init(store: ConnectionStoring, ownerId: UUID) {
        _vm = StateObject(wrappedValue: ConnectionsViewModel(store: store, ownerId: ownerId))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header

                    if let message = vm.errorMessage {
                        Text(message)
                            .font(.atoll(size: 14))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if vm.connections.isEmpty {
                        emptyState
                    } else {
                        connectionsList
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
            .background(Theme.appBG.ignoresSafeArea())
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
        }
        .task { await vm.load() }
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

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.text2)
            Text("Bald verfügbar")
                .font(.atoll(size: 20, weight: .bold))
                .foregroundStyle(Theme.text)
            Text("Noch keine Kontakte – über dein geteiltes Profil eingegangene Kontakte erscheinen hier.")
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

    private var connectionsList: some View {
        VStack(spacing: 12) {
            ForEach(vm.connections) { connection in
                NavigationLink {
                    ConnectionDetailView(connection: connection)
                } label: {
                    row(for: connection)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
    }

    private func row(for connection: Connection) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(connection.name)
                    .font(.atoll(size: 17, weight: .bold))
                    .foregroundStyle(Theme.text)
                if let company = connection.company, !company.isEmpty {
                    Text(company)
                        .font(.atoll(size: 14))
                        .foregroundStyle(Theme.text2)
                }
                Text(connection.createdAt.formatted(.relative(presentation: .named)))
                    .font(.atoll(size: 12))
                    .foregroundStyle(Theme.text2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.text2)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .glassSurface(cornerRadius: 18)
    }
}

#Preview {
    ContactsView(
        store: InMemoryConnectionStore(seed: [
            Connection(id: UUID(), cardId: UUID(), name: "Mara Lindqvist",
                       email: "mara@example.com", phone: "+49 170 1234567",
                       company: "Northwind Studio", note: "Auf der Messe getroffen.",
                       createdAt: Date().addingTimeInterval(-3600)),
            Connection(id: UUID(), cardId: UUID(), name: "Tomás Berg",
                       email: nil, phone: "+49 151 9876543",
                       company: nil, note: nil,
                       createdAt: Date().addingTimeInterval(-86_400 * 2))
        ]),
        ownerId: UUID()
    )
}
