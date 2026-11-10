#!/usr/bin/env python3
"""Генератор картинок для уровней.

Каждая картинка описана фигурами в координатах 0..1 (x вправо, y вниз),
поэтому её можно отрисовать в любом размере сетки.
Запуск:  python3 tools/make_levels.py [папка_для_превью]
Пишет scripts/levels.gd (и превью PNG, если указана папка).
"""
import math
import os
import sys

# Цвета должны совпадать с Level.COLORS в scripts/level.gd
PALETTE = {
    "R": "ff6b6b", "W": "fdfbf5", "Y": "ffd166", "G": "6bcb77", "B": "5ab8f0",
    "P": "9b7ede", "O": "ff9f43", "K": "a47551", "N": "4a4e69", "D": "3a9d6b",
    "S": "ff9ecd", "A": "b8c0d6", "L": "f3c995",
}


# ---------- фигуры ----------

def circle(cx, cy, r):
    return lambda x, y: (x - cx) ** 2 + (y - cy) ** 2 <= r * r

def ellipse(cx, cy, rx, ry):
    return lambda x, y: ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1

def rect(x0, y0, x1, y1):
    return lambda x, y: x0 <= x <= x1 and y0 <= y <= y1

def poly(*pts):
    def inside(x, y):
        res = False
        j = len(pts) - 1
        for i in range(len(pts)):
            xi, yi = pts[i]
            xj, yj = pts[j]
            if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
                res = not res
            j = i
        return res
    return inside

def both(a, b):
    return lambda x, y: a(x, y) and b(x, y)

def minus(a, b):
    return lambda x, y: a(x, y) and not b(x, y)

def anyof(*shapes):
    return lambda x, y: any(s(x, y) for s in shapes)

def stripes(shape, k, offset=0.0):
    """Каждая вторая диагональная полоска внутри фигуры (k — частота полосок)."""
    return lambda x, y: shape(x, y) and int((x + y) * k + offset) % 2 == 0

def everywhere(x, y):
    return True

def line(x0, y0, x1, y1, w):
    def inside(x, y):
        dx, dy = x1 - x0, y1 - y0
        t = max(0, min(1, ((x - x0) * dx + (y - y0) * dy) / (dx * dx + dy * dy)))
        return math.hypot(x - x0 - t * dx, y - y0 - t * dy) <= w / 2
    return inside


# ---------- картинки ----------
# Список слоёв (цвет, фигура): каждый следующий рисуется поверх.

def kolobok():
    return [
        ("B", everywhere),
        ("G", rect(0, 0.8, 1, 1)),
        ("Y", circle(0.5, 0.55, 0.33)),
        ("N", anyof(circle(0.39, 0.47, 0.05), circle(0.61, 0.47, 0.05))),
        ("R", both(ellipse(0.5, 0.62, 0.15, 0.1), rect(0, 0.62, 1, 1))),
    ]

def muhomor():
    return [
        ("G", everywhere),
        ("W", rect(0.4, 0.45, 0.6, 0.9)),
        ("R", both(ellipse(0.5, 0.5, 0.42, 0.36), rect(0, 0, 1, 0.5))),
        ("W", anyof(circle(0.32, 0.36, 0.05), circle(0.55, 0.26, 0.06),
                    circle(0.7, 0.4, 0.05), circle(0.45, 0.43, 0.04), circle(0.2, 0.46, 0.035))),
    ]

def snegovik():
    return [
        ("B", everywhere),
        ("W", rect(0, 0.9, 1, 1)),
        ("K", anyof(line(0.33, 0.5, 0.12, 0.38, 0.04), line(0.67, 0.5, 0.88, 0.38, 0.04))),
        ("W", anyof(circle(0.5, 0.74, 0.25), circle(0.5, 0.45, 0.18), circle(0.5, 0.22, 0.13))),
        ("R", rect(0.34, 0.31, 0.66, 0.36)),
        ("K", rect(0.37, 0.02, 0.63, 0.12)),
        ("N", anyof(circle(0.44, 0.2, 0.03), circle(0.57, 0.2, 0.03),
                    circle(0.5, 0.42, 0.035), circle(0.5, 0.53, 0.035), circle(0.5, 0.7, 0.035))),
        ("O", poly((0.5, 0.24), (0.5, 0.3), (0.72, 0.27))),
    ]

