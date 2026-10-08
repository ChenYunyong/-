"""pngstat.py -- stdlib-only PNG inspector, for checking a screenshot without eyes on it.

Prints size, distinct sampled colour count, mean colour, and a coarse BLOCK MAP: the image
cut into ROWS x COLS cells, each shown as its mean colour in hex. The map is what makes a
layout readable as text -- a Godot loading screen and a main menu look completely different
in it.

Usage: python pngstat.py <file.png> [rows] [cols]
"""
import sys
import zlib
import struct


def load_png(path):
    data = open(path, "rb").read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", "not a png"
    pos = 8
    idat = bytearray()
    width = height = depth = ctype = interlace = None
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos:pos + 4])
        ctag = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if ctag == b"IHDR":
            width, height, depth, ctype, _, _, interlace = struct.unpack(">IIBBBBB", body)
        elif ctag == b"IDAT":
            idat += body
        elif ctag == b"IEND":
            break
    assert interlace == 0, "interlaced png unsupported"
    assert depth == 8, "only 8-bit png supported"
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ctype]
    raw = zlib.decompress(bytes(idat))
    stride = width * channels
    out = bytearray(width * height * channels)
    prev = bytearray(stride)
    p = 0
    for y in range(height):
        ft = raw[p]
        p += 1
        line = bytearray(raw[p:p + stride])
        p += stride
        if ft == 1:
            for i in range(channels, stride):
                line[i] = (line[i] + line[i - channels]) & 0xFF
        elif ft == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif ft == 3:
            for i in range(stride):
                a = line[i - channels] if i >= channels else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 0xFF
        elif ft == 4:
            for i in range(stride):
                a = line[i - channels] if i >= channels else 0
                b = prev[i]
                c = prev[i - channels] if i >= channels else 0
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 0xFF
        out[y * stride:(y + 1) * stride] = line
        prev = line
    return width, height, channels, out


def main():
    path = sys.argv[1]
    rows = int(sys.argv[2]) if len(sys.argv) > 2 else 12
    cols = int(sys.argv[3]) if len(sys.argv) > 3 else 16
    w, h, ch, px = load_png(path)
    stride = w * ch

    def rgb(x, y):
        i = y * stride + x * ch
        return px[i], px[i + 1], px[i + 2]

    colors = {}
    step = max(1, min(w, h) // 120)
    for y in range(0, h, step):
        for x in range(0, w, step):
            colors[rgb(x, y)] = colors.get(rgb(x, y), 0) + 1
    total = sum(colors.values())
    mr = sum(c[0] * n for c, n in colors.items()) // total
    mg = sum(c[1] * n for c, n in colors.items()) // total
    mb = sum(c[2] * n for c, n in colors.items()) // total
    top = sorted(colors.items(), key=lambda kv: -kv[1])[:4]

    print("file  : %s" % path)
    print("size  : %dx%d  channels=%d" % (w, h, ch))
    print("sample: %d px, %d distinct colours" % (total, len(colors)))
    print("mean  : #%02x%02x%02x" % (mr, mg, mb))
    print("top   : " + ", ".join("#%02x%02x%02x x%d" % (c[0], c[1], c[2], n) for c, n in top))
    print("map   : %d rows x %d cols, each cell = mean colour of that block" % (rows, cols))
    for ry in range(rows):
        cells = []
        for rx in range(cols):
            x0, x1 = rx * w // cols, (rx + 1) * w // cols
            y0, y1 = ry * h // rows, (ry + 1) * h // rows
            sr = sg = sb = n = 0
            for y in range(y0, y1, max(1, (y1 - y0) // 8)):
                for x in range(x0, x1, max(1, (x1 - x0) // 8)):
                    r, g, b = rgb(x, y)
                    sr += r
                    sg += g
                    sb += b
                    n += 1
            cells.append("%02x%02x%02x" % (sr // n, sg // n, sb // n))
        print("  %2d | %s" % (ry, " ".join(cells)))


main()
