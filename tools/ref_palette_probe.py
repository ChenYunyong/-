# -*- coding: utf-8 -*-
"""Pure-stdlib PNG decoder + palette extraction for PixelFusion reference images."""
import zlib, struct, sys, pathlib
from collections import Counter

def read_png(path):
    data = pathlib.Path(path).read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", "not a png"
    pos = 8
    idat = bytearray()
    plte = None
    w = h = bd = ct = interlace = None
    while pos < len(data):
        (ln,) = struct.unpack(">I", data[pos:pos+4])
        typ = data[pos+4:pos+8]
        body = data[pos+8:pos+8+ln]
        pos += 12 + ln
        if typ == b"IHDR":
            w, h, bd, ct, comp, filt, interlace = struct.unpack(">IIBBBBB", body)
        elif typ == b"PLTE":
            plte = body
        elif typ == b"IDAT":
            idat += body
        elif typ == b"IEND":
            break
    raw = zlib.decompress(bytes(idat))
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ct]
    if interlace != 0:
        raise SystemExit("interlaced PNG unsupported")
    bits_pp = channels * bd
    bpp = max(1, bits_pp // 8)
    stride = (w * bits_pp + 7) // 8
    out = bytearray()
    prev = bytearray(stride)
    p = 0
    for _ in range(h):
        f = raw[p]; p += 1
        line = bytearray(raw[p:p+stride]); p += stride
        if f == 1:
            for i in range(bpp, stride):
                line[i] = (line[i] + line[i-bpp]) & 0xFF
        elif f == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif f == 3:
            for i in range(stride):
                a = line[i-bpp] if i >= bpp else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 0xFF
        elif f == 4:
            for i in range(stride):
                a = line[i-bpp] if i >= bpp else 0
                b = prev[i]
                c = prev[i-bpp] if i >= bpp else 0
                pa = abs(b - c); pb = abs(a - c); pc = abs(a + b - 2*c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 0xFF
        out += line
        prev = line
    return w, h, bd, ct, channels, bytes(out), plte

def pixels(w, h, bd, ct, channels, buf, plte, step_max=6):
    """Yield (r,g,b) with alpha>=128, subsampled."""
    if bd != 8:
        raise SystemExit("only 8-bit supported")
    stride = w * channels
    step = 1
    while (w // step) * (h // step) > 400000:
        step += 1
    for y in range(0, h, step):
        base = y * stride
        for x in range(0, w, step):
            o = base + x * channels
            if ct == 2:
                yield buf[o], buf[o+1], buf[o+2]
            elif ct == 6:
                if buf[o+3] >= 128:
                    yield buf[o], buf[o+1], buf[o+2]
            elif ct == 0:
                v = buf[o]; yield v, v, v
            elif ct == 4:
                if buf[o+1] >= 128:
                    v = buf[o]; yield v, v, v
            elif ct == 3:
                i = buf[o] * 3
                yield plte[i], plte[i+1], plte[i+2]

def hx(c):
    return "#%02X%02X%02X" % c

files = sys.argv[1:]
for f in files:
    w, h, bd, ct, ch, buf, plte = read_png(f)
    exact = Counter()
    q = Counter()
    region = {}
    for y in range(0, h, 3):
        for x in range(0, w, 3):
            o = y * w * ch + x * ch
            if ct == 2: px = (buf[o], buf[o+1], buf[o+2])
            elif ct == 6:
                if buf[o+3] < 128: continue
                px = (buf[o], buf[o+1], buf[o+2])
            elif ct == 0:
                v = buf[o]; px = (v, v, v)
            elif ct == 4:
                if buf[o+1] < 128: continue
                v = buf[o]; px = (v, v, v)
            elif ct == 3:
                i = buf[o]*3; px = (plte[i], plte[i+1], plte[i+2])
            else:
                continue
            exact[px] += 1
            q[(px[0] & 0xF0, px[1] & 0xF0, px[2] & 0xF0)] += 1
            gx = min(3, x * 4 // w); gy = min(2, y * 3 // h)
            region.setdefault((gx, gy), Counter())[(px[0] & 0xF0, px[1] & 0xF0, px[2] & 0xF0)] += 1
    print("=" * 62)
    print(f"FILE  {pathlib.Path(f).name}")
    print(f"SIZE  {w}x{h}  bitdepth={bd} colortype={ct}  unique_exact_colors={len(exact)}")
    tot = sum(q.values())
    print("-- top 22 quantized (16-level buckets), share of sampled pixels --")
    for c, n in q.most_common(22):
        print(f"   {hx(c)}  {100.0*n/tot:5.2f}%")
    print("-- dominant per 4x3 region --")
    for gy in range(3):
        row = []
        for gx in range(4):
            r = region.get((gx, gy))
            row.append(hx(r.most_common(1)[0][0]) if r else "  --  ")
        print("   " + "  ".join(row))
print("=" * 62)
