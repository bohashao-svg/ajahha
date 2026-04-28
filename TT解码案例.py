"""
TTNet/TTv2 全格式解码脚本
支持格式：
  TTv2      - 灰色图，无加密
  TTPWv2    - 灰色图，SM2混合加密（密码保护）
  TTSM2v2   - 灰色图，SM2混合加密
  TTRSAv2   - 灰色图，RSA混合加密（本地密钥）
  TTNETv2   - 彩色图，RSA Net混合加密（服务器密钥）
  TTNETv3   - 彩色图，云端RSA（暂不支持）
"""

import hashlib
import struct
import sys
from pathlib import Path
from PIL import Image
from Crypto.Cipher import ChaCha20

# ── RSANet 私钥（服务器密钥，用于 TTNETv2）────────────────────────────────────
RSANET_PRIVATE_KEY = {
    "n": "B691A71AD927A3B0108F2C9456A7F27216D892D34E787BA2E3EFD51CCAFED38151693043EB23C40472BCF8897330CF0EC739DCC301201255C5E4C7AC48DEE08EEE459FFC08655374FB2E37358892120F513582B47CCF259CD960220C215BA6857AC03982CFCEA13863EA60F163B1FAAC87E8FD33D279D5B779D0B9A1F3FEFA6F",
    "d": "8500973C77F6E8C8DB4772B29E6EBBB161F365038BA73A6AF0A3481E31C47351427DDF2B9BA1F2AB4AEB6024C2464C91F791AFC2608F7CCBFFDF2B97D77E87185E756FB411B17AA2F87A88D89C58FDBF26501262162A9A3E83199701349CE17095208B0BFB29C44EA919709F7670DAAC85F316431AA366C0EE20CB2A516F6801",
    "e": 65537,
}

# ── TTRSAv2 本地 RSA 私钥────────────────────────────────────────────────────
RSA_LOCAL_PRIVATE_KEY = {
    "n": "8780D06EF9DA6B96CD69A842B62C2DA8EFF89B9BC33F6A7935C7839DCE1A0C722BB1300397805EC1F5143A3AF2F9201AE567219C70A3F749BDD0625D466BC777F5558C9777C65D26A8B202371C1BBB9E630B2D79629DC66863161E769B3D46E7428A92EE518D0DFBDB9BBCF8ABFE6D5CD296363C964E9C775B200B720DFE31B1",
    "d": "5FD5A415091308CAE446D8E12DD4BB0A6386720FCD1C79E2763DC0818875F5DD7DB7589D01B6A1CE0DD69B847BB9E49201335A9B39334E3F5247227A93C6C090B007ADB7A1BD1B3A97C59943A738A041133B97F81DEDEF883E8D19C44B0158DFEAF5F0C3CEEA906CDC0D68D180196EB92153507D9E7AFCF310D59BA907AAC34D",
    "e": 65537,
}

# ── SM2 私钥（用于 TTSM2v2 / TTPWv2）────────────────────────────────────────
SM2_PRIVATE_KEY = "2ac8c94da87bbe6d1d396e73341eca778b63dd8c1043f6fb0112ef0fa35433b3"
SM2_PUBLIC_KEY  = "04ffcb1976578a81feed18f04c35d30564759077b1494f594ba95488cbc152b554c8a60fc5a437ced2b9b44c40318c15576403729e1dd344bad0f742aebf00ed66"

PASSWORD = "xiaosi666"

# ── Magic bytes ───────────────────────────────────────────────────────────────
MAGIC_TTv2    = bytes([84, 84, 118, 50])                    # TTv2    (4字节)
MAGIC_TTPWv2  = bytes([84, 84, 80, 87, 118, 50])            # TTPWv2  (6字节)
MAGIC_TTSM2v2 = bytes([84, 84, 83, 77, 50, 118, 50])        # TTSM2v2 (7字节)
MAGIC_TTRSAv2 = bytes([84, 84, 82, 83, 65, 118, 50])        # TTRSAv2 (7字节)
MAGIC_TTNETv2 = bytes([84, 84, 78, 69, 84, 118, 50])        # TTNETv2 (7字节)
MAGIC_TTNETv3 = bytes([84, 84, 78, 69, 84, 118, 51])        # TTNETv3 (7字节)

