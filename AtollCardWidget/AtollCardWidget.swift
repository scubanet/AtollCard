import WidgetKit
import SwiftUI
import CoreImage

struct AtollEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedCardSnapshot?
}

struct AtollProvider: TimelineProvider {
    func placeholder(in context: Context) -> AtollEntry {
        AtollEntry(date: Date(), snapshot: SharedCardSnapshot(slug: "jane-doe", displayName: "Jane Doe", accentColor: "#0E7C86"))
    }
    func getSnapshot(in context: Context, completion: @escaping (AtollEntry) -> Void) {
        completion(AtollEntry(date: Date(), snapshot: AtollAppGroup.load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<AtollEntry>) -> Void) {
        let entry = AtollEntry(date: Date(), snapshot: AtollAppGroup.load())
        completion(Timeline(entries: [entry], policy: .never))
    }
}

private func qrImage(forSlug slug: String) -> Image? {
    guard let ci = QRCodeGenerator.image(for: QRCodeGenerator.profileURL(forSlug: slug)) else { return nil }
    let ctx = CIContext()
    guard let cg = ctx.createCGImage(ci, from: ci.extent) else { return nil }
    return Image(decorative: cg, scale: 1)
}

struct AtollCardWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AtollEntry

    var body: some View {
        if let snap = entry.snapshot {
            switch family {
            case .systemSmall: small(snap)
            default: medium(snap)
            }
        } else {
            placeholder
        }
    }

    private func qr(_ slug: String, _ name: String) -> some View {
        Group {
            if let img = qrImage(forSlug: slug) {
                img.resizable().interpolation(.none).scaledToFit()
                    .accessibilityLabel("QR-Code für \(name)")
            } else {
                Image(systemName: "qrcode").resizable().scaledToFit().foregroundStyle(.secondary)
            }
        }
    }

    private func small(_ snap: SharedCardSnapshot) -> some View {
        qr(snap.slug, snap.displayName).padding(10)
    }

    private func medium(_ snap: SharedCardSnapshot) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(snap.displayName).font(.headline).lineLimit(2)
                Text("card.atoll-os.com/\(snap.slug)")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            qr(snap.slug, snap.displayName).frame(width: 96, height: 96)
        }
        .padding(14)
    }

    private var placeholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "qrcode").font(.title)
            Text("In AtollCard anmelden, um deine Karte zu zeigen.")
                .font(.caption).multilineTextAlignment(.center).foregroundStyle(.secondary)
        }
        .padding()
    }
}

struct AtollCardWidget: Widget {
    let kind = "AtollCardWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AtollProvider()) { entry in
            AtollCardWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("AtollCard")
        .description("Zeigt deine aktive Karte als QR-Code.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct AtollCardWidgetBundle: WidgetBundle {
    var body: some Widget { AtollCardWidget() }
}
