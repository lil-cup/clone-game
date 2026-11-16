# Рисует картинку загрузки: сердце из блоков в стиле игры.
# Запуск: python3 tools/make_splash.py → splash.png в корне проекта.
import struct
import zlib
from pathlib import Path

SIZE = 512
SS = 3  # суперсэмплинг для гладких краёв

HEART = [
    ".RR...RR.",
    "RSSR.RRRR",
    "RSRRRRRRR",
    "RRRRRRRRR",
    ".RRRRRRR.",
    "..RRRRR..",
    "...RRR...",
    "....R....",
]
COLORS = {"R": (0xE8, 0x20, 0x2A), "S": (0xFF, 0x6F, 0xB5)}

CELL = 44
GAP = 6
RADIUS = 9
cols, rows = len(HEART[0]), len(HEART)
ox = (SIZE - cols * CELL) / 2
oy = (SIZE - rows * CELL) / 2


def inside_rounded(px, py, x0, y0, w, h, r):
    cx = min(max(px, x0 + r), x0 + w - r)
    cy = min(max(py, y0 + r), y0 + h - r)
    return (px - cx) ** 2 + (py - cy) ** 2 <= r * r


def sample(px, py):
    col = int((px - ox) // CELL)
    row = int((py - oy) // CELL)
    if not (0 <= col < cols and 0 <= row < rows):
        return None
    key = HEART[row][col]
    if key == ".":
        return None
    x0 = ox + col * CELL + GAP / 2
    y0 = oy + row * CELL + GAP / 2
    w = CELL - GAP
    if not inside_rounded(px, py, x0, y0, w, w, RADIUS):
        return None
    r, g, b = COLORS[key]
    t = (py - y0) / w
    # Блик сверху, тень снизу — как у блоков на поле.
    if t < 0.18:
        k = 0.35 * (1 - t / 0.18)
        r, g, b = (c + (255 - c) * k for c in (r, g, b))
    elif t > 0.8:
        k = 0.25 * (t - 0.8) / 0.2
        r, g, b = (c * (1 - k) for c in (r, g, b))
    return r, g, b


rows_out = []
for y in range(SIZE):
    line = bytearray([0])
    for x in range(SIZE):
        acc = [0.0, 0.0, 0.0, 0.0]
        for sy in range(SS):
            for sx in range(SS):
                c = sample(x + (sx + 0.5) / SS, y + (sy + 0.5) / SS)
                if c:
                    acc[0] += c[0]
                    acc[1] += c[1]
                    acc[2] += c[2]
                    acc[3] += 1
        n = acc[3]
        if n:
            line += bytes([round(acc[0] / n), round(acc[1] / n), round(acc[2] / n), round(255 * n / SS / SS)])
        else:
            line += bytes(4)
    rows_out.append(bytes(line))


def chunk(tag, data):
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data))


png = b"\x89PNG\r\n\x1a\n"
png += chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0))
png += chunk(b"IDAT", zlib.compress(b"".join(rows_out), 9))
png += chunk(b"IEND", b"")
out = Path(__file__).resolve().parent.parent / "splash.png"
out.write_bytes(png)
print("written", out)
