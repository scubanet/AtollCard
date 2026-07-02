import SwiftUI

/// Kontakte tab — lists leads captured via the user's shared profile.
struct ContactsView: View {
    @StateObject private var vm: ConnectionsViewModel
    @State private var connectionToDelete: Connection?

    init(store: ConnectionStoring, ownerId: UUID) {
        _vm = StateObject(wrappedValue: ConnectionsViewModel(store: store, ownerId: ownerId))
    }

    var body: some View {
        NavigationStack {
            List {
                Group {
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
                        connectionRows
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.appBG.ignoresSafeArea())
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .confirmationDialog(
                "Kontakt löschen?",
                isPresented: Binding(
                    get: { connectionToDelete != nil },
                    set: { if !$0 { connectionToDelete = nil } }
                ),
                titleVisibility: .visible,
                presenting: connectionToDelete
            ) { connection in
                Button("Löschen", role: .destructive) {
                    Task { await vm.delete(connection.id) }
                }
                Button("Abbrechen", role: .cancel) {}
            } message: { connection in
                Text("„\(connection.displayName)“ wird dauerhaft entfernt.")
            }
        }
        .task { await vm.load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Dein Netzwerk")
                .font(.atoll(size: 14, weight: .medium))
                .foregroundStyle(Theme.text2)
            Text("Kontakte")
                .font(.atoll(size: 30, weight: .bold, relativeTo: .title2))
                .foregroundStyle(Theme.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
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

    private var connectionRows: some View {
        ForEach(vm.connections) { connection in
            NavigationLink {
                ConnectionDetailView(connection: connection)
            } label: {
                row(for: connection)
            }
            .buttonStyle(.plain)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    connectionToDelete = connection
                } label: {
                    Label("Löschen", systemImage: "trash")
                }
            }
        }
    }

    private func row(for connection: Connection) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(connection.displayName)
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
                       firstName: "Mara", lastName: "Lindqvist",
                       email: "mara@example.com", phone: "+49 170 1234567",
                       company: "Northwind Studio", note: "Auf der Messe getroffen.",
                       createdAt: Date().addingTimeInterval(-3600)),
            Connection(id: UUID(), cardId: UUID(), name: "Tomás Berg",
                       firstName: nil, lastName: nil,
                       email: nil, phone: "+49 151 9876543",
                       company: nil, note: nil,
                       createdAt: Date().addingTimeInterval(-86_400 * 2))
        ]),
        ownerId: UUID()
    )
}
