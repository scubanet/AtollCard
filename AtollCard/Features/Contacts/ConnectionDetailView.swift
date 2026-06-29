import SwiftUI

/// Detail for a single captured lead, with tap-to-mail / tap-to-call.
struct ConnectionDetailView: View {
    let connection: Connection

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
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 120)
        }
        .background(Theme.appBG.ignoresSafeArea())
        #if os(iOS)
        .navigationTitle(connection.name)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(connection.name)
                .font(.atoll(size: 24, weight: .bold))
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
            email: "mara@example.com", phone: "+49 170 1234567",
            company: "Northwind Studio", note: "Auf der Messe getroffen, will Demo nächste Woche.",
            createdAt: Date()
        ))
    }
}
