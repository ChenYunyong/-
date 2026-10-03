# -*- coding: utf-8 -*-
"""Render each reference image as a coarse ASCII composition map (pure stdlib).
Legend: '#'=dark navy  '~'=sky/energy blue  'o'=bright/white  'w'=warm(brown/gold/skin)  '.'=other"""
import zlib, struct, pathlib, sys

def read_png(path):
    data = pathlib.Path(path).read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    pos, idat, plte = 8, bytearray(), None
    w = h = bd = ct = interlace = None
    while pos < len(data):
        (ln,) = struct.unpack(">I", data[pos:pos+4])
        typ = data[pos+4:pos+8]; body = data[pos+8:pos+8+ln]; pos += 12 + ln
        if typ == b"IHDR":
            w, h, bd, ct, comp, filt, interlace = struct.unpack(">IIBBBBB", body)
        elif typ == b"PLTE": plte = body
        elif typ == b"IDAT": idat += body
        elif typ == b"IEND": break
    raw = zlib.decompress(bytes(idat))
    ch = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ct]
    bpp = max(1, (ch * bd) // 8); stride = (w * ch * bd + 7) // 8
    out = bytearray(); prev = bytearray(stride); p = 0
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
        out += line; prev = line
    return w, h, ct, ch, bytes(out)

def classify(r, g, b):
    lum = 0.299*r + 0.587*g + 0.114*b
    if lum > 200: return "o"
    if b >= r and b >= g and lum < 115: return "#"
    if b > r + 8 and b > 140: return "~"
    if r > b + 10: return "w"
    if lum < 90: return "#"
    return "."

COLS, ROWS = 78, 40
for f in sys.argv[1:]:
    label = pathlib.Path(f).name.encode("ascii", "replace").decode()
    w, h, ct, ch, buf = read_png(f)
    stride = w * ch
    print("=" * COLS)
    print(f"{label}   {w}x{h}")
    print("    " + "".join(str((c // 10) % 10) if c % 10 == 0 else " " for c in range(COLS)))
    for ry in range(ROWS):
        y0, y1 = ry*h//ROWS, (ry+1)*h//ROWS
        row = []
        for rx in range(COLS):
            x0, x1 = rx*w//COLS, (rx+1)*w//COLS
            counts = {}
            n = 0
            for y in range(y0, max(y0+1, y1), max(1, (y1-y0)//6 or 1)):
                base = y*stride
                for x in range(x0, max(x0+1, x1), max(1, (x1-x0)//6 or 1)):
                    o = base + x*ch
                    if ct == 2: r, g, b = buf[o], buf[o+1], buf[o+2]
                    elif ct == 6: r, g, b = buf[o], buf[o+1], buf[o+2]
                    else: r = g = b = buf[o]
                    k = classify(r, g, b)
                    counts[k] = counts.get(k, 0) + 1
                    n += 1
            best = max(counts.items(), key=lambda kv: kv[1])[0] if counts else " "
            row.append(best)
        print(f"{ry:3d} " + "".join(row))
print("=" * COLS)