# header_offset = magic_len + 4(hdrLen) + 2(crc)
MAGIC_INFO = {
    MAGIC_TTv2:    {"name": "TTv2",    "hdr_off": 10, "encrypted": False},
    MAGIC_TTPWv2:  {"name": "TTPWv2",  "hdr_off": 12, "encrypted": True,  "algo": "SM2",  "pw_suffix": "_sm2_password_check_2025",  "key_suffix": "_sm2_chacha20_key_2025"},
    MAGIC_TTSM2v2: {"name": "TTSM2v2", "hdr_off": 13, "encrypted": True,  "algo": "SM2",  "pw_suffix": "_sm2_password_check_2025",  "key_suffix": "_sm2_chacha20_key_2025"},
    MAGIC_TTRSAv2: {"name": "TTRSAv2", "hdr_off": 13, "encrypted": True,  "algo": "RSA",  "pw_suffix": "_rsa_password_check_2025",  "key_suffix": "_rsa_chacha20_key_2025"},
    MAGIC_TTNETv2: {"name": "TTNETv2", "hdr_off": 13, "encrypted": True,  "algo": "RSANET", "pw_suffix": "_rsa_password_check_2025", "key_suffix": "_rsa_chacha20_key_2025"},
}


# ── SHA256 工具 ───────────────────────────────────────────────────────────────
def sha256_hex(s: str) -> str:
    return hashlib.sha256(s.encode()).hexdigest()


def hex_to_bytes(h: str) -> bytes:
    return bytes.fromhex(h)


# ── ChaCha20 密钥派生 ─────────────────────────────────────────────────────────
def generate_chacha20_key(password: str, suffix: str) -> bytes:
    n = password + suffix
    for t in range(1000):
        n = sha256_hex(n + str(t))
    r = hex_to_bytes(n)
    key = bytearray(32)
    for s in range(32):
        a = s % len(r)
        c = s // len(r)
        key[s] = r[a] ^ (13 * s & 0xFF) ^ (7 * c & 0xFF) ^ 170
    return bytes(key)


# ── TinyRSA 解密 ──────────────────────────────────────────────────────────────
def tiny_rsa_decrypt(ciphertext_hex: str, d_hex: str, n_hex: str) -> bytes:
    c = int(ciphertext_hex, 16)
    d = int(d_hex, 16)
    n = int(n_hex, 16)
    m = pow(c, d, n)
    key_len = (n.bit_length() + 7) // 8

    raw = []
    tmp = m
    while tmp > 0:
        raw.insert(0, tmp & 0xFF)
        tmp >>= 8

    if len(raw) < key_len and (len(raw) == 0 or raw[0] != 0):
        raw.insert(0, 0)

    # simpleUnpad: [0x00, 0x02, 0xFF..., 0x00, data]
    if len(raw) >= 4 and raw[0] == 0x00 and raw[1] == 0x02:
        t = 2
        while t < len(raw) and raw[t] != 0x00:
            t += 1
        if t < len(raw):
            return bytes(raw[t + 1:])
    return bytes(raw)


# ── SM2 解密 ──────────────────────────────────────────────────────────────────
def sm2_decrypt(ciphertext: bytes, private_key_hex: str) -> bytes:
    """SM2解密，C1C3C2格式（mode=1）。返回明文bytes。"""
    from gmssl import sm2 as gm_sm2
    # gmssl CryptSM2: mode=1 → C1C3C2（与JS doDecrypt mode=1一致）
    sm2_crypt = gm_sm2.CryptSM2(
        private_key=private_key_hex,
        public_key=SM2_PUBLIC_KEY.lstrip("04"),
        mode=1,
    )
    result = sm2_crypt.decrypt(ciphertext)
    if result is None:
        raise ValueError("SM2解密失败，返回None")
    return result


# ── CRC16 校验 ────────────────────────────────────────────────────────────────
def crc16(data: bytes) -> int:
    n = 0xFFFF
    for b in data:
        n ^= (b << 8) & 0xFFFF
        for _ in range(8):
            if n & 0x8000:
                n = (0xFFFF & ((n << 1) ^ 0x1021))
            else:
                n = (n << 1) & 0xFFFF
    return n & 0xFFFF


# ── 通用数据包解析 ────────────────────────────────────────────────────────────
def parse_packet(rgb: bytes, offset: int, magic: bytes):
    """
    解析任意格式数据包，返回 (payload, extension, next_offset) 或 None
    header_offset = len(magic) + 4(hdrLen) + 2(crc)
    """
    info = MAGIC_INFO[magic]
    hdr_off = info["hdr_off"]
    magic_len = len(magic)

    if offset + hdr_off + 1 > len(rgb):
        return None

    # hdrLen 在 magic 之后的4字节
    hdr_len_pos = offset + magic_len
    hdr_len = struct.unpack_from(">I", rgb, hdr_len_pos)[0]
    crc_expected = struct.unpack_from(">H", rgb, hdr_len_pos + 4)[0]

    total_needed = hdr_off + hdr_len
    if offset + total_needed > len(rgb):
        return None

    inner = rgb[offset + hdr_off: offset + hdr_off + hdr_len]

    crc_calc = crc16(inner)
    if crc_calc != crc_expected:
        print(f"  [!] CRC不匹配: 计算={crc_calc:#06x} 期望={crc_expected:#06x}")
        return None

    if len(inner) < 7:
        return None

    version = inner[0]
    ext_len = inner[2]
    extension = inner[3: 3 + ext_len].decode("utf-8", errors="replace")

    # 跳过可选过期时间字段（8字节）
    pos = 3 + ext_len
    if len(inner) >= pos + 8 + 4:
        ts_candidate = int.from_bytes(inner[pos: pos + 8], "big")
        if ts_candidate == 0 or (1577836800 <= ts_candidate <= 4102444800):
            pos += 8

    if len(inner) < pos + 4:
        return None

    data_len = struct.unpack_from(">I", inner, pos)[0]
    payload = inner[pos + 4: pos + 4 + data_len]

    if version != 2 or data_len <= 0 or len(payload) < data_len:
        return None

    return payload, extension, offset + total_needed


