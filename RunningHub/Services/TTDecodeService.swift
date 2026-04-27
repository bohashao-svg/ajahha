import Foundation
import UIKit
import CryptoKit

// MARK: - TT Tool Decode Service
// Supports: V2 (RGB direct write, color image)
// Encryption: none / RSA (local/net) / ChaCha20
final class TTDecodeService {

    static let shared = TTDecodeService()
    private init() {}

    // MARK: - Public API

    enum DecodeError: LocalizedError {
        case invalidImage
        case downloadFailed
        case needPassword
        case wrongPassword
        case expired(String)
        case unsupportedFormat
        case decodeFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidImage:        return "无效的图片格式"
            case .downloadFailed:      return "下载图片失败"
            case .needPassword:        return "该图片需要密码解码"
            case .wrongPassword:       return "密码错误"
            case .expired(let d):      return "文件已过期：\(d)"
            case .unsupportedFormat:   return "不是 TT tool 隐写图片"
            case .decodeFailed(let m): return "解码失败：\(m)"
            }
        }
    }

    struct TTFile {
        let data: Data
        let ext: String
        let format: String
    }

    func decode(imageUrl: String, password: String) async throws -> TTFile {
        guard let url = URL(string: imageUrl) else { throw DecodeError.downloadFailed }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try decodeImageData(data, password: password)
    }

    func decodeImageData(_ imageData: Data, password: String) throws -> TTFile {
        guard let uiImage = UIImage(data: imageData),
              let cgImage = uiImage.cgImage else { throw DecodeError.invalidImage }
        return try decodeFromCGImage(cgImage, password: password)
    }

    func decodeFromCGImage(_ cgImage: CGImage, password: String) throws -> TTFile {
        let width  = cgImage.width
        let height = cgImage.height
        let bpr    = width * 4
        var pixels = [UInt8](repeating: 0, count: height * bpr)
        guard let ctx = CGContext(data: &pixels, width: width, height: height,
                                  bitsPerComponent: 8, bytesPerRow: bpr,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
            throw DecodeError.invalidImage
        }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        if let v2 = tryV2(pixels: pixels, width: width, height: height, password: password) {
            return v2
        }
        throw DecodeError.unsupportedFormat
    }

    // MARK: - Detect TT node in workflow
    func detectTTNode(in nodes: [WorkflowNodeRaw]) -> Bool {
        nodes.contains { node in
            let ct    = node.classType?.lowercased() ?? ""
            let title = node.meta?.title?.lowercased() ?? ""
            let combined = ct + " " + title
            return combined.contains("tt img enc")
                || combined.contains("ttimgenc")
                || combined.contains("tt_img_enc")
                || combined.contains("tttool")
                || combined.contains("tt_tool")
        }
    }
}

// MARK: - Crypto (ChaCha20 + TinyRSA + key derivation)
extension TTDecodeService {

    // TTRSAv2 local RSA keypair
    private var rsaLocalN: String { "8780D06EF9DA6B96CD69A842B62C2DA8EFF89B9BC33F6A7935C7839DCE1A0C722BB1300397805EC1F5143A3AF2F9201AE567219C70A3F749BDD0625D466BC777F5558C9777C65D26A8B202371C1BBB9E630B2D79629DC66863161E769B3D46E7428A92EE518D0DFBDB9BBCF8ABFE6D5CD296363C964E9C775B200B720DFE31B1" }
    private var rsaLocalD: String { "5FD5A415091308CAE446D8E12DD4BB0A6386720FCD1C79E2763DC0818875F5DD7DB7589D01B6A1CE0DD69B847BB9E49201335A9B39334E3F5247227A93C6C090B007ADB7A1BD1B3A97C59943A738A041133B97F81DEDEF883E8D19C44B0158DFEAF5F0C3CEEA906CDC0D68D180196EB92153507D9E7AFCF310D59BA907AAC34D" }