def yolka():
    return [
        ("B", everywhere),
        ("W", rect(0, 0.85, 1, 1)),
        ("K", rect(0.44, 0.75, 0.56, 0.92)),
        ("G", anyof(poly((0.5, 0.1), (0.25, 0.4), (0.75, 0.4)),
                    poly((0.5, 0.25), (0.18, 0.6), (0.82, 0.6)),
                    poly((0.5, 0.42), (0.1, 0.8), (0.9, 0.8)))),
        ("R", anyof(circle(0.42, 0.35, 0.035), circle(0.6, 0.52, 0.035),
                    circle(0.35, 0.68, 0.035), circle(0.66, 0.72, 0.035), circle(0.5, 0.62, 0.035))),
        ("Y", circle(0.5, 0.09, 0.06)),
    ]

def valenok():
    return [
        ("B", everywhere),
        ("W", rect(0, 0.85, 1, 1)),
        ("A", anyof(rect(0.3, 0.1, 0.6, 0.8), ellipse(0.55, 0.78, 0.3, 0.12))),
        ("A", rect(0.3, 0.66, 0.85, 0.85)),
        ("R", rect(0.27, 0.1, 0.63, 0.2)),
        ("N", rect(0.25, 0.85, 0.88, 0.9)),
    ]

def matreshka():
    return [
        ("Y", everywhere),
        ("R", anyof(ellipse(0.5, 0.66, 0.3, 0.3), circle(0.5, 0.3, 0.2))),
        ("W", circle(0.5, 0.31, 0.11)),
        ("N", anyof(circle(0.44, 0.29, 0.035), circle(0.57, 0.29, 0.035))),
        ("S", anyof(circle(0.42, 0.36, 0.03), circle(0.59, 0.36, 0.03))),
        ("W", ellipse(0.5, 0.73, 0.15, 0.16)),
        ("G", anyof(circle(0.5, 0.7, 0.05), rect(0.48, 0.74, 0.53, 0.85))),
    ]

def bereza():
    return [
        ("B", everywhere),
        ("G", rect(0, 0.82, 1, 1)),
        ("W", rect(0.43, 0.3, 0.57, 0.9)),
        ("N", anyof(rect(0.43, 0.42, 0.5, 0.45), rect(0.5, 0.55, 0.57, 0.58),
                    rect(0.43, 0.68, 0.52, 0.71), rect(0.48, 0.8, 0.57, 0.83))),
        ("D", anyof(ellipse(0.5, 0.25, 0.3, 0.2), ellipse(0.32, 0.38, 0.14, 0.1), ellipse(0.68, 0.38, 0.14, 0.1))),
    ]

def izbushka():
    return [
        ("B", everywhere),
        ("G", rect(0, 0.82, 1, 1)),
        ("K", rect(0.18, 0.45, 0.82, 0.85)),
        ("R", poly((0.5, 0.12), (0.08, 0.48), (0.92, 0.48))),
        ("Y", rect(0.38, 0.55, 0.62, 0.72)),
        ("K", anyof(rect(0.48, 0.55, 0.52, 0.72), rect(0.38, 0.62, 0.62, 0.65))),
    ]

def samovar():
    return [
        ("P", everywhere),
        ("N", rect(0.45, 0.06, 0.55, 0.2)),
        ("Y", anyof(ellipse(0.5, 0.48, 0.28, 0.26), rect(0.38, 0.18, 0.62, 0.3))),
        ("O", anyof(ellipse(0.17, 0.42, 0.08, 0.1), ellipse(0.83, 0.42, 0.08, 0.1))),
        ("P", anyof(ellipse(0.17, 0.42, 0.04, 0.05), ellipse(0.83, 0.42, 0.04, 0.05))),
        ("O", rect(0.22, 0.47, 0.78, 0.52)),
        ("Y", poly((0.38, 0.7), (0.62, 0.7), (0.7, 0.85), (0.3, 0.85))),
        ("O", rect(0.25, 0.85, 0.75, 0.92)),
    ]

def balalaika():
    return [
        ("P", everywhere),
        ("K", rect(0.46, 0.04, 0.54, 0.5)),
        ("O", poly((0.5, 0.42), (0.15, 0.92), (0.85, 0.92))),
        ("K", circle(0.5, 0.72, 0.06)),
        ("W", anyof(rect(0.48, 0.06, 0.49, 0.88), rect(0.51, 0.06, 0.52, 0.88))),
    ]

