# -*- coding: utf-8 -*-
"""Structural analysis of the reference images: panel boundaries, region extents.
Pure stdlib. Emits ASCII only (no console encoding issues)."""
import zlib, struct, pathlib, sys

def read_png(path):
    data = pathlib.Path(path).read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    pos, idat, plte = 8, bytearray(), None
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
    ch = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ct]
    bpp = max(1, (ch * bd) // 8)
    stride = (w * ch * bd + 7) // 8
    out = bytearray()
    prev = bytearray(stride)
    p = 0
    for _ in range(h):
        f = raw[p]; p += 1
        line = bytearray(raw[p:p+stride]); p += stride
        if f == 1:
            for i in range(bpp, stride): line[i] = (line[i] + line[i-bpp]) & 0xFF
        elif f == 2:
            for i in range(stride): line[i] = (line[i] + prev[i]) & 0xFF
        elif f == 3:
            for i in range(stride):
                a = line[i-bpp] if i >= bpp else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 0xFF
        elif f == 4:
            for i in range(stride):
                a = line[i-bpp] if i >= bpp else 0
                b = prev[i]; c = prev[i-bpp] if i >= bpp else 0
                pa, pb, pc = abs(b-c), abs(a-c), abs(a+b-2*c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 0xFF
        out += line
        prev = line
    return w, h, ct, ch, bytes(out)

def peaks(prof, min_gap, top=10):
    n = len(prof)
    sm = []
    for i in range(n):
        lo, hi = max(0, i-3), min(n, i+4)
        seg = prof[lo:hi]
        sm.append(sum(seg)/len(seg))
    cand = sorted(((sm[i], i) for i in range(3, n-3)), reverse=True)
    picked = []
    for v, i in cand:
        if all(abs(i - j) >= min_gap for _, j in picked):
            picked.append((v, i))
        if len(picked) >= top:
            break
    return sorted(picked, key=lambda t: t[1]), (max(sm) if sm else 0)

for f in sys.argv[1:]:
    name = pathlib.Path(f).name.encode("ascii", "replace").decode()
    w, h, ct, ch, buf = read_png(f)
    stride = w * ch
    print("=" * 70)
    print(f"FILE {name}  {w}x{h} colortype={ct}")

    # vertical edges (panel borders) -- sample every 4th row
    vprof = [0.0] * w
    ys = list(range(0, h, 4))
    for y in ys:
        base = y * stride
        prev = 0.299*buf[base] + 0.587*buf[base+1] + 0.114*buf[base+2]
        for x in range(1, w):
            o = base + x*ch
            L = 0.299*buf[o] + 0.587*buf[o+1] + 0.114*buf[o+2]
            vprof[x] += abs(L - prev)
            prev = L
    vprof = [v / len(ys) for v in vprof]
    vp, vmax = peaks(vprof, min_gap=40, top=10)
    print("VERTICAL borders (x% of width):")
    for v, x in vp:
        print(f"   x={x:5d}  {100.0*x/w:6.2f}%  strength={v:7.2f}  ({100.0*v/vmax:5.1f}% of max)")

    # horizontal edges -- sample every 4th column
    hprof = [0.0] * h
    xs = list(range(0, w, 4))
    for y in range(1, h):
        b1, b0 = y * stride, (y-1) * stride
        s = 0.0
        for x in xs:
            o1, o0 = b1 + x*ch, b0 + x*ch
            L1 = 0.299*buf[o1] + 0.587*buf[o1+1] + 0.114*buf[o1+2]
            L0 = 0.299*buf[o0] + 0.587*buf[o0+1] + 0.114*buf[o0+2]
            s += abs(L1 - L0)
        hprof[y] = s / len(xs)
    hp, hmax = peaks(hprof, min_gap=30, top=10)
    print("HORIZONTAL borders (y% of height):")
    for v, y in hp:
        print(f"   y={y:5d}  {100.0*y/h:6.2f}%  strength={v:7.2f}  ({100.0*v/hmax:5.1f}% of max)")

    # gold CTA-ish region bbox  (warm amber: high R, mid G, low-mid B)
    gx0 = gy0 = 10**9; gx1 = gy1 = -1; gcount = 0
    for y in range(0, h, 2):
        base = y * stride
        for x in range(0, w, 2):
            o = base + x*ch
            r, g, b = buf[o], buf[o+1], buf[o+2]
            if r >= 0xE0 and 0xA0 <= g <= 0xDF and 0x30 <= b <= 0x9F:
                gcount += 1
                if x < gx0: gx0 = x
                if x > gx1: gx1 = x
                if y < gy0: gy0 = y
                if y > gy1: gy1 = y
    tot = (w//2) * (h//2)
    if gcount:
        print("GOLD/AMBER region bbox: "
              f"x {100.0*gx0/w:.1f}%..{100.0*gx1/w:.1f}%  "
              f"y {100.0*gy0/h:.1f}%..{100.0*gy1/h:.1f}%  "
              f"coverage={100.0*gcount/tot:.2f}%")

    # bright (near-white / very light blue) row bands -> text & HUD density
    bands = []
    cur = None
    for y in range(0, h, 2):
        base = y * stride
        c = 0
        for x in range(0, w, 4):
            o = base + x*ch
            if 0.299*buf[o] + 0.587*buf[o+1] + 0.114*buf[o+2] > 205:
                c += 1
        dens = c / (w // 4)
        if dens > 0.05:
            if cur is None:
                cur = [y, y]
            else:
                cur[1] = y
        else:
            if cur is not None and cur[1] - cur[0] > 6:
                bands.append(tuple(cur))
            cur = None
    if cur is not None and cur[1] - cur[0] > 6:
        bands.append(tuple(cur))
    print("BRIGHT bands (y% of height, text/HUD density > 5%):")
    for a, b in bands[:12]:
        print(f"   y {100.0*a/h:6.2f}% .. {100.0*b/h:6.2f}%   (h={100.0*(b-a)/h:.2f}%)")
print("=" * 70)
