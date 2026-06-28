import XCTest
import ImageIO
import CoreGraphics
@testable import AtollCard

final class ImageDownscalerTests: XCTestCase {
    private func makeJPEG(side: Int) throws -> Data {
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        let ctx = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8,
                            bytesPerRow: 0, space: cs,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0.1, green: 0.5, blue: 0.5, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
        let img = ctx.makeImage()!
        let out = NSMutableData()
        let dest = CGImageDestinationCreateWithData(out, "public.jpeg" as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, img, nil)
        XCTAssertTrue(CGImageDestinationFinalize(dest))
        return out as Data
    }

    func test_downscalesLargeImage() throws {
        let big = try makeJPEG(side: 3000)
        let small = try XCTUnwrap(ImageDownscaler.downscaledJPEG(big, maxDimension: 512, quality: 0.8))
        XCTAssertLessThan(small.count, big.count)
        let src = CGImageSourceCreateWithData(small as CFData, nil)!
        let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as! [CFString: Any]
        let w = props[kCGImagePropertyPixelWidth] as! Int
        let h = props[kCGImagePropertyPixelHeight] as! Int
        XCTAssertLessThanOrEqual(max(w, h), 512)
    }

    func test_returnsNilForGarbage() {
        XCTAssertNil(ImageDownscaler.downscaledJPEG(Data([0x00, 0x01, 0x02]), maxDimension: 512, quality: 0.8))
    }
}
