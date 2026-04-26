import Foundation
import UIKit
import CryptoKit

// MARK: - Duck Decode Service
// Implements LSB steganography decoding compatible with SS_tools duck_encode_node v1.2
// Reference: https://github.com/copyangle/SS_tools
final class DuckDecodeService {

    static let shared = DuckDecodeService()
    private init() {}

    enum DecodeError: LocalizedError {
        case downloadFailed
        case invalidImage
        case decryptionFailed
        case invalidPassword

        var errorDescription: String? {
            switch self {
            case .downloadFailed:   return "下载鸭子图失败"
            case .invalidImage:     return "无效的图片格式"
            case .decryptionFailed: return "解码失败，请检查密码"
            case .invalidPassword:  return "密码错误"
            }
        }
    }

    // Download duck image and decode it
    func decode(imageUrl: String, password: String) async throws -> Data {
        // 1. Download image
        guard let url = URL(string: imageUrl) else { throw DecodeError.downloadFailed }
        let (data, _) = try await URLSession.shared.data(from: url)

        // 2. Decode
        return try decodeImageData(data, password: password)
    }

    // Core decode: extract hidden image from duck image using LSB steganography
    func decodeImageData(_ imageData: Data, password: String) throws -> Data {
        guard let uiImage = UIImage(data: imageData),
              let cgImage = uiImage.cgImage else {
            throw DecodeError.invalidImage
        }

        let width  = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let totalBytes = height * bytesPerRow

        var pixelData = [UInt8](repeating: 0, count: totalBytes)
        guard let context = CGContext(
            data: &pixelData,
            width: width, height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw DecodeError.invalidImage }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Derive XOR key from password using SHA-256
        let keyBytes = Array(SHA256.hash(data: Data(password.utf8)))

        // Extract LSB bits from R, G, B channels (skip alpha)
        var bits: [UInt8] = []
        bits.reserveCapacity(totalBytes * 3 / 8)

        for i in stride(from: 0, to: totalBytes, by: bytesPerPixel) {
            bits.append(pixelData[i]     & 1) // R
            bits.append(pixelData[i + 1] & 1) // G
            bits.append(pixelData[i + 2] & 1) // B
        }

        // Pack bits into bytes
        var extractedBytes: [UInt8] = []
        extractedBytes.reserveCapacity(bits.count / 8)
        for i in stride(from: 0, to: bits.count - 7, by: 8) {
            var byte: UInt8 = 0
            for j in 0..<8 { byte |= bits[i + j] << (7 - j) }
            extractedBytes.append(byte)
        }

        // First 4 bytes = length of hidden data (big-endian)
        guard extractedBytes.count >= 4 else { throw DecodeError.decryptionFailed }
        let length = Int(extractedBytes[0]) << 24
                   | Int(extractedBytes[1]) << 16
                   | Int(extractedBytes[2]) << 8
                   | Int(extractedBytes[3])

        guard length > 0, length <= extractedBytes.count - 4 else {
            throw DecodeError.decryptionFailed
        }

        // XOR decrypt with key
        var hiddenBytes = Array(extractedBytes[4..<(4 + length)])
        for i in 0..<hiddenBytes.count {
            hiddenBytes[i] ^= keyBytes[i % keyBytes.count]
        }

        let result = Data(hiddenBytes)

        // Validate: result should be a valid image
        guard UIImage(data: result) != nil else { throw DecodeError.invalidPassword }

        return result
    }

    // Detect duck_encode_node v1.2 in workflow nodes
    func detectDuckNode(in nodes: [WorkflowNodeRaw]) -> DuckNodeInfo? {
        for (index, node) in nodes.enumerated() {
            guard let classType = node.classType,
                  classType.lowercased().contains("duck_encode") else { continue }

            var password: String?
            if let inputs = node.inputs?.dictValue {
                password = inputs["password"]?.stringValue
                    ?? inputs["key"]?.stringValue
                    ?? inputs["secret"]?.stringValue
            }
            return DuckNodeInfo(
                nodeId: String(index),
                password: password,
                version: "1.2"
            )
        }
        return nil
    }
}
