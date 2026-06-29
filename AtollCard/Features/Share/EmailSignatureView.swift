import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct EmailSignatureView: View {
    let card: Card
    let store: CardStoring
    @State private var fields: [CardField] = []
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Vorschau")
                    .font(.atoll(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.text2)
                Text(EmailSignatureBuilder.plainText(for: card, fields: fields))
                    .font(.atoll(size: 14))
                    .foregroundStyle(Theme.text)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .glassSurface(cornerRadius: 18)

                HStack(spacing: 12) {
                    Button { copy() } label: {
                        Label(copied ? "Kopiert" : "Kopieren", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accentDefault)

                    ShareLink(item: EmailSignatureBuilder.plainText(for: card, fields: fields)) {
                        Label("Teilen", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(20)
        }
        .background(Theme.appBG.ignoresSafeArea())
        #if os(iOS)
        .navigationTitle("E-Mail-Signatur")
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { fields = (try? await store.fields(forCard: card.id)) ?? [] }
    }

    private func copy() {
        let html = EmailSignatureBuilder.html(for: card, fields: fields)
        let plain = EmailSignatureBuilder.plainText(for: card, fields: fields)
        #if os(iOS)
        UIPasteboard.general.setItems([["public.html": html, "public.utf8-plain-text": plain]])
        #elseif os(macOS)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(html, forType: .html)
        pb.setString(plain, forType: .string)
        #endif
        copied = true
    }
}