def borovik():
    return [
        ("B", everywhere),
        ("G", rect(0, 0.78, 1, 1)),
        ("D", anyof(poly((0.1, 0.9), (0.15, 0.65), (0.2, 0.9)), poly((0.8, 0.92), (0.86, 0.6), (0.92, 0.92)))),
        ("W", anyof(ellipse(0.5, 0.68, 0.14, 0.22))),
        ("K", both(ellipse(0.5, 0.45, 0.36, 0.3), rect(0, 0, 1, 0.48))),
        ("L", both(ellipse(0.5, 0.45, 0.36, 0.3), rect(0, 0.42, 1, 0.48))),
    ]

def ryabina():
    berries = [(-0.14, 0), (0, 0), (0.14, 0), (-0.21, 0.13), (-0.07, 0.13), (0.07, 0.13), (0.21, 0.13),
               (-0.14, 0.26), (0, 0.26), (0.14, 0.26), (-0.07, 0.39), (0.07, 0.39)]
    return [
        ("B", everywhere),
        ("K", anyof(line(0.0, 0.2, 1.0, 0.1, 0.06), line(0.5, 0.15, 0.5, 0.42, 0.04))),
        ("D", anyof(ellipse(0.2, 0.3, 0.14, 0.06), ellipse(0.82, 0.25, 0.14, 0.06), ellipse(0.75, 0.05, 0.12, 0.05))),
        ("R", anyof(*[circle(0.5 + dx, 0.48 + dy, 0.065) for dx, dy in berries])),
        ("W", rect(0, 0.92, 1, 1)),
    ]

def snegir():
    return [
        ("B", everywhere),
        ("K", line(0.0, 0.78, 1.0, 0.7, 0.06)),
        ("W", line(0.0, 0.74, 1.0, 0.66, 0.035)),
        ("A", ellipse(0.5, 0.52, 0.25, 0.2)),
        ("N", poly((0.68, 0.5), (0.95, 0.4), (0.95, 0.5), (0.7, 0.58))),
        ("R", both(ellipse(0.45, 0.56, 0.2, 0.16), rect(0, 0.45, 0.6, 1))),
        ("N", circle(0.3, 0.33, 0.13)),
        ("W", circle(0.26, 0.31, 0.03)),
        ("N", poly((0.15, 0.32), (0.08, 0.36), (0.16, 0.38))),
    ]

def ushanka():
    return [
        ("B", everywhere),
        ("S", ellipse(0.5, 0.62, 0.2, 0.24)),
        ("N", anyof(circle(0.42, 0.6, 0.03), circle(0.58, 0.6, 0.03))),
        ("R", ellipse(0.5, 0.74, 0.06, 0.025)),
        ("K", both(ellipse(0.5, 0.4, 0.36, 0.32), rect(0, 0, 1, 0.4))),
        ("A", anyof(rect(0.12, 0.33, 0.88, 0.45),
                    both(ellipse(0.2, 0.62, 0.09, 0.26), rect(0, 0.4, 1, 1)),
                    both(ellipse(0.8, 0.62, 0.09, 0.26), rect(0, 0.4, 1, 1)))),
        ("K", anyof(line(0.2, 0.86, 0.3, 0.97, 0.035), line(0.8, 0.86, 0.7, 0.97, 0.035))),
    ]

def medved():
    return [
        ("G", everywhere),
        ("K", anyof(circle(0.25, 0.25, 0.12), circle(0.75, 0.25, 0.12), circle(0.5, 0.55, 0.35))),
        ("L", anyof(circle(0.25, 0.25, 0.06), circle(0.75, 0.25, 0.06), ellipse(0.5, 0.68, 0.16, 0.13))),
        ("N", anyof(circle(0.38, 0.48, 0.035), circle(0.62, 0.48, 0.035), ellipse(0.5, 0.62, 0.06, 0.04))),
        ("N", rect(0.49, 0.62, 0.51, 0.72)),
    ]

