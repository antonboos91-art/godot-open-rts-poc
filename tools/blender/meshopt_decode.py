"""Dekomprimiert glTF/GLB mit EXT_meshopt_compression (nur ATTRIBUTES, wie bei mesh2motion-Animationen).
  python meshopt_decode.py in.glb out.glb"""
import json, struct, sys, math


def decode_vertex(data, count, stride):
    assert data[0] == 0xA0, hex(data[0])
    pos = 1
    tail = data[len(data) - stride:]
    end = len(data) - stride
    last = bytearray(tail)
    block_elems = min((8192 // stride) & ~15, 256)
    out = bytearray(count * stride)
    off = 0
    while off < count:
        bs = min(count - off, block_elems)
        padded = (bs + 15) & ~15
        lanes = []
        for k in range(stride):
            ngroups = padded // 16
            hsize = (ngroups + 3) // 4
            header = data[pos:pos + hsize]
            pos += hsize
            buf = bytearray(padded)
            for g in range(ngroups):
                bl = (header[g // 4] >> ((g % 4) * 2)) & 3
                o = g * 16
                if bl == 0:
                    pass
                elif bl == 1:
                    var = pos + 4
                    for q in range(4):
                        b = data[pos + q]
                        for t in range(4):
                            v = (b >> (6 - 2 * t)) & 3
                            if v == 3:
                                v = data[var]; var += 1
                            buf[o + q * 4 + t] = v
                    pos = var
                elif bl == 2:
                    var = pos + 8
                    for q in range(8):
                        b = data[pos + q]
                        for t in range(2):
                            v = (b >> (4 - 4 * t)) & 15
                            if v == 15:
                                v = data[var]; var += 1
                            buf[o + q * 2 + t] = v
                    pos = var
                else:
                    buf[o:o + 16] = data[pos:pos + 16]
                    pos += 16
            lanes.append(buf)
        for k in range(stride):
            p = last[k]
            buf = lanes[k]
            for i in range(bs):
                b = buf[i]
                d = (~(b >> 1)) & 0xFF if (b & 1) else (b >> 1)
                p = (p + d) & 0xFF
                out[(off + i) * stride + k] = p
            last[k] = p
        off += bs
    return out


def filt_exp(buf, count, stride):
    n = stride // 4
    res = bytearray(len(buf))
    for i in range(count * n):
        v = struct.unpack_from("<I", buf, i * 4)[0]
        e = struct.unpack("<i", struct.pack("<I", v))[0] >> 24
        m = struct.unpack("<i", struct.pack("<I", (v << 8) & 0xFFFFFFFF))[0] >> 8
        struct.pack_into("<f", res, i * 4, math.ldexp(m, e))
    return res


def filt_quat(buf, count):
    res = bytearray(len(buf))
    sc = 1.0 / math.sqrt(2.0)
    for i in range(count):
        d = struct.unpack_from("<4h", buf, i * 8)
        sf = d[3] | 3
        ss = sc / float(sf)
        x, y, z = d[0] * ss, d[1] * ss, d[2] * ss
        w = math.sqrt(max(0.0, 1.0 - x * x - y * y - z * z))
        maxc = d[3] & 3
        o = [0.0] * 4
        o[(maxc + 1) & 3] = x; o[(maxc + 2) & 3] = y; o[(maxc + 3) & 3] = z; o[maxc] = w
        struct.pack_into("<4h", res, i * 8, *[int(round(c * 32767)) for c in o])
    return res


def main(src, dst):
    b = open(src, "rb").read()
    jl = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20:20 + jl])
    off = 20 + jl
    bl = struct.unpack("<I", b[off:off + 4])[0]
    bin0 = b[off + 8:off + 8 + bl]
    newbin = bytearray()
    for bv in j["bufferViews"]:
        ext = bv.get("extensions", {}).get("EXT_meshopt_compression")
        if ext:
            raw = bin0[ext["byteOffset"]:ext["byteOffset"] + ext["byteLength"]]
            data = decode_vertex(raw, ext["count"], ext["byteStride"])
            f = ext.get("filter", "NONE")
            if f == "EXPONENTIAL":
                data = filt_exp(data, ext["count"], ext["byteStride"])
            elif f == "QUATERNION":
                data = filt_quat(data, ext["count"])
            elif f != "NONE":
                raise SystemExit("filter " + f)
            del bv["extensions"]["EXT_meshopt_compression"]
            if not bv["extensions"]:
                del bv["extensions"]
        else:
            data = bin0[bv.get("byteOffset", 0):bv.get("byteOffset", 0) + bv["byteLength"]]
        while len(newbin) % 4:
            newbin.append(0)
        bv["byteOffset"] = len(newbin)
        bv["byteLength"] = len(data)
        bv["buffer"] = 0
        bv.pop("byteStride", None) if False else None
        newbin += data
    j["buffers"] = [{"byteLength": len(newbin)}]
    j["extensionsUsed"] = [e for e in j.get("extensionsUsed", []) if e != "EXT_meshopt_compression"]
    j.pop("extensionsRequired", None)
    js = json.dumps(j).encode()
    js += b" " * ((4 - len(js) % 4) % 4)
    newbin += b"\0" * ((4 - len(newbin) % 4) % 4)
    out = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(newbin))
    out += struct.pack("<II", len(js), 0x4E4F534A) + js + struct.pack("<II", len(newbin), 0x004E4942) + newbin
    open(dst, "wb").write(out)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
