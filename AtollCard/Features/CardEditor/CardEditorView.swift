import SwiftUI
import PhotosUI

struct CardEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: CardEditorViewModel

    @State private var newFieldType: CardFieldType = .email
    @State private var newFieldLabel = ""
    @State private var newFieldValue = ""

    @State private var photoItem: PhotosPickerItem?
    @State private var coverItem: PhotosPickerItem?
    /// Bumped whenever the persisted URLs are cleared so the preview re-evaluates
    /// (coverURL/photoURL are plain `var` on the VM, not `@Published`).
    @State private var mediaRefresh = 0

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

                Section("Bilder") {
                    mediaRow(
                        title: "Profilfoto",
                        systemImage: "person.crop.circle",
                        selection: $photoItem,
                        pendingData: vm.pendingPhotoData,
                        url: vm.photoURL,
                        isRound: true,
                        onPick: { data in vm.pendingPhotoData = data },
                        onRemove: {
                            vm.pendingPhotoData = nil
                            vm.photoURL = nil
                            photoItem = nil
                            mediaRefresh += 1
                        },
                        maxDimension: 512
                    )

                    mediaRow(
                        title: "Coverbild",
                        systemImage: "photo",
                        selection: $coverItem,
                        pendingData: vm.pendingCoverData,
                        url: vm.coverURL,
                        isRound: false,
                        onPick: { data in vm.pendingCoverData = data },
                        onRemove: {
                            vm.pendingCoverData = nil
                            vm.coverURL = nil
                            coverItem = nil
                            mediaRefresh += 1
                        },
                        maxDimension: 1600
                    )
                }
                .id(mediaRefresh)

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

    /// A picker + live preview + remove control for one image slot.
    @ViewBuilder
    private func mediaRow(
        title: String,
        systemImage: String,
        selection: Binding<PhotosPickerItem?>,
        pendingData: Data?,
        url: String?,
        isRound: Bool,
        onPick: @escaping (Data) -> Void,
        onRemove: @escaping () -> Void,
        maxDimension: CGFloat
    ) -> some View {
        let hasImage = pendingData != nil || (url.map { !$0.isEmpty } ?? false)

        VStack(alignment: .leading, spacing: 12) {
            mediaPreview(pendingData: pendingData, url: url, isRound: isRound)

            HStack {
                PhotosPicker(selection: selection, matching: .images) {
                    Label("\(title) wählen", systemImage: systemImage)
                }
                Spacer()
                if hasImage {
                    Button("Entfernen", role: .destructive, action: onRemove)
                }
            }
        }
        .onChange(of: selection.wrappedValue) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let small = ImageDownscaler.downscaledJPEG(data, maxDimension: maxDimension, quality: 0.8) {
                    onPick(small)
                }
            }
        }
    }

    @ViewBuilder
    private func mediaPreview(pendingData: Data?, url: String?, isRound: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: isRound ? 100 : 12, style: .continuous)
        let size: CGFloat = isRound ? 72 : 120

        Group {
            if let data = pendingData, let image = decodedImage(from: data) {
                image
                    .resizable()
                    .scaledToFill()
            } else if let url, let parsed = URL(string: url), !url.isEmpty {
                AsyncImage(url: parsed) { phase in
                    if let img = phase.image {
                        img.resizable().scaledToFill()
                    } else {
                        Theme.surface2
                    }
                }
            } else {
                Theme.surface2.overlay(
                    Image(systemName: isRound ? "person.crop.circle" : "photo")
                        .font(.system(size: 28))
                        .foregroundStyle(Theme.text2)
                )
            }
        }
        .frame(width: isRound ? size : nil, height: size)
        .frame(maxWidth: isRound ? nil : .infinity)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Theme.separator, lineWidth: 1))
        .accessibilityHidden(true)
    }

    /// Cross-platform in-memory decode of pending JPEG data for the preview.
    private func decodedImage(from data: Data) -> Image? {
        #if os(iOS)
        guard let ui = UIImage(data: data) else { return nil }
        return Image(uiImage: ui)
        #else
        guard let ns = NSImage(data: data) else { return nil }
        return Image(nsImage: ns)
        #endif
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