def lisa():
    return [
        ("D", everywhere),
        ("O", anyof(poly((0.1, 0.1), (0.35, 0.3), (0.2, 0.45)), poly((0.9, 0.1), (0.65, 0.3), (0.8, 0.45)),
                    poly((0.15, 0.3), (0.85, 0.3), (0.5, 0.9)), ellipse(0.5, 0.42, 0.33, 0.18))),
        ("N", anyof(poly((0.1, 0.1), (0.2, 0.18), (0.14, 0.24)), poly((0.9, 0.1), (0.8, 0.18), (0.86, 0.24)))),
        ("W", anyof(poly((0.2, 0.5), (0.5, 0.55), (0.5, 0.9)), poly((0.8, 0.5), (0.5, 0.55), (0.5, 0.9)))),
        ("N", anyof(circle(0.36, 0.43, 0.035), circle(0.64, 0.43, 0.035), circle(0.5, 0.86, 0.045))),
    ]

def petushok():
    return [
        ("S", everywhere),
        ("K", rect(0.47, 0.7, 0.53, 1)),
        ("R", anyof(ellipse(0.48, 0.5, 0.25, 0.2), circle(0.68, 0.3, 0.12),
                    poly((0.3, 0.45), (0.1, 0.2), (0.2, 0.5)), poly((0.3, 0.5), (0.05, 0.4), (0.2, 0.62)))),
        ("Y", anyof(circle(0.66, 0.16, 0.05), circle(0.74, 0.17, 0.045), poly((0.79, 0.29), (0.92, 0.33), (0.79, 0.36)))),
        ("O", ellipse(0.73, 0.43, 0.04, 0.06)),
        ("N", circle(0.71, 0.28, 0.025)),
        ("Y", anyof(line(0.38, 0.68, 0.36, 0.75, 0.03), line(0.55, 0.68, 0.57, 0.75, 0.03))),
    ]

def raketa():
    stars = [(0.1, 0.1), (0.85, 0.15), (0.15, 0.6), (0.9, 0.55), (0.75, 0.85), (0.25, 0.9)]
    return [
        ("N", everywhere),
        ("Y", anyof(*[circle(x, y, 0.025) for x, y in stars])),
        ("O", poly((0.4, 0.78), (0.6, 0.78), (0.5, 0.98))),
        ("R", anyof(poly((0.38, 0.55), (0.25, 0.8), (0.38, 0.75)), poly((0.62, 0.55), (0.75, 0.8), (0.62, 0.75)))),
        ("W", anyof(ellipse(0.5, 0.45, 0.13, 0.35))),
        ("R", both(ellipse(0.5, 0.45, 0.13, 0.35), rect(0, 0, 1, 0.22))),
        ("B", circle(0.5, 0.42, 0.06)),
        ("R", rect(0.38, 0.72, 0.62, 0.78)),
    ]

def bashnya():
    return [
        ("B", everywhere),
        ("R", anyof(rect(0.26, 0.55, 0.74, 1), rect(0.34, 0.3, 0.66, 0.55))),
        ("W", anyof(*[rect(0.26 + i * 0.13, 0.5, 0.32 + i * 0.13, 0.55) for i in range(4)])),
        ("G", poly((0.5, 0.06), (0.34, 0.31), (0.66, 0.31))),
        ("Y", rect(0.47, 0.0, 0.53, 0.07)),
        ("W", circle(0.5, 0.41, 0.09)),
        ("N", anyof(rect(0.49, 0.35, 0.51, 0.42), rect(0.5, 0.41, 0.56, 0.43))),
        ("N", both(ellipse(0.5, 1, 0.12, 0.2), rect(0, 0.82, 1, 1))),
    ]

def zharptica():
    return [
        ("P", everywhere),
        ("Y", anyof(line(0.4, 0.55, 0.02, 0.8, 0.09), line(0.42, 0.58, 0.2, 0.98, 0.09))),
        ("R", anyof(line(0.4, 0.55, 0.06, 0.95, 0.08), line(0.45, 0.6, 0.42, 0.98, 0.08))),
        ("O", anyof(ellipse(0.55, 0.5, 0.2, 0.13), line(0.62, 0.45, 0.72, 0.28, 0.1), circle(0.73, 0.25, 0.08))),
        ("R", ellipse(0.5, 0.45, 0.13, 0.07)),
        ("Y", anyof(line(0.72, 0.18, 0.66, 0.06, 0.04), line(0.75, 0.18, 0.8, 0.06, 0.04))),
        ("Y", poly((0.8, 0.22), (0.93, 0.26), (0.8, 0.3))),
        ("N", circle(0.74, 0.23, 0.025)),
    ]

def dome(cx, cy, r):
    """Луковичный купол: круг снизу и острый носик сверху."""
    return anyof(circle(cx, cy, r), poly((cx - r * 0.75, cy - r * 0.5), (cx + r * 0.75, cy - r * 0.5), (cx, cy - r * 2.1)))

