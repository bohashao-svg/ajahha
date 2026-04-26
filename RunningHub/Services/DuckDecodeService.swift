import Foundation
import UIKit
import CryptoKit
import AVFoundation

// MARK: - Duck Decode Service
// Ported from SS_tools duck_encode_node v1.2 (content.js)
// Algorithm: LSB steganography with optional SHA-256 stream cipher encryption
final class DuckDecodeService {

    static let shared = DuckDecodeService()
    private init() {}

    // Watermark skip ratios (matches JS: WATERMARK_SKIP_W_RATIO=0.4, WATERMARK_SKIP_H_RATIO=0.08)
    private let skipWRatio: Double = 0.4
    private let skipHRatio: Double = 0.08
    // LSB bit depths to try in order (matches JS: COMPRESS_LEVELS=[2,6,8])
    private let compressLevels: [Int] = [2, 6, 8]

    enum DecodeError: LocalizedError {
        case downloadFailed
        case invalidImage
        case needPassword
        case wrongPassword
        case decodeFailed(String)

        var errorDescription: String? {
            switch self {
            case .downloadFailed:    return "下载鸭子图失败"
            case .invalidImage:      return "无效的图片格式"
            case .needPassword:      return "该鸭子图需要密码解码"
            case .wrongPassword:     return "密码错误"
            case .decodeFailed(let m): return "解码失败: \(m)"
            }
        }
    }

    // MARK: - Public API

    var videoExtensions: Set<String> { ["mp4", "mov", "webm", "avi", "mkv"] }

    func isVideoUrl(_ urlString: String) -> Bool {
        let ext = urlString.split(separator: ".").last?.lowercased() ?? ""
        return videoExtensions.contains(String(ext))
    }

    func decode(imageUrl: String, password: String) async throws -> Data {
        guard let url = URL(string: imageUrl) else { throw DecodeError.downloadFailed }

        if isVideoUrl(imageUrl) {
            // Extract first frame from video, then decode LSB from that frame
            let frameImage = try await extractFirstFrame(from: url)
            guard let cgImage = frameImage.cgImage else { throw DecodeError.invalidImage }
            return try decodeFromCGImage(cgImage, password: password)
        } else {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try decodeImageData(data, password: password)
        }
    }