# ── RSA 混合解密（TTRSAv2 / TTNETv2）────────────────────────────────────────
def rsa_hybrid_decrypt(encrypted: bytes, password: str, private_key: dict,
                       pw_suffix: str, key_suffix: str) -> bytes:
    chacha20_key = generate_chacha20_key(password, key_suffix)

    pos = 0
    pw_check_stored = encrypted[pos: pos + 16]
    pos += 16
    pw_hash = sha256_hex(password + pw_suffix)
    pw_check_expected = hex_to_bytes(pw_hash)[:16]
    if pw_check_stored != pw_check_expected:
        raise ValueError(f"密码校验失败: {pw_check_stored.hex()} != {pw_check_expected.hex()}")
    print("  [+] 密码校验通过")

    key_block_len = struct.unpack_from(">I", encrypted, pos)[0]
    pos += 4
    key_block_enc = encrypted[pos: pos + key_block_len]
    pos += key_block_len

    nonce = encrypted[pos: pos + 12]
    pos += 12
    ciphertext = encrypted[pos:]

    cipher1 = ChaCha20.new(key=chacha20_key, nonce=nonce)
    key_block = cipher1.decrypt(key_block_enc)

    n_int = int(private_key["n"], 16)
    rsa_block_len = (n_int.bit_length() + 7) // 8
    rsa_enc_part = key_block[:rsa_block_len]

    random_key = tiny_rsa_decrypt(rsa_enc_part.hex(), private_key["d"], private_key["n"])
    if len(random_key) != 32:
        raise ValueError(f"RSA解密结果长度异常: {len(random_key)}，期望32")
    print(f"  [+] RSA解密随机密钥: {random_key.hex()[:16]}...")

    cipher2 = ChaCha20.new(key=bytes(random_key), nonce=nonce)
    return cipher2.decrypt(ciphertext)


# ── SM2 混合解密（TTSM2v2 / TTPWv2）─────────────────────────────────────────
def sm2_hybrid_decrypt(encrypted: bytes, password: str,
                       pw_suffix: str, key_suffix: str) -> bytes:
    chacha20_key = generate_chacha20_key(password, key_suffix)

    pos = 0
    pw_check_stored = encrypted[pos: pos + 16]
    pos += 16
    pw_hash = sha256_hex(password + pw_suffix)
    pw_check_expected = hex_to_bytes(pw_hash)[:16]
    if pw_check_stored != pw_check_expected:
        raise ValueError(f"密码校验失败: {pw_check_stored.hex()} != {pw_check_expected.hex()}")
    print("  [+] 密码校验通过")

    key_block_len = struct.unpack_from(">I", encrypted, pos)[0]
    pos += 4
    key_block_enc = encrypted[pos: pos + key_block_len]
    pos += key_block_len

    nonce = encrypted[pos: pos + 12]
    pos += 12
    ciphertext = encrypted[pos:]

    # ChaCha20解密密钥块（得到SM2加密的随机密钥bytes）
    cipher1 = ChaCha20.new(key=chacha20_key, nonce=nonce)
    key_block = cipher1.decrypt(key_block_enc)
    print(f"  [+] SM2密钥块解密完成，长度: {len(key_block)}")

    # SM2解密：key_block是SM2密文bytes，解密后得到32字节随机密钥的hex字符串（64字节）
    # JS: h(S) → doDecrypt(hexStr, privKey, 1, {output:'hex'}) → c(result) = 32 bytes
    decrypted_hex_str = sm2_decrypt(key_block, SM2_PRIVATE_KEY)
    # decrypted_hex_str 是 bytes，内容是64个hex字符（32字节随机密钥的hex表示）
    if isinstance(decrypted_hex_str, bytes):
        try:
            random_key = bytes.fromhex(decrypted_hex_str.decode("ascii"))
        except Exception:
            random_key = decrypted_hex_str
    else:
        random_key = bytes.fromhex(decrypted_hex_str)

    if len(random_key) != 32:
        raise ValueError(f"SM2解密结果长度异常: {len(random_key)}，期望32")
    print(f"  [+] SM2解密随机密钥: {random_key.hex()[:16]}...")

    cipher2 = ChaCha20.new(key=bytes(random_key), nonce=nonce)
    return cipher2.decrypt(ciphertext)