def sobor():
    left, mid, right = dome(0.22, 0.42, 0.1), dome(0.5, 0.3, 0.13), dome(0.78, 0.42, 0.1)
    return [
        ("B", everywhere),
        ("W", anyof(ellipse(0.12, 0.12, 0.1, 0.04), ellipse(0.85, 0.08, 0.1, 0.035))),
        ("G", rect(0, 0.9, 1, 1)),
        # барабаны под куполами
        ("Y", anyof(rect(0.17, 0.5, 0.27, 0.62), rect(0.44, 0.42, 0.56, 0.62), rect(0.73, 0.5, 0.83, 0.62))),
        ("R", anyof(rect(0.1, 0.62, 0.9, 0.92), rect(0.4, 0.55, 0.6, 0.62))),
        ("W", anyof(*[rect(0.15 + i * 0.14, 0.7, 0.21 + i * 0.14, 0.78) for i in range(6)])),
        ("K", both(ellipse(0.5, 0.92, 0.08, 0.12), rect(0, 0.82, 1, 0.92))),
        ("G", left), ("Y", stripes(left, 14)),
        ("P", mid), ("W", stripes(mid, 12)),
        ("O", right), ("R", stripes(right, 14)),
        ("Y", anyof(rect(0.215, 0.16, 0.225, 0.22), rect(0.495, 0.0, 0.505, 0.04), rect(0.775, 0.16, 0.785, 0.22))),
    ]


# (название, функция) по порядку уровней. Сложность = номер десятка.
LEVELS = [
    ("Колобок", kolobok), ("Мухомор", muhomor), ("Снеговик", snegovik), ("Ёлка", yolka),
    ("Валенок", valenok), ("Матрёшка", matreshka), ("Берёза", bereza), ("Избушка", izbushka),
    ("Самовар", samovar), ("Балалайка", balalaika),
    ("Боровик", borovik), ("Рябина", ryabina), ("Снегирь", snegir), ("Ушанка", ushanka),
    ("Медведь", medved), ("Лиса", lisa), ("Петушок", petushok), ("Ракета", raketa),
    ("Башня", bashnya), ("Жар-птица", zharptica),
    ("Собор", sobor),
]

# Размер сетки для каждой сложности (по десяткам уровней).
SIZES = [16, 20, 24, 26, 26, 28, 28, 30, 30, 32]


def render(layers, n):
    rows = []
    for r in range(n):
        line_ = ""
        for c in range(n):
            x, y = (c + 0.5) / n, (r + 0.5) / n
            color = "."
            for col, shape in layers:
                if shape(x, y):
                    color = col
            line_ += color
        rows.append(line_)
    return rows


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = ["# Сгенерировано tools/make_levels.py — не редактируй руками.",
           "class_name Levels", "", "const LIST := ["]
    rendered = []
    for i, (name, fn) in enumerate(LEVELS):
        rows = render(fn(), SIZES[i // 10])
        rendered.append((name, rows))
        out.append("\t{")
        out.append('\t\t"name": "%s",' % name)
        out.append('\t\t"map": [')
        out.extend('\t\t\t"%s",' % r for r in rows)
        out.append("\t\t],")
        out.append("\t},")
    out.append("]")
    with open(os.path.join(root, "scripts", "levels.gd"), "w") as f:
        f.write("\n".join(out) + "\n")

    if len(sys.argv) > 1:
        from PIL import Image, ImageDraw
        cell, cols = 12, 5
        size = max(len(r) for _, r in rendered) * cell + 30
        img = Image.new("RGB", (cols * size, math.ceil(len(rendered) / cols) * size), "#333250")
        d = ImageDraw.Draw(img)
        for i, (name, rows) in enumerate(rendered):
            ox, oy = (i % cols) * size, (i // cols) * size
            d.text((ox + 4, oy + 2), "%d" % (i + 1), fill="white")
            for r, row in enumerate(rows):
                for c, ch in enumerate(row):
                    if ch != ".":
                        d.rectangle([ox + c * cell, oy + 16 + r * cell, ox + c * cell + cell - 2,
                                     oy + 16 + r * cell + cell - 2], fill="#" + PALETTE[ch])
        img.save(os.path.join(sys.argv[1], "levels_preview.png"))


if __name__ == "__main__":
    main()
