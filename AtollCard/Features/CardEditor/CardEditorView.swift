import SwiftUI

struct CardEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: CardEditorViewModel

    @State private var newFieldType: CardFieldType = .email
    @State private var newFieldLabel = ""
    @State private var newFieldValue = ""

    init(store: CardStoring, mediaStore: MediaStoring, ownerId: UUID, editing: Card? = nil) {
        _vm = StateObject(wrappedValue: CardEditorViewModel(store: store, mediaStore: mediaStore,
                                                            ownerId: ownerId, editing: editing))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Karte") {
                    LabeledTextField(title: "Anzeigename", text: $vm.displayName)
                    LabeledTextField(title: "Slug", text: $vm.slug, autocapitalize: false)
                    LabeledTextField(title: "Bezeichnung", text: $vm.label)
                    LabeledTextField(title: "Titel", text: $vm.title)
                    LabeledTextField(title: "Firma", text: $vm.company)

                    Picker("Sichtbarkeit", selection: $vm.visibility) {
                        ForEach(CardVisibility.allCases, id: \.self) { visibility in
                            Text(visibilityLabel(visibility)).tag(visibility)
                        }
                    }
                }

                Section("Felder") {
                    ForEach(vm.fields) { field in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(field.label.isEmpty ? field.type.rawValue : field.label)
                                .font(.subheadline)
                            Text(field.value)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Feld hinzufügen") {
                    Picker("Typ", selection: $newFieldType) {
                        ForEach(CardFieldType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    LabeledTextField(title: "Bezeichnung", text: $newFieldLabel)
                    LabeledTextField(title: "Wert", text: $newFieldValue, autocapitalize: false)
                    Button("Feld hinzufügen") {
                        vm.addField(type: newFieldType, label: newFieldLabel, value: newFieldValue)
                        newFieldLabel = ""
                        newFieldValue = ""
                    }
                    .disabled(newFieldValue.isEmpty)
                }

                if let error = vm.errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(vm.isEditing ? "Karte bearbeiten" : "Neue Karte")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        Task {
                            if await vm.save() { dismiss() }
                        }
                    }
                }
            }
        }
    }

    private func visibilityLabel(_ visibility: CardVisibility) -> String {
        switch visibility {
        case .public: return "Öffentlich"
        case .unlisted: return "Nicht gelistet"
        case .private: return "Privat"
        }
    }
}

/// A text field with a leading label that disables autocapitalization where requested (iOS only).
private struct LabeledTextField: View {
    let title: String
    @Binding var text: String
    var autocapitalize: Bool = true

    var body: some View {
        TextField(title, text: $text)
            #if os(iOS)
            .textInputAutocapitalization(autocapitalize ? .sentences : .never)
            .autocorrectionDisabled(!autocapitalize)
            #endif
    }
}

#Preview {
    CardEditorView(store: AppStores.preview.cardStore,
                   mediaStore: AppStores.preview.mediaStore, ownerId: UUID())
}
