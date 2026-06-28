import SwiftUI

/// The dark teal glass business card matching `card.png`.
/// Dark surface with a teal radial glow behind the avatar, circular initials
/// avatar, name/title/company, a hairline divider, then field rows with a
/// circular dark icon badge + bold value + muted label. A QR button (top-right)
/// triggers share; the whole card body is tappable to edit.
struct BusinessCardView: View {
    let card: Card
    let fields: [CardField]
    let onShare: () -> Void
    let onEdit: () -> Void

    private var accent: Color { Color(hex: card.accentColor) }

    private var initials: String {
        let parts = card.displayName
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
        let s = String(parts).uppercased()
        return s.isEmpty ? "?" : s
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top row: avatar + QR button
            HStack(alignment: .top) {
                avatar
                Spacer()
                Button(action: onShare) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("QR-Code teilen")
            }
            .padding(.bottom, 26)

            // Identity
            Text(card.displayName)
                .font(.atoll(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            if let title = card.title, !title.isEmpty {
                Text(title)
                    .font(.atoll(size: 17, weight: .semibold))
                    .foregroundStyle(accentForeground)
                    .padding(.top, 6)
            }

            if let company = card.company, !company.isEmpty {
                Text(company)
                    .font(.atoll(size: 15, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .padding(.top, 2)
            }

            if !fields.isEmpty {
                Divider()
                    .overlay(Color.white.opacity(0.12))
                    .padding(.vertical, 20)

                VStack(spacing: 18) {
                    ForEach(fields) { field in
                        FieldRow(field: field)
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.25), radius: 28, x: 0, y: 16)
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onTapGesture(perform: onEdit)
        .accessibilityElement(children: .contain)
        .accessibilityHint("Doppeltippen zum Bearbeiten")
    }

    /// Slightly lighten the accent for legibility on the dark surface.
    private var accentForeground: Color {
        accent.opacity(0.95)
    }

    @ViewBuilder
    private var avatar: some View {
        Group {
            if let photoURL = card.photoURL, let url = URL(string: photoURL), !photoURL.isEmpty {
                AsyncImage(url: url) { phase in
                    if let img = phase.image {
                        img.resizable().scaledToFill()
                    } else {
                        initialsAvatar
                    }
                }
                .frame(width: 76, height: 76)
                .clipShape(Circle())
            } else {
                initialsAvatar
            }
        }
        .shadow(color: accent.opacity(0.6), radius: 18, x: 0, y: 0)
        .accessibilityHidden(true)
    }

    private var initialsAvatar: some View {
        Circle()
            .fill(accent)
            .frame(width: 76, height: 76)
            .overlay(
                Text(initials)
                    .font(.atoll(size: 26, weight: .bold))
                    .foregroundStyle(.white)
            )
    }

    /// Dark base with a teal radial glow emanating from the top-left (avatar).
    /// If a cover image exists it is layered on top of the glow; the gradient
    /// remains the placeholder/failure fallback.
    private var cardBackground: some View {
        ZStack {
            Color(hex: "#0E1116")
            RadialGradient(
                colors: [accent.opacity(0.45), accent.opacity(0.0)],
                center: UnitPoint(x: 0.18, y: 0.16),
                startRadius: 0,
                endRadius: 320
            )
            if let coverURL = card.coverURL, let url = URL(string: coverURL), !coverURL.isEmpty {
                AsyncImage(url: url) { phase in
                    if let img = phase.image {
                        img.resizable().scaledToFill()
                    } else {
                        Color.clear
                    }
                }
                // Darken for legibility of the white text over arbitrary photos.
                .overlay(Color.black.opacity(0.35))
            }
            LinearGradient(
                colors: [Color.white.opacity(0.04), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .accessibilityHidden(true)
    }
}

/// One contact field: circular dark icon badge, bold value, muted label below.
private struct FieldRow: View {
    let field: CardField

    private var icon: String {
        switch field.type {
        case .phone:   return "phone.fill"
        case .email:   return "envelope.fill"
        case .url:     return "globe"
        case .social:  return "at"
        case .address: return "mappin.and.ellipse"
        case .custom:  return "link"
        }
    }

    private var fallbackLabel: String {
        switch field.type {
        case .phone:   return "Telefon"
        case .email:   return "E-Mail"
        case .url:     return "Web"
        case .social:  return "Social"
        case .address: return "Adresse"
        case .custom:  return "Sonstiges"
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.10), in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                Text(field.value)
                    .font(.atoll(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text((field.label.isEmpty ? fallbackLabel : field.label).uppercased())
                    .font(.atoll(size: 11, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(Color.white.opacity(0.45))
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(field.label.isEmpty ? fallbackLabel : field.label): \(field.value)")
    }
}

#Preview {
    ScrollView {
        BusinessCardView(
            card: Card(
                id: UUID(), ownerId: UUID(), slug: "dominik-weckherlin",
                label: "Arbeit", displayName: "Dominik Weckherlin",
                title: "PADI Course Director", company: "Deep Blue Diving",
                theme: "default", accentColor: "#0E7C86",
                visibility: .public, isActive: true
            ),
            fields: [
                CardField(id: UUID(), type: .phone, label: "Telefon", value: "+41 79 214 88 30", sortOrder: 0),
                CardField(id: UUID(), type: .email, label: "E-Mail", value: "dominik@deepblue.ch", sortOrder: 1),
                CardField(id: UUID(), type: .url, label: "Web", value: "deepbluediving.ch", sortOrder: 2),
            ],
            onShare: {}, onEdit: {}
        )
        .padding()
    }
    .background(Theme.appBG)
}
