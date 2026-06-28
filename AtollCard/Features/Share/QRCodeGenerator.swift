import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

enum QRCodeGenerator {
    static let profileBaseURL = URL(string: "https://card.atoll-os.com")!

    static func profileURL(forSlug slug: String) -> URL {
        profileBaseURL.appendingPathComponent(slug)
    }

    static func image(for url: URL) -> CIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scale = CGAffineTransform(scaleX: 10, y: 10)
        return output.transformed(by: scale)
    }
}
