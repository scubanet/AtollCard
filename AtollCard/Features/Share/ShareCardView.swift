import CoreImage
import SwiftUI

struct ShareCardView: View {
    let slug: String

    private var url: URL { QRCodeGenerator.profileURL(forSlug: slug) }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                qrImage
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 280)
                    .accessibilityLabel("QR-Code für dein AtollCard-Profil")

                Text(url.absoluteString)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)

                ShareLink(item: url) {
                    Label("Profil teilen", systemImage: "square.and.arrow.up")
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Teilen")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var qrImage: Image {
        if let ci = QRCodeGenerator.image(for: url),
           let cgImage = CIContext().createCGImage(ci, from: ci.extent) {
            return Image(decorative: cgImage, scale: 1)
        }
        return Image(systemName: "qrcode")
    }
}

#Preview {
    NavigationStack {
        ShareCardView(slug: "max-mustermann")
    }
}