    // TTNETv2 RSA Net keypair (server key)
    private var rsaNetN: String { "B691A71AD927A3B0108F2C9456A7F27216D892D34E787BA2E3EFD51CCAFED38151693043EB23C40472BCF8897330CF0EC739DCC301201255C5E4C7AC48DEE08EEE459FFC08655374FB2E37358892120F513582B47CCF259CD960220C215BA6857AC03982CFCEA13863EA60F163B1FAAC87E8FD33D279D5B779D0B9A1F3FEFA6F" }
    private var rsaNetD: String { "8500973C77F6E8C8DB4772B29E6EBBB161F365038BA73A6AF0A3481E31C47351427DDF2B9BA1F2AB4AEB6024C2464C91F791AFC2608F7CCBFFDF2B97D77E87185E756FB411B17AA2F87A88D89C58FDBF26501262162A9A3E83199701349CE17095208B0BFB29C44EA919709F7670DAAC85F316431AA366C0EE20CB2A516F6801" }

    var defaultPassword: String { "xiaosi666" }

    private func sha256Hex(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    func hexToBytes(_ hex: String) -> [UInt8] {
        var bytes = [UInt8](); var i = hex.startIndex
        while i < hex.endIndex {
            let j = hex.index(i, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
            bytes.append(UInt8(hex[i..<j], radix: 16) ?? 0); i = j
        }
        return bytes
    }

    // ChaCha20 key derivation: 1000 SHA-256 rounds then XOR mix
    func deriveChaCha20Key(_ password: String, suffix: String) -> [UInt8] {
        var mat = password + suffix
        for i in 0..<1000 { mat = sha256Hex(mat + String(i)) }
        let kb = hexToBytes(mat)
        var key = [UInt8](repeating: 0, count: 32)
        for i in 0..<32 {
            key[i] = kb[i % kb.count] ^ UInt8((13 * i) & 0xFF) ^ UInt8((7 * (i / kb.count)) & 0xFF) ^ 170
        }
        return key
    }

    // RSA hybrid decrypt: matches Python rsa_hybrid_decrypt
    // keySuffix / pwSuffix differ by format (SM2 vs RSA)
    func decryptRSAHybrid(_ data: [UInt8], password: String, nHex: String, dHex: String,
                          pwSuffix: String, keySuffix: String) -> [UInt8]? {
        let pw = password.isEmpty ? defaultPassword : password
        let chaKey = deriveChaCha20Key(pw, suffix: keySuffix)
        guard data.count >= 32 else { return nil }
        let storedCheck = Array(data[0..<16])
        let expected    = Array(hexToBytes(sha256Hex(pw + pwSuffix)).prefix(16))
        guard storedCheck == expected else { return nil }
        var off = 16
        guard off + 4 <= data.count else { return nil }
        let keyLen = Int(UInt32(data[off]) << 24 | UInt32(data[off+1]) << 16 | UInt32(data[off+2]) << 8 | UInt32(data[off+3]))
        off += 4
        guard off + keyLen + 12 <= data.count else { return nil }
        let doubleEncKey = Array(data[off..<(off + keyLen)]); off += keyLen
        let nonce        = Array(data[off..<(off + 12)]);     off += 12
        let cipherData   = Array(data[off...])
        // Decrypt key block with ChaCha20 (full 12-byte nonce)
        let combinedKey  = chacha20(doubleEncKey, key: chaKey, nonce: nonce, counter: 0)
        guard let nBig = TTBigUInt(nHex) else { return nil }
        let rsaLen = (nBig.bitWidth + 7) / 8
        let rsaHex = combinedKey.prefix(rsaLen).map { String(format: "%02x", $0) }.joined()
        guard let decKey = rsaDecryptHex(rsaHex, dHex: dHex, nHex: nHex), decKey.count == 32 else { return nil }
        // Decrypt payload with ChaCha20 (full 12-byte nonce)
        return chacha20(cipherData, key: decKey, nonce: nonce, counter: 0)
    }

    private func rsaDecryptHex(_ cipherHex: String, dHex: String, nHex: String) -> [UInt8]? {
        guard let c = TTBigUInt(cipherHex),
              let d = TTBigUInt(dHex),
              let n = TTBigUInt(nHex) else { return nil }
        let plain = c.power(d, modulus: n)
        var bytes = plain.serialize()
        let keyLen = (n.bitWidth + 7) / 8
        while bytes.count < keyLen { bytes.insert(0, at: 0) }
        guard bytes.count >= 4, bytes[0] == 0, bytes[1] == 2 else { return bytes }
        var i = 2; while i < bytes.count && bytes[i] != 0 { i += 1 }
        guard i < bytes.count else { return bytes }
        return Array(bytes[(i+1)...])
    }

    func chacha20(_ data: [UInt8], key: [UInt8], nonce: [UInt8], counter: UInt32) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: data.count)
        var offset = 0; var bc = counter
        while offset < data.count {
            let ks = chacha20Block(key: key, nonce: nonce, counter: bc); bc += 1
            let chunk = min(64, data.count - offset)
            for i in 0..<chunk { out[offset + i] = data[offset + i] ^ ks[i] }
            offset += chunk
        }
        return out
    }

