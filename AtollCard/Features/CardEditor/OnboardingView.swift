import SwiftUI

/// 3-step onboarding that drives a `CardEditorViewModel`:
/// 1. Name (+ optional title/company/label)
/// 2. Contact field(s)
/// 3. Accent color picker
/// The final step normalizes the slug from the name, then calls `vm.save()`.
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: CardEditorViewModel

    @State private var step = 0
    @State private var slugEdited = false
    @State private var isAutoUpdatingSlug = false
    @State private var isSaving = false

    // Step 2 single-field entry
    @State private var phone = ""
    @State private var email = ""
    @State private var web = ""

    private let accents: [(name: String, hex: String)] = [
        ("Teal", "#0E7C86"),
        ("Blau", "#2A6FDB"),
        ("Violett", "#6D5CFF"),
        ("Grün", "#1F8A5B"),
        ("Orange", "#C2603A"),
        ("Anthrazit", "#2E3138"),
    ]

    init(store: CardStoring, ownerId: UUID) {
        _vm = StateObject(wrappedValue: CardEditorViewModel(store: store, ownerId: ownerId, editing: nil))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressBar
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                ScrollView {
                    Group {
                        switch step {
                        case 0: stepName
                        case 1: stepContact
                        default: stepAccent
                        }
                    }
                    .padding(20)
                }

                footer
                    .padding(20)
            }
            .background(Theme.appBG.ignoresSafeArea())
            .navigationTitle("Neue Karte")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.large])
        #endif
    }

    // MARK: - Progress

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? Theme.accentDefault : Theme.text2.opacity(0.25))
                    .frame(height: 4)
            }
        }
        .accessibilityLabel("Schritt \(step + 1) von 3")
    }

    // MARK: - Step 1: Name

    private var stepName: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeader(title: "Wer bist du?",
                       subtitle: "Name und optional Titel und Firma.")

            field(label: "Anzeigename", text: $vm.displayName,
                  placeholder: "Dominik Weckherlin")
                .onChange(of: vm.displayName) { _ in
                    if !slugEdited {
                        isAutoUpdatingSlug = true
                        vm.slug = SlugFormatter.normalize(vm.displayName)
                        isAutoUpdatingSlug = false
                    }
                }

            field(label: "Bezeichnung der Karte", text: $vm.label, placeholder: "Arbeit")
            field(label: "Titel", text: $vm.title, placeholder: "PADI Course Director")
            field(label: "Firma", text: $vm.company, placeholder: "Deep Blue Diving")

            VStack(alignment: .leading, spacing: 6) {
                field(label: "Profil-Adresse (Slug)", text: $vm.slug,
                      placeholder: "dominik-weckherlin", autocapitalize: false)
                    .onChange(of: vm.slug) { _ in if !isAutoUpdatingSlug { slugEdited = true } }
                Text("card.atoll-os.com/\(vm.slug.isEmpty ? "…" : vm.slug)")
                    .font(.atoll(size: 13))
                    .foregroundStyle(Theme.text2)
                    .padding(.leading, 4)
            }
        }
    }

    // MARK: - Step 2: Contact

    private var stepContact: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeader(title: "Wie erreicht man dich?",
                       subtitle: "Mindestens ein Kontaktweg.")

            field(label: "Telefon", text: $phone, placeholder: "+41 79 214 88 30",
                  autocapitalize: false, keyboard: .phone)
            field(label: "E-Mail", text: $email, placeholder: "dominik@deepblue.ch",
                  autocapitalize: false, keyboard: .email)
            field(label: "Website", text: $web, placeholder: "deepbluediving.ch",
                  autocapitalize: false, keyboard: .url)
        }
    }

    // MARK: - Step 3: Accent

    private var stepAccent: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeader(title: "Wähle deine Farbe",
                       subtitle: "Der Akzent deiner Karte.")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 16)], spacing: 16) {
                ForEach(accents, id: \.hex) { accent in
                    Button {
                        vm.accentColor = accent.hex
                    } label: {
                        Circle()
                            .fill(Color(hex: accent.hex))
                            .frame(width: 56, height: 56)
                            .overlay(
                                Circle().strokeBorder(
                                    vm.accentColor == accent.hex ? Theme.text : Color.clear,
                                    lineWidth: 3
                                )
                            )
                            .overlay {
                                if vm.accentColor == accent.hex {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(accent.name)
                    .accessibilityAddTraits(vm.accentColor == accent.hex ? [.isSelected, .isButton] : .isButton)
                }
            }

            if let error = vm.errorMessage {
                Text(error)
                    .font(.atoll(size: 14))
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button {
                    withAnimation { step -= 1 }
                } label: {
                    Text("Zurück")
                        .font(.atoll(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.surface, in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.separator, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            Button {
                advance()
            } label: {
                Group {
                    if isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text(step == 2 ? "Karte erstellen" : "Weiter")
                            .font(.atoll(size: 16, weight: .semibold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.accentDefault, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isSaving || !canAdvance)
            .opacity(canAdvance ? 1 : 0.5)
        }
    }

    private var canAdvance: Bool {
        switch step {
        case 0:
            return !vm.displayName.trimmingCharacters(in: .whitespaces).isEmpty
                && !vm.slug.trimmingCharacters(in: .whitespaces).isEmpty
        case 1:
            return !phone.isEmpty || !email.isEmpty || !web.isEmpty
        default:
            return true
        }
    }

    private func advance() {
        if step < 2 {
            withAnimation { step += 1 }
            return
        }
        // Final step: build fields, normalize slug, save.
        commitFields()
        vm.slug = SlugFormatter.normalize(vm.slug.isEmpty ? vm.displayName : vm.slug)
        Task {
            isSaving = true
            let ok = await vm.save()
            isSaving = false
            if ok { dismiss() }
        }
    }

    private func commitFields() {
        vm.fields.removeAll()
        if !phone.isEmpty { vm.addField(type: .phone, label: "Telefon", value: phone) }
        if !email.isEmpty { vm.addField(type: .email, label: "E-Mail", value: email) }
        if !web.isEmpty { vm.addField(type: .url, label: "Web", value: web) }
    }

    // MARK: - Reusable bits

    private func stepHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.atoll(size: 26, weight: .bold))
                .foregroundStyle(Theme.text)
            Text(subtitle)
                .font(.atoll(size: 15))
                .foregroundStyle(Theme.text2)
        }
    }

    private enum KeyboardKind { case `default`, email, phone, url }

    private func field(label: String, text: Binding<String>, placeholder: String,
                       autocapitalize: Bool = true,
                       keyboard: KeyboardKind = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.atoll(size: 13, weight: .semibold))
                .foregroundStyle(Theme.text2)
                .padding(.leading, 4)
            TextField(placeholder, text: text)
                .font(.atoll(size: 16))
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Theme.separator, lineWidth: 1)
                )
                #if os(iOS)
                .textInputAutocapitalization(autocapitalize ? .sentences : .never)
                .autocorrectionDisabled(!autocapitalize)
                .keyboardType(keyboardType(keyboard))
                #endif
        }
    }

    #if os(iOS)
    private func keyboardType(_ kind: KeyboardKind) -> UIKeyboardType {
        switch kind {
        case .default: return .default
        case .email: return .emailAddress
        case .phone: return .phonePad
        case .url: return .URL
        }
    }
    #endif
}

#Preview {
    OnboardingView(store: AppStores.preview.cardStore, ownerId: UUID())
}