# ── 主流程 ────────────────────────────────────────────────────────────────────
def decode_image(image_path: str, output_dir: str = None, password: str = PASSWORD):
    img = Image.open(image_path).convert("RGBA")
    w, h = img.size
    data = img.tobytes()
    print(f"[*] 图片尺寸: {w}x{h}，数据长度: {len(data)}")

    # 提取 RGB（去掉 Alpha）
    rgb = bytearray()
    for i in range(w * h):
        base = i * 4
        rgb.extend(data[base:base + 3])
    rgb = bytes(rgb)
    print(f"[*] RGB数据长度: {len(rgb)}")

    out_dir = Path(output_dir) if output_dir else Path(image_path).parent
    found = 0

    # 所有要扫描的 magic（按长度从长到短，避免短magic误匹配）
    all_magics = [
        MAGIC_TTNETv3, MAGIC_TTNETv2, MAGIC_TTSM2v2, MAGIC_TTRSAv2,
        MAGIC_TTPWv2, MAGIC_TTv2,
    ]

    def try_decode(magic, offset):
        nonlocal found
        info = MAGIC_INFO.get(magic)
        if info is None:
            print(f"  [!] TTNETv3暂不支持（需要云端RSA）")
            return

        name = info["name"]
        result = parse_packet(rgb, offset, magic)
        if result is None:
            print(f"  [!] {name}数据包解析失败")
            return

        payload, ext, _ = result
        print(f"  [+] 扩展名: {ext}，payload长度: {len(payload)}")

        try:
            if not info["encrypted"]:
                # TTv2：无加密，直接保存
                plaintext = bytes(payload)
                print(f"  [+] TTv2无加密，直接提取")
            elif info["algo"] in ("RSA", "RSANET"):
                pk = RSANET_PRIVATE_KEY if info["algo"] == "RSANET" else RSA_LOCAL_PRIVATE_KEY
                plaintext = rsa_hybrid_decrypt(
                    payload, password, pk,
                    info["pw_suffix"], info["key_suffix"]
                )
            elif info["algo"] == "SM2":
                plaintext = sm2_hybrid_decrypt(
                    payload, password,
                    info["pw_suffix"], info["key_suffix"]
                )
            else:
                print(f"  [!] 未知算法: {info['algo']}")
                return

            out_path = out_dir / f"decoded_{found}.{ext or 'bin'}"
            out_path.write_bytes(plaintext)
            print(f"  [+] 已保存: {out_path}")
            found += 1
        except Exception as e:
            print(f"  [!] 解密失败: {e}")

    # 行首扫描
    for row in range(h):
        offset = row * w * 3
        if offset + 14 > len(rgb):
            break

        for magic in all_magics:
            ml = len(magic)
            if rgb[offset: offset + ml] == magic:
                name = MAGIC_INFO[magic]["name"] if magic in MAGIC_INFO else "TTNETv3"
                print(f"\n[*] 行 {row}: 找到 {name} magic，偏移 {offset}")
                if magic == MAGIC_TTNETv3:
                    print("  [!] TTNETv3暂不支持（需要云端RSA）")
                else:
                    try_decode(magic, offset)
                break  # 一行只处理一个magic

    # 全局扫描（未找到时）
    if found == 0:
        print("\n[!] 行首扫描未找到，尝试全局扫描...")
        pos = 0
        while pos < len(rgb) - 14:
            matched = False
            for magic in all_magics:
                ml = len(magic)
                if rgb[pos: pos + ml] == magic:
                    name = MAGIC_INFO[magic]["name"] if magic in MAGIC_INFO else "TTNETv3"
                    print(f"  [*] 全局扫描找到 {name}，偏移 {pos}")
                    if magic == MAGIC_TTNETv3:
                        print("  [!] TTNETv3暂不支持")
                        pos += ml
                    else:
                        result = parse_packet(rgb, pos, magic)
                        if result:
                            payload, ext, next_pos = result
                            try_decode(magic, pos)
                            pos = next_pos
                        else:
                            pos += 1
                    matched = True
                    break
            if not matched:
                pos += 1

    print(f"\n[*] 完成，共解码 {found} 个文件")


if __name__ == "__main__":
    img = sys.argv[1] if len(sys.argv) > 1 else r"C:\Users\Administrator\Desktop\动态调试\待解码.png"
    pw = sys.argv[2] if len(sys.argv) > 2 else PASSWORD
    decode_image(img, password=pw)