    private func chacha20Block(key: [UInt8], nonce: [UInt8], counter: UInt32) -> [UInt8] {
        let sigma: [UInt32] = [0x61707865, 0x3320646e, 0x79622d32, 0x6b206574]
        var s = [UInt32](repeating: 0, count: 16)
        s[0]=sigma[0]; s[1]=sigma[1]; s[2]=sigma[2]; s[3]=sigma[3]
        for i in 0..<8 {
            let b = i*4
            s[4+i] = UInt32(key[b]) | UInt32(key[b+1])<<8 | UInt32(key[b+2])<<16 | UInt32(key[b+3])<<24
        }
        s[12] = counter
        // 12-byte nonce: word 13 = nonce[0..3], word 14 = nonce[4..7], word 15 = nonce[8..11]
        let n12 = nonce + [UInt8](repeating: 0, count: max(0, 12 - nonce.count))
        s[13] = UInt32(n12[0])|UInt32(n12[1])<<8|UInt32(n12[2])<<16|UInt32(n12[3])<<24
        s[14] = UInt32(n12[4])|UInt32(n12[5])<<8|UInt32(n12[6])<<16|UInt32(n12[7])<<24
        s[15] = UInt32(n12[8])|UInt32(n12[9])<<8|UInt32(n12[10])<<16|UInt32(n12[11])<<24
        var w = s
        func qr(_ a: Int,_ b: Int,_ c: Int,_ d: Int) {
            w[a] &+= w[b]; w[d] ^= w[a]; w[d] = w[d]<<16 | w[d]>>16
            w[c] &+= w[d]; w[b] ^= w[c]; w[b] = w[b]<<12 | w[b]>>20
            w[a] &+= w[b]; w[d] ^= w[a]; w[d] = w[d]<<8  | w[d]>>24
            w[c] &+= w[d]; w[b] ^= w[c]; w[b] = w[b]<<7  | w[b]>>25
        }
        for _ in 0..<10 {
            qr(0,4,8,12); qr(1,5,9,13); qr(2,6,10,14); qr(3,7,11,15)
            qr(0,5,10,15); qr(1,6,11,12); qr(2,7,8,13); qr(3,4,9,14)
        }
        var out = [UInt8](repeating: 0, count: 64)
        for i in 0..<16 {
            let v = w[i] &+ s[i]
            out[i*4]=UInt8(v&0xFF); out[i*4+1]=UInt8((v>>8)&0xFF)
            out[i*4+2]=UInt8((v>>16)&0xFF); out[i*4+3]=UInt8((v>>24)&0xFF)
        }
        return out
    }
}

// MARK: - Minimal BigUInt for RSA modPow
private struct TTBigUInt {
    var words: [UInt64]  // little-endian 64-bit limbs

