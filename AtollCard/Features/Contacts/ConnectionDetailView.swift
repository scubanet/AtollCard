import SwiftUI

/// Detail for a single captured lead, with tap-to-mail / tap-to-call and save-to-contacts.
struct ConnectionDetailView: View {
    let connection: Connection
    private let exporter: ContactExporting

    @State private var saved = false
    @State private var exportError: String?

    init(connection: Connection, exporter: ContactExporting = SystemContactExporter()) {
        self.connection = connection
        self.exporter = exporter
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                heading

                contactRows

                if let note = connection.note, !note.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notiz")
                            .font(.atoll(size: 13, weight: .medium))
                            .foregroundStyle(Theme.text2)
                        Text(note)
                            .font(.atoll(size: 15))
                            .foregroundStyle(Theme.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassSurface(cornerRadius: 18)
                }

                exportSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 120)
        }
        .background(Theme.appBG.ignoresSafeArea())
        #if os(iOS)
        .navigationTitle(connection.displayName)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(connection.displayName)
                .font(.atoll(size: 24, weight: .bold, relativeTo: .title2))
                .foregroundStyle(Theme.text)
            if let company = connection.company, !company.isEmpty {
                Text(company)
                    .font(.atoll(size: 16))
                    .foregroundStyle(Theme.text2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var contactRows: some View {
        let hasEmail = !(connection.email ?? "").isEmpty
        let hasPhone = !(connection.phone ?? "").isEmpty
        if hasEmail || hasPhone {
            VStack(spacing: 0) {
                if let email = connection.email, !email.isEmpty,
                   let url = URL(string: "mailto:\(email)") {
                    Link(destination: url) {
                        contactRow(icon: "envelope", text: email)
                    }
                    if hasPhone {
                        Divider().overlay(Theme.separator)
                    }
                }
                if let phone = connection.phone, !phone.isEmpty {
                    #if os(iOS)
                    if let url = URL(string: "tel:\(phone)") {
                        Link(destination: url) {
                            contactRow(icon: "phone", text: phone)
                        }
                    }
                    #else
                    contactRow(icon: "phone", text: phone)
                    #endif
                }
            }
            .glassSurface(cornerRadius: 18)
        }
    }

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                Task { await saveToContacts() }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: saved ? "checkmark.circle.fill" : "person.crop.circle.badge.plus")
                        .font(.system(size: 16))
                        .foregroundStyle(saved ? .green : Theme.accentDefault)
                        .frame(width: 22)
                        .accessibilityHidden(true)
                    Text(saved ? "Gesichert" : "In Kontakte sichern")
                        .font(.atoll(size: 16, weight: .medium))
                        .foregroundStyle(Theme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .glassSurface(cornerRadius: 18)
            .disabled(saved)

            if let exportError {
                Text(exportError)
                    .font(.atoll(size: 14))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func saveToContacts() async {
        do {
            try await exporter.save(connection)
            saved = true
            exportError = nil
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func contactRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Theme.accentDefault)
                .frame(width: 22)
                .accessibilityHidden(true)
            Text(text)
                .font(.atoll(size: 16))
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        ConnectionDetailView(connection: Connection(
            id: UUID(), cardId: UUID(), name: "Mara Lindqvist",
            firstName: "Mara", lastName: "Lindqvist",
            email: "mara@example.com", phone: "+49 170 1234567",
            company: "Northwind Studio", note: "Auf der Messe getroffen, will Demo nächste Woche.",
            createdAt: Date()
        ))
    }
}
