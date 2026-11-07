import UIKit

/// Decodes a cover's BlurHash (https://blurha.sh, the same hashes Finamp shows on the phone) into a small, blurred image
/// drawn until the cover itself arrives.
enum BlurHash {
    private static let cache = NSCache<NSString, UIImage>()
    private static let digits = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz#$%*+,-.:;=?@[]^_{|}~")
    private static let values = Dictionary(uniqueKeysWithValues: digits.enumerated().map { ($1, $0) })
    /// The image is scaled up to the cover's slot, so a few pixels are enough.
    private static let side = 20

    /// nil for an empty or malformed hash.
    static func image(_ hash: String) -> UIImage? {
        guard !hash.isEmpty else { return nil }
        if let cached = cache.object(forKey: hash as NSString) { return cached }
        guard let image = decode(Array(hash)) else { return nil }
        cache.setObject(image, forKey: hash as NSString)
        return image
    }

    private static func decode(_ hash: [Character]) -> UIImage? {
        guard hash.count >= 6, let sizeFlag = number(hash[0..<1]), let quantised = number(hash[1..<2]),
              let dc = number(hash[2..<6]) else { return nil }
        let columns = sizeFlag % 9 + 1, rows = sizeFlag / 9 + 1
        guard hash.count == 4 + 2 * columns * rows else { return nil }
        let maximum = Double(quantised + 1) / 166
        var colors = [(linear(dc >> 16), linear((dc >> 8) & 255), linear(dc & 255))]
        for index in 1..<(columns * rows) {
            guard let ac = number(hash[(4 + index * 2)..<(6 + index * 2)]) else { return nil }
            colors.append((
                signedSquare(Double(ac / (19 * 19)) - 9) * maximum,
                signedSquare(Double(ac / 19 % 19) - 9) * maximum,
                signedSquare(Double(ac % 19) - 9) * maximum
            ))
        }

        var pixels = [UInt8](repeating: 255, count: side * side * 4)
        for y in 0..<side {
            for x in 0..<side {
                var red = 0.0, green = 0.0, blue = 0.0
                for row in 0..<rows {
                    for column in 0..<columns {
                        let basis = cos(.pi * Double(x * column) / Double(side)) * cos(.pi * Double(y * row) / Double(side))
                        let color = colors[column + row * columns]
                        red += color.0 * basis
                        green += color.1 * basis
                        blue += color.2 * basis
                    }
                }
                let offset = (y * side + x) * 4
                pixels[offset] = sRGB(red)
                pixels[offset + 1] = sRGB(green)
                pixels[offset + 2] = sRGB(blue)
            }
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let image = CGImage(
                  width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: side * 4,
                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                  provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent
              )
        else { return nil }
        return UIImage(cgImage: image)
    }

    /// Base 83, the hash's digits.
    private static func number(_ characters: ArraySlice<Character>) -> Int? {
        var value = 0
        for character in characters {
            guard let digit = values[character] else { return nil }
            value = value * 83 + digit
        }
        return value
    }

    /// An AC component's quantised value (-9…9) back to -1…1, squared with its sign kept.
    private static func signedSquare(_ quantised: Double) -> Double {
        let value = quantised / 9
        return value < 0 ? -(value * value) : value * value
    }

    private static func linear(_ value: Int) -> Double {
        let v = Double(value) / 255
        return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
    }

    private static func sRGB(_ value: Double) -> UInt8 {
        let v = max(0, min(1, value))
        let encoded = v <= 0.0031308 ? v * 12.92 : 1.055 * pow(v, 1 / 2.4) - 0.055
        return UInt8(encoded * 255 + 0.5)
    }
}