    init(_ v: UInt64 = 0) { words = v == 0 ? [] : [v] }
    init?(_ hex: String) {
        var h = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        words = []
        while !h.isEmpty {
            let chunk = String(h.suffix(16)); h = String(h.dropLast(chunk.count))
            guard let v = UInt64(chunk, radix: 16) else { return nil }
            words.append(v)
        }
        trim()
    }
    mutating func trim() { while words.last == 0 { words.removeLast() } }
    var isZero: Bool { words.isEmpty }
    var bitWidth: Int {
        guard let top = words.last else { return 0 }
        return (words.count-1)*64 + (64 - top.leadingZeroBitCount)
    }
    func serialize() -> [UInt8] {
        var out = [UInt8]()
        for w in words.reversed() { for i in stride(from:56,through:0,by: -8) { out.append(UInt8((w>>i)&0xFF)) } }
        while out.first == 0 && out.count > 1 { out.removeFirst() }
        return out
    }
    static func <(l: TTBigUInt, r: TTBigUInt) -> Bool {
        if l.words.count != r.words.count { return l.words.count < r.words.count }
        for i in stride(from: l.words.count-1, through: 0, by: -1) {
            if l.words[i] != r.words[i] { return l.words[i] < r.words[i] }
        }
        return false
    }
    static func +(l: TTBigUInt, r: TTBigUInt) -> TTBigUInt {
        var out=[UInt64](); var carry: UInt64=0
        for i in 0..<max(l.words.count,r.words.count) {
            let a=i<l.words.count ? l.words[i]:0; let b=i<r.words.count ? r.words[i]:0
            let (s1,o1)=a.addingReportingOverflow(b); let (s2,o2)=s1.addingReportingOverflow(carry)
            out.append(s2); carry=(o1 ? 1:0)+(o2 ? 1:0)
        }
        if carry>0 { out.append(carry) }
        var r=TTBigUInt(); r.words=out; return r
    }
    static func -(l: TTBigUInt, r: TTBigUInt) -> TTBigUInt {
        var out=[UInt64](); var borrow: UInt64=0
        for i in 0..<l.words.count {
            let a=l.words[i]; let b=i<r.words.count ? r.words[i]:0
            let (s1,o1)=a.subtractingReportingOverflow(b); let (s2,o2)=s1.subtractingReportingOverflow(borrow)
            out.append(s2); borrow=(o1 ? 1:0)+(o2 ? 1:0)
        }
        var res=TTBigUInt(); res.words=out; res.trim(); return res
    }
    static func *(l: TTBigUInt, r: TTBigUInt) -> TTBigUInt {
        var out=[UInt64](repeating:0,count:l.words.count+r.words.count)
        for i in 0..<l.words.count {
            var carry: UInt64=0
            for j in 0..<r.words.count {
                let (hi,lo)=l.words[i].multipliedFullWidth(by:r.words[j])
                let (s1,o1)=out[i+j].addingReportingOverflow(lo)
                let (s2,o2)=s1.addingReportingOverflow(carry)
                out[i+j]=s2; carry=hi+(o1 ? 1:0)+(o2 ? 1:0)
            }
            out[i+r.words.count] &+= carry
        }
        var res=TTBigUInt(); res.words=out; res.trim(); return res
    }
    static func %(l: TTBigUInt, r: TTBigUInt) -> TTBigUInt {
        guard !r.isZero else { return l }
        if l < r { return l }
        var rem=TTBigUInt()
        for i in stride(from: l.bitWidth-1, through: 0, by: -1) {
            rem = rem << 1
            let wi=i/64, bi=i%64
            if wi<l.words.count && (l.words[wi]>>bi)&1==1 {
                if rem.isZero { rem.words=[1] } else { rem.words[0]|=1 }
            }
            if !(rem < r) { rem = rem - r }
        }
        return rem
    }
    static func <<(lhs: TTBigUInt, rhs: Int) -> TTBigUInt {
        let ws=rhs/64, bs=rhs%64
        var out=[UInt64](repeating:0,count:lhs.words.count+ws+1)
        for i in 0..<lhs.words.count {
            out[i+ws] |= lhs.words[i]<<bs
            if bs>0 { out[i+ws+1] |= lhs.words[i]>>(64-bs) }
        }
        var r=TTBigUInt(); r.words=out; r.trim(); return r
    }
    static func >>(lhs: TTBigUInt, rhs: Int) -> TTBigUInt {
        let ws=rhs/64, bs=rhs%64
        guard ws<lhs.words.count else { return TTBigUInt() }
        var out=[UInt64]()
        for i in ws..<lhs.words.count {
            var v=lhs.words[i]>>bs
            if bs>0 && i+1<lhs.words.count { v|=lhs.words[i+1]<<(64-bs) }
            out.append(v)
        }
        var r=TTBigUInt(); r.words=out; r.trim(); return r
    }
    func power(_ exp: TTBigUInt, modulus: TTBigUInt) -> TTBigUInt {
        var result=TTBigUInt(1); var base=self%modulus; var e=exp
        while !e.isZero {
            if e.words[0]&1==1 { result=(result*base)%modulus }
            base=(base*base)%modulus; e=e>>1
        }
        return result
    }
}