    private func extractFirstFrame(from url: URL) async throws -> UIImage {
        return try await withCheckedThrowingContinuation { continuation in
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero

            let time = CMTime(seconds: 0, preferredTimescale: 600)
            generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, cgImage, _, result, error in
                if let cgImage = cgImage, result == .succeeded {
                    continuation.resume(returning: UIImage(cgImage: cgImage))
                } else {
                    continuation.resume(throwing: DecodeError.downloadFailed)
                }
            }
        }
    }

    func decodeImageData(_ imageData: Data, password: String) throws -> Data {
        guard let uiImage = UIImage(data: imageData),
              let cgImage = uiImage.cgImage else { throw DecodeError.invalidImage }
        return try decodeFromCGImage(cgImage, password: password)
    }

    func decodeFromCGImage(_ cgImage: CGImage, password: String) throws -> Data {
        let width  = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow   = width * bytesPerPixel
        let totalBytes    = height * bytesPerRow

        var pixelData = [UInt8](repeating: 0, count: totalBytes)
        guard let ctx = CGContext(
            data: &pixelData,
            width: width, height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { throw DecodeError.invalidImage }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Skip watermark region (top-left corner)
        let skipW = Int(Double(width)  * skipWRatio)
        let skipH = Int(Double(height) * skipHRatio)

        // Extract valid RGB bytes (skip watermark area)
        let rgbBytes = extractValidRGB(pixels: pixelData,
                                       width: width, height: height,
                                       skipW: skipW, skipH: skipH)

        // Try each compress level
        for k in compressLevels {
            do {
                let result = try tryExtract(rgbBytes: rgbBytes, k: k, password: password)
                return result
            } catch DecodeError.needPassword {
                throw DecodeError.needPassword
            } catch DecodeError.wrongPassword {
                throw DecodeError.wrongPassword
            } catch {
                continue
            }
        }
        throw DecodeError.decodeFailed("所有解码级别均失败")
    }

    // MARK: - Detect duck_encode_node in workflow
    func detectDuckNode(in nodes: [WorkflowNodeRaw]) -> DuckNodeInfo? {
        for (index, node) in nodes.enumerated() {
            guard let classType = node.classType else { continue }
            let lower = classType.lowercased()
            // Matches: DuckHideNode, duck_encode_node, DuckEncode, etc.
            guard lower.contains("duck") else { continue }
            var password: String?
            if let inputs = node.inputs?.dictValue {
                password = inputs["password"]?.stringValue
                    ?? inputs["key"]?.stringValue
                    ?? inputs["secret"]?.stringValue
            }
            return DuckNodeInfo(nodeId: String(index), password: password, version: "1.2")
        }
        return nil
    }

    // MARK: - Internal

    /// Extract RGB bytes skipping the watermark region (top-left skipW x skipH)
    private func extractValidRGB(pixels: [UInt8], width: Int, height: Int,
                                  skipW: Int, skipH: Int) -> [UInt8] {
        let totalPixels = width * height - skipW * skipH
        var rgb = [UInt8](repeating: 0, count: totalPixels * 3)
        var idx = 0
        for row in 0..<height {
            for col in 0..<width {
                if row < skipH && col < skipW { continue }
                let base = (row * width + col) * 4
                rgb[idx]     = pixels[base]
                rgb[idx + 1] = pixels[base + 1]
                rgb[idx + 2] = pixels[base + 2]
                idx += 3
            }
        }
        return rgb
    }

    /// Try to extract hidden data using k LSBs per channel
    private func tryExtract(rgbBytes: [UInt8], k: Int, password: String) throws -> Data {
        var stream = LsbStream(rgbBytes: rgbBytes, k: k)

        // Read header length (4 bytes big-endian)
        let lenBytes = try stream.readBytes(4)
        let headerLen = UInt32(lenBytes[0]) << 24
                      | UInt32(lenBytes[1]) << 16
                      | UInt32(lenBytes[2]) << 8
                      | UInt32(lenBytes[3])

        guard headerLen > 0, headerLen <= UInt32(rgbBytes.count) else {
            throw DecodeError.decodeFailed("Invalid header length: \(headerLen)")
        }

        let header = try stream.readBytes(Int(headerLen))
        var pos = 0

        // Byte 0: encrypted flag
        let isEncrypted = header[pos] == 1
        pos += 1

        var storedHash: [UInt8]? = nil
        var salt: [UInt8]? = nil

        if isEncrypted {
            guard pos + 48 <= header.count else {
                throw DecodeError.decodeFailed("Header too short for auth")
            }
            storedHash = Array(header[pos..<pos+32])
            pos += 32
            salt = Array(header[pos..<pos+16])
            pos += 16
        }

        // Extension string length (1 byte) + extension string
        let extLen = Int(header[pos])
        pos += 1
        let extBytes = Array(header[pos..<pos+extLen])
        let ext = String(bytes: extBytes, encoding: .utf8) ?? ""
        pos += extLen

        // Data length (4 bytes big-endian)
        guard pos + 4 <= header.count else {
            throw DecodeError.decodeFailed("Header too short for data length")
        }
        let dataLen = UInt32(header[pos]) << 24
                    | UInt32(header[pos+1]) << 16
                    | UInt32(header[pos+2]) << 8
                    | UInt32(header[pos+3])
        pos += 4

        let payload = Array(header[pos...])
        guard payload.count == Int(dataLen) else {
            throw DecodeError.decodeFailed("Data length mismatch")
        }

        var result = payload

        if isEncrypted {
            guard !password.isEmpty else { throw DecodeError.needPassword }
            guard let saltBytes = salt, let hashBytes = storedHash else {
                throw DecodeError.decodeFailed("Missing salt or hash")
            }

            // Verify password: SHA-256(password + hex(salt)) == storedHash
            let saltHex = saltBytes.map { String(format: "%02x", $0) }.joined()
            let verifyInput = Data((password + saltHex).utf8)
            let computed = Array(SHA256.hash(data: verifyInput))
            guard computed == hashBytes else { throw DecodeError.wrongPassword }

            // Decrypt: XOR with SHA-256(password + hex(salt) + counter) stream
            result = try decryptData(payload, password: password, salt: saltBytes)
        }

        // Handle .binpng format (video encoded as PNG pixels)
        var finalData = Data(result)
        if ext.lowercased().hasSuffix(".binpng") {
            finalData = try convertBinPngToBytes(finalData)
        }

        _ = ext  // extension info available if needed
        return finalData
    }

    /// XOR stream cipher: key stream = SHA-256(password + hex(salt) + "0"), SHA-256(...+"1"), ...
    private func decryptData(_ data: [UInt8], password: String, salt: [UInt8]) throws -> [UInt8] {
        let saltHex = salt.map { String(format: "%02x", $0) }.joined()
        let baseKey = Data((password + saltHex).utf8)

        var output = [UInt8](repeating: 0, count: data.count)
        var pos = 0
        var counter = 0

        while pos < data.count {
            let counterData = Data(String(counter).utf8)
            var combined = baseKey
            combined.append(counterData)
            let block = Array(SHA256.hash(data: combined))
            let chunk = min(32, data.count - pos)
            for i in 0..<chunk {
                output[pos + i] = data[pos + i] ^ block[i]
            }
            pos += chunk
            counter += 1
        }
        return output
    }

    /// Convert binpng (video bytes stored as RGB pixels) back to raw bytes
    private func convertBinPngToBytes(_ pngData: Data) throws -> Data {
        guard let uiImage = UIImage(data: pngData),
              let cgImage = uiImage.cgImage else { throw DecodeError.invalidImage }

        let width  = cgImage.width
        let height = cgImage.height
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let ctx = CGContext(
            data: &pixels,
            width: width, height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { throw DecodeError.invalidImage }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let total = width * height * 3
        var rgb = [UInt8](repeating: 0, count: total)
        var idx = 0
        for i in stride(from: 0, to: pixels.count, by: 4) {
            rgb[idx]     = pixels[i]
            rgb[idx + 1] = pixels[i + 1]
            rgb[idx + 2] = pixels[i + 2]
            idx += 3
        }
        // Strip trailing zeros
        var end = rgb.count
        while end > 0 && rgb[end - 1] == 0 { end -= 1 }
        return Data(rgb[0..<end])
    }
}

// MARK: - LSB Stream Reader
private struct LsbStream {
    let rgbBytes: [UInt8]
    let k: Int
    let bitMask: UInt32

    private var rgbIdx: Int = 0
    private var bitBuffer: UInt32 = 0
    private var bitCount: Int = 0

    init(rgbBytes: [UInt8], k: Int) {
        self.rgbBytes = rgbBytes
        self.k = k
        self.bitMask = (1 << k) - 1
    }

    mutating func readBytes(_ count: Int) throws -> [UInt8] {
        var result = [UInt8](repeating: 0, count: count)
        for i in 0..<count { result[i] = try readByte() }
        return result
    }

    mutating func readByte() throws -> UInt8 {
        while bitCount < 8 {
            guard rgbIdx < rgbBytes.count else {
                throw DuckDecodeService.DecodeError.decodeFailed("Unexpected end of stream")
            }
            let bits = UInt32(rgbBytes[rgbIdx]) & bitMask
            rgbIdx += 1
            bitBuffer = (bitBuffer << k) | bits
            bitCount += k
        }
        let shift = bitCount - 8
        let byte = UInt8((bitBuffer >> shift) & 0xFF)
        bitCount -= 8
        bitBuffer &= (1 << bitCount) - 1
        return byte
    }
}