// MARK: - V2 (RGB direct write, color image) decoder
extension TTDecodeService {

    // Magic bytes
    private static let MAGIC_TTV2:    [UInt8] = [84,84,118,50]
    private static let MAGIC_TTSM2V2: [UInt8] = [84,84,83,77,50,118,50]
    private static let MAGIC_TTRSAV2: [UInt8] = [84,84,82,83,65,118,50]
    private static let MAGIC_TTNETV2: [UInt8] = [84,84,78,69,84,118,50]
    private static let MAGIC_TTNETV3: [UInt8] = [84,84,78,69,84,118,51]
    private static let MAGIC_TTPWV2:  [UInt8] = [84,84,80,87,118,50]

    private func matchMagic(_ rgb: [UInt8], at offset: Int, magic: [UInt8]) -> Bool {
        guard offset + magic.count <= rgb.count else { return false }
        for i in 0..<magic.count { if rgb[offset + i] != magic[i] { return false } }
        return true
    }

    private func rgbaToRgb(_ pixels: [UInt8], width: Int, height: Int) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: width * height * 3)
        var k = 0
        for i in 0..<(width * height) {
            let b = i * 4
            out[k] = pixels[b]; out[k+1] = pixels[b+1]; out[k+2] = pixels[b+2]
            k += 3
        }
        return out
    }

    private func crc16(_ bytes: ArraySlice<UInt8>) -> UInt16 {
        var crc: UInt16 = 0xFFFF
        for byte in bytes {
            crc ^= UInt16(byte) << 8
            for _ in 0..<8 {
                crc = (crc & 0x8000) != 0 ? (crc << 1) ^ 0x1021 : crc << 1
            }
        }
        return crc
    }

    private struct V2ParseResult {
        let file: TTFile?
        let encryptedData: [UInt8]?
        let ext: String
        let format: String
        let needsDecrypt: Bool
        let isExpired: Bool
        let expiryStr: String
    }

    private func parseV2Inner(_ rgb: [UInt8], offset: Int, headerLen: Int, crc: UInt16, totalNeeded: Int, format: String) -> V2ParseResult? {
        guard offset + totalNeeded <= rgb.count else { return nil }
        let inner = Array(rgb[(offset + headerLen)..<(offset + totalNeeded)])
        guard crc16(inner[...]) == crc else { return nil }
        guard inner.count >= 3 else { return nil }

        let version = inner[0]
        let extLen  = Int(inner[2])
        guard version == 2, inner.count >= 3 + extLen + 4 else { return nil }

        let ext = String(bytes: inner[3..<(3 + extLen)], encoding: .utf8) ?? "bin"

        // Check expiry (8 bytes after ext)
        var dataLenOffset = 3 + extLen
        if inner.count >= 3 + extLen + 8 + 4 {
            var ts: UInt64 = 0
            for i in 0..<8 { ts = ts * 256 + UInt64(inner[3 + extLen + i]) }
            if ts == 0 || (ts >= 1_577_836_800 && ts <= 4_102_444_800) {
                dataLenOffset = 3 + extLen + 8
                if ts > 0 {
                    let now = UInt64(Date().timeIntervalSince1970)
                    if now > ts {
                        let d = Date(timeIntervalSince1970: TimeInterval(ts))
                        let fmt = DateFormatter(); fmt.dateStyle = .medium; fmt.timeStyle = .short
                        return V2ParseResult(file: nil, encryptedData: nil, ext: ext, format: format,
                                             needsDecrypt: false, isExpired: true, expiryStr: fmt.string(from: d))
                    }
                }
            }
        }

        guard dataLenOffset + 4 <= inner.count else { return nil }
        let dataLen = Int(UInt32(inner[dataLenOffset]) << 24 | UInt32(inner[dataLenOffset+1]) << 16
                       | UInt32(inner[dataLenOffset+2]) << 8  | UInt32(inner[dataLenOffset+3]))
        let dataBytes = Array(inner[(dataLenOffset + 4)...])
        guard dataLen > 0, dataBytes.count >= dataLen else { return nil }
        let payload = Array(dataBytes[0..<dataLen])

        return V2ParseResult(file: nil, encryptedData: payload, ext: ext, format: format,
                             needsDecrypt: true, isExpired: false, expiryStr: "")
    }

    private func scanV2Row(_ rgb: [UInt8], rowOffset: Int, password: String) -> TTFile? {
        // TTv2 (no encryption)
        if matchMagic(rgb, at: rowOffset, magic: Self.MAGIC_TTV2) {
            let hdrLen = 10
            let hdrLenData = Int(UInt32(rgb[rowOffset+4]) << 24 | UInt32(rgb[rowOffset+5]) << 16
                               | UInt32(rgb[rowOffset+6]) << 8  | UInt32(rgb[rowOffset+7]))
            let crc = UInt16(rgb[rowOffset+8]) << 8 | UInt16(rgb[rowOffset+9])
            if let r = parseV2Inner(rgb, offset: rowOffset, headerLen: hdrLen, crc: crc,
                                    totalNeeded: hdrLen + hdrLenData, format: "V2-TTv2") {
                if r.isExpired { return nil }
                if let enc = r.encryptedData {
                    return TTFile(data: Data(enc), ext: r.ext, format: r.format)
                }
            }
        }

        // TTNETv3: cloud RSA, not supported
        if matchMagic(rgb, at: rowOffset, magic: Self.MAGIC_TTNETV3) {
            return nil  // TTNETv3 requires cloud RSA key — unsupported
        }

        // Encrypted variants: each routed to correct key + suffix
        struct EncVariant {
            let magic: [UInt8]; let fmt: String; let hdrLen: Int; let lenOff: Int; let crcOff: Int
            let nHex: String; let dHex: String; let pwSuffix: String; let keySuffix: String
            let sm2: Bool
        }
        let pw = password.isEmpty ? defaultPassword : password
        let variants: [EncVariant] = [
            // TTRSAv2: local RSA key, RSA suffixes
            EncVariant(magic: Self.MAGIC_TTRSAV2, fmt: "V2-TTRSAv2", hdrLen: 13, lenOff: 7, crcOff: 11,
                       nHex: rsaLocalN, dHex: rsaLocalD,
                       pwSuffix: "_rsa_password_check_2025", keySuffix: "_rsa_chacha20_key_2025", sm2: false),
            // TTNETv2: RSA Net key, RSA suffixes
            EncVariant(magic: Self.MAGIC_TTNETV2, fmt: "V2-TTNETv2", hdrLen: 13, lenOff: 7, crcOff: 11,
                       nHex: rsaNetN, dHex: rsaNetD,
                       pwSuffix: "_rsa_password_check_2025", keySuffix: "_rsa_chacha20_key_2025", sm2: false),
            // TTSM2v2: SM2 — not supported in Swift (no gmssl equivalent)
            EncVariant(magic: Self.MAGIC_TTSM2V2, fmt: "V2-TTSM2v2", hdrLen: 13, lenOff: 7, crcOff: 11,
                       nHex: "", dHex: "",
                       pwSuffix: "_sm2_password_check_2025", keySuffix: "_sm2_chacha20_key_2025", sm2: true),
            // TTPWv2: SM2 — not supported in Swift
            EncVariant(magic: Self.MAGIC_TTPWV2, fmt: "V2-TTPWv2", hdrLen: 12, lenOff: 6, crcOff: 10,
                       nHex: "", dHex: "",
                       pwSuffix: "_sm2_password_check_2025", keySuffix: "_sm2_chacha20_key_2025", sm2: true),
        ]
        for v in variants {
            guard matchMagic(rgb, at: rowOffset, magic: v.magic) else { continue }
            guard rowOffset + v.crcOff + 2 <= rgb.count else { continue }
            let hdrLenData = Int(UInt32(rgb[rowOffset+v.lenOff]) << 24 | UInt32(rgb[rowOffset+v.lenOff+1]) << 16
                               | UInt32(rgb[rowOffset+v.lenOff+2]) << 8  | UInt32(rgb[rowOffset+v.lenOff+3]))
            let crc = UInt16(rgb[rowOffset+v.crcOff]) << 8 | UInt16(rgb[rowOffset+v.crcOff+1])
            guard let r = parseV2Inner(rgb, offset: rowOffset, headerLen: v.hdrLen, crc: crc,
                                       totalNeeded: v.hdrLen + hdrLenData, format: v.fmt) else { continue }
            if r.isExpired { return nil }
            guard let enc = r.encryptedData else { continue }
            if v.sm2 { return nil }  // SM2 not supported
            if let d = decryptRSAHybrid(enc, password: pw, nHex: v.nHex, dHex: v.dHex,
                                        pwSuffix: v.pwSuffix, keySuffix: v.keySuffix) {
                return TTFile(data: Data(d), ext: r.ext, format: v.fmt + "-Decrypted")
            }
        }
        return nil
    }

    func tryV2(pixels: [UInt8], width: Int, height: Int, password: String) -> TTFile? {
        let rgb = rgbaToRgb(pixels, width: width, height: height)
        // Row-by-row scan
        for row in 0..<height {
            let off = row * width * 3
            if off + 10 > rgb.count { break }
            if let f = scanV2Row(rgb, rowOffset: off, password: password) { return f }
        }
        // Fallback: scan top 15% byte-by-byte for TTv2
        let limit = min(rgb.count - 4, rgb.count * 15 / 100)
        for off in 0..<limit {
            guard matchMagic(rgb, at: off, magic: Self.MAGIC_TTV2) else { continue }
            let hdrLen = 10
            guard off + hdrLen <= rgb.count else { continue }
            let hdrLenData = Int(UInt32(rgb[off+4]) << 24 | UInt32(rgb[off+5]) << 16
                               | UInt32(rgb[off+6]) << 8  | UInt32(rgb[off+7]))
            let crc = UInt16(rgb[off+8]) << 8 | UInt16(rgb[off+9])
            if let r = parseV2Inner(rgb, offset: off, headerLen: hdrLen, crc: crc,
                                    totalNeeded: hdrLen + hdrLenData, format: "V2-TTv2-Scan"),
               !r.isExpired, let enc = r.encryptedData {
                return TTFile(data: Data(enc), ext: r.ext, format: r.format)
            }
        }
        return nil
    }
}
