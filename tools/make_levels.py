#!/usr/bin/env python3
"""Генератор картинок для уровней.

Каждая картинка описана фигурами в координатах 0..1 (x вправо, y вниз),
поэтому её можно отрисовать в любом размере сетки.
Запуск:  python3 tools/make_levels.py [папка_для_превью]
Пишет scripts/levels.gd (и превью PNG, если указана папка).
"""
import math
import os
import random
import sys

# Цвета должны совпадать с Level.COLORS в scripts/level.gd
PALETTE = {
    "R": "e8202a", "W": "ffffff", "Y": "ffd400", "G": "22b53a", "B": "1f8fff",
    "P": "7a3cf0", "O": "ff7a00", "K": "7a4520", "N": "1b1b2b", "D": "0f6b2c",
    "S": "ff6fb5", "A": "9aa3b8", "L": "f7c48a",
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
        ("B", everywhere),
        ("G", rect(0, 0.84, 1, 1)),
        ("K", rect(0.47, 0.7, 0.53, 0.9)),
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
        ("S", circle(0.84, 0.24, 0.1)),
        ("P", ellipse(0.5, 1.02, 0.85, 0.3)),
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

def dome(cx, cy, r):
    """Луковичный купол: круг снизу и острый носик сверху."""
    return anyof(circle(cx, cy, r), poly((cx - r * 0.75, cy - r * 0.5), (cx + r * 0.75, cy - r * 0.5), (cx, cy - r * 2.1)))

def star(cx, cy, r, inner=0.45, n=5):
    pts = []
    for i in range(n * 2):
        a = -math.pi / 2 + i * math.pi / n
        k = r if i % 2 == 0 else r * inner
        pts.append((cx + math.cos(a) * k, cy + math.sin(a) * k))
    return poly(*pts)

def ring(cx, cy, r, w):
    return minus(circle(cx, cy, r), circle(cx, cy, r - w))

def cross(cx, top, h):
    return anyof(rect(cx - 0.008, top, cx + 0.008, top + h), rect(cx - 0.025, top + h * 0.25, cx + 0.025, top + h * 0.4))

def fir(cx, bottom, w, h):
    return anyof(poly((cx, bottom - h), (cx - w * 0.35, bottom - h * 0.5), (cx + w * 0.35, bottom - h * 0.5)),
                 poly((cx, bottom - h * 0.75), (cx - w / 2, bottom - h * 0.1), (cx + w / 2, bottom - h * 0.1)))

def sobor():
    left, mid, right = dome(0.25, 0.38, 0.085), dome(0.5, 0.26, 0.12), dome(0.75, 0.38, 0.085)
    far_l, far_r = dome(0.08, 0.5, 0.06), dome(0.92, 0.5, 0.06)
    return [
        ("B", everywhere),
        ("Y", circle(0.9, 0.08, 0.07)),
        ("W", anyof(ellipse(0.13, 0.1, 0.11, 0.04), ellipse(0.2, 0.07, 0.06, 0.04),
                    ellipse(0.72, 0.13, 0.09, 0.03), ellipse(0.78, 0.11, 0.05, 0.03))),
        ("G", rect(0, 0.9, 1, 1)),
        ("D", anyof(fir(0.05, 0.94, 0.12, 0.2), fir(0.95, 0.94, 0.12, 0.2))),
        # боковые башенки
        ("S", anyof(rect(0.04, 0.55, 0.12, 0.9), rect(0.88, 0.55, 0.96, 0.9))),
        ("N", anyof(rect(0.065, 0.62, 0.095, 0.7), rect(0.905, 0.62, 0.935, 0.7))),
        ("D", far_l), ("W", stripes(far_l, 16)),
        ("D", far_r), ("W", stripes(far_r, 16, 1)),
        # барабаны под куполами
        ("Y", anyof(rect(0.2, 0.45, 0.3, 0.6), rect(0.43, 0.36, 0.57, 0.56), rect(0.7, 0.45, 0.8, 0.6))),
        ("N", anyof(rect(0.235, 0.49, 0.265, 0.56), rect(0.465, 0.42, 0.49, 0.5), rect(0.51, 0.42, 0.535, 0.5),
                    rect(0.735, 0.49, 0.765, 0.56))),
        # главный корпус
        ("R", anyof(rect(0.14, 0.6, 0.86, 0.92), rect(0.38, 0.54, 0.62, 0.6))),
        ("W", anyof(rect(0.14, 0.6, 0.86, 0.625), rect(0.14, 0.75, 0.86, 0.77))),
        ("W", anyof(*[both(rect(0.18 + i * 0.12, 0.66, 0.24 + i * 0.12, 0.73), anyof(rect(0, 0.68, 1, 1), circle(0.21 + i * 0.12, 0.68, 0.03)))
                      for i in range(6) if i not in (2, 3)])),
        ("B", anyof(*[rect(0.195 + i * 0.12, 0.685, 0.225 + i * 0.12, 0.725) for i in range(6) if i not in (2, 3)])),
        ("K", both(ellipse(0.5, 0.92, 0.09, 0.2), rect(0, 0.76, 1, 0.92))),
        ("O", both(ellipse(0.5, 0.92, 0.05, 0.13), rect(0, 0.82, 1, 0.92))),
        ("A", rect(0.1, 0.92, 0.9, 0.96)),
        ("A", rect(0.3, 0.96, 0.7, 1)),
        ("G", left), ("Y", stripes(left, 14)),
        ("P", mid), ("W", stripes(mid, 12)),
        ("O", right), ("R", stripes(right, 14, 1)),
        ("Y", anyof(cross(0.25, 0.13, 0.08), cross(0.5, 0.0, 0.03), cross(0.75, 0.13, 0.08),
                    cross(0.08, 0.32, 0.06), cross(0.92, 0.32, 0.06))),
    ]

def hohloma():
    """Хохломская роспись: золото и алые ягоды на чёрном."""
    berries = [(0.3, 0.3), (0.38, 0.24), (0.36, 0.35), (0.68, 0.62), (0.75, 0.56), (0.74, 0.68),
               (0.25, 0.72), (0.2, 0.78), (0.3, 0.8), (0.72, 0.22), (0.8, 0.28)]
    swirl = anyof(ring(0.5, 0.5, 0.3, 0.05), line(0.5, 0.2, 0.62, 0.05, 0.04), line(0.5, 0.8, 0.38, 0.95, 0.04))
    leaves = anyof(ellipse(0.5, 0.5, 0.12, 0.06), ellipse(0.5, 0.5, 0.06, 0.12),
                   ellipse(0.15, 0.45, 0.07, 0.035), ellipse(0.85, 0.45, 0.07, 0.035),
                   ellipse(0.5, 0.1, 0.035, 0.07), ellipse(0.12, 0.15, 0.06, 0.03), ellipse(0.88, 0.88, 0.06, 0.03),
                   ellipse(0.58, 0.88, 0.05, 0.03), ellipse(0.45, 0.68, 0.05, 0.03), ellipse(0.55, 0.32, 0.05, 0.03))
    return [
        ("N", everywhere),
        ("O", anyof(rect(0, 0, 1, 0.04), rect(0, 0.96, 1, 1), rect(0, 0, 0.04, 1), rect(0.96, 0, 1, 1))),
        ("Y", swirl),
        ("D", leaves),
        ("Y", anyof(ellipse(0.5, 0.5, 0.06, 0.03), ellipse(0.5, 0.5, 0.03, 0.06))),
        ("R", anyof(*[circle(x, y, 0.045) for x, y in berries])),
        ("O", anyof(*[circle(x - 0.01, y - 0.01, 0.015) for x, y in berries])),
        ("R", circle(0.5, 0.5, 0.025)),
    ]

def gzhel():
    """Гжельский чайник: синий узор на белом."""
    body = anyof(ellipse(0.48, 0.6, 0.3, 0.24), rect(0.3, 0.38, 0.66, 0.5))
    return [
        ("B", everywhere),
        ("A", rect(0, 0.5, 1, 1)),
        ("W", anyof(*[circle(0.08 + i * 0.12, 0.04, 0.025) for i in range(8)])),
        ("K", rect(0, 0.76, 1, 1)),
        ("N", rect(0, 0.9, 1, 1)),
        ("W", anyof(body, line(0.74, 0.62, 0.92, 0.36, 0.06), ring(0.17, 0.55, 0.13, 0.05))),
        ("W", anyof(ellipse(0.48, 0.36, 0.2, 0.06), circle(0.48, 0.26, 0.05))),
        ("N", ring(0.48, 0.6, 0.18, 0.03)),
        ("B", anyof(ellipse(0.48, 0.5, 0.04, 0.08), ellipse(0.48, 0.7, 0.04, 0.08),
                    ellipse(0.38, 0.6, 0.08, 0.04), ellipse(0.58, 0.6, 0.08, 0.04))),
        ("N", circle(0.48, 0.6, 0.035)),
        ("B", anyof(rect(0.22, 0.79, 0.74, 0.83), rect(0.3, 0.4, 0.66, 0.43), circle(0.48, 0.26, 0.025))),
        ("N", rect(0.26, 0.84, 0.7, 0.9)),
        ("B", anyof(*[circle(0.22 + i * 0.065, 0.81, 0.012) for i in range(9)])),
    ]

def yozhik():
    spikes = [poly((0.2 + i * 0.07, 0.62), (0.26 + i * 0.07, 0.62), (0.16 + i * 0.07, 0.2 + abs(i - 4) * 0.035))
              for i in range(9)]
    return [
        ("D", everywhere),
        ("G", rect(0, 0.78, 1, 1)),
        ("Y", anyof(*[circle(x, y, 0.025) for x, y in [(0.1, 0.9), (0.85, 0.92), (0.6, 0.95)]])),
        ("K", anyof(both(ellipse(0.48, 0.6, 0.32, 0.25), rect(0, 0, 1, 0.75)), *spikes)),
        ("N", anyof(*[line(0.25 + i * 0.07, 0.6, 0.22 + i * 0.07, 0.42 + abs(i - 3) * 0.03, 0.02) for i in range(7)])),
        ("L", anyof(ellipse(0.75, 0.64, 0.14, 0.12), poly((0.8, 0.58), (0.95, 0.66), (0.82, 0.72)))),
        ("N", anyof(circle(0.94, 0.66, 0.03), circle(0.76, 0.6, 0.025))),
        ("K", anyof(rect(0.3, 0.74, 0.36, 0.8), rect(0.6, 0.74, 0.66, 0.8))),
        ("R", circle(0.45, 0.2, 0.09)),
        ("D", ellipse(0.5, 0.09, 0.05, 0.025)),
        ("W", circle(0.41, 0.17, 0.025)),
        ("K", rect(0.445, 0.08, 0.46, 0.12)),
    ]

def filin():
    return [
        ("N", everywhere),
        ("Y", anyof(star(0.1, 0.1, 0.035), star(0.3, 0.06, 0.025), star(0.6, 0.08, 0.03), star(0.08, 0.5, 0.03))),
        ("W", circle(0.82, 0.18, 0.12)),
        ("N", circle(0.88, 0.14, 0.1)),
        ("K", anyof(line(0.0, 0.84, 1.0, 0.8, 0.07), line(0.7, 0.81, 0.95, 0.95, 0.04))),
        ("D", anyof(ellipse(0.15, 0.78, 0.08, 0.035), ellipse(0.86, 0.9, 0.07, 0.03))),
        ("K", anyof(ellipse(0.5, 0.55, 0.24, 0.27), poly((0.3, 0.3), (0.32, 0.14), (0.42, 0.28)),
                    poly((0.7, 0.3), (0.68, 0.14), (0.58, 0.28)))),
        ("L", ellipse(0.5, 0.65, 0.15, 0.15)),
        ("K", anyof(*[poly((0.42 + dx, 0.58 + dy), (0.46 + dx, 0.58 + dy), (0.44 + dx, 0.62 + dy))
                      for dx in (0, 0.08, 0.16) for dy in (0, 0.08)])),
        ("W", anyof(circle(0.41, 0.4, 0.085), circle(0.59, 0.4, 0.085))),
        ("Y", anyof(circle(0.41, 0.4, 0.055), circle(0.59, 0.4, 0.055))),
        ("N", anyof(circle(0.41, 0.4, 0.025), circle(0.59, 0.4, 0.025))),
        ("O", poly((0.47, 0.46), (0.53, 0.46), (0.5, 0.54))),
        ("O", anyof(*[rect(x, 0.78, x + 0.03, 0.83) for x in (0.4, 0.45, 0.53, 0.58)])),
    ]

def mayak():
    tower = poly((0.42, 0.25), (0.58, 0.25), (0.64, 0.82), (0.36, 0.82))
    return [
        ("P", everywhere),
        ("S", rect(0, 0.45, 1, 0.65)),
        ("O", both(circle(0.85, 0.65, 0.12), rect(0, 0, 1, 0.65))),
        ("Y", anyof(poly((0.5, 0.18), (0.0, 0.05), (0.0, 0.25)), poly((0.5, 0.18), (1.0, 0.08), (1.0, 0.26)))),
        ("B", rect(0, 0.65, 1, 1)),
        ("W", anyof(*[rect(0.05 + i * 0.2 + (r % 2) * 0.1, 0.7 + r * 0.08, 0.13 + i * 0.2 + (r % 2) * 0.1, 0.715 + r * 0.08)
                      for i in range(5) for r in range(4)])),
        ("A", ellipse(0.5, 0.86, 0.3, 0.07)),
        ("W", tower),
        ("R", anyof(both(tower, rect(0, 0.33, 1, 0.43)), both(tower, rect(0, 0.53, 1, 0.63)), both(tower, rect(0, 0.73, 1, 0.82)))),
        ("N", anyof(rect(0.38, 0.22, 0.62, 0.25), rect(0.44, 0.1, 0.56, 0.22))),
        ("Y", rect(0.46, 0.12, 0.54, 0.21)),
        ("R", poly((0.42, 0.1), (0.58, 0.1), (0.5, 0.03))),
        ("K", rect(0.47, 0.73, 0.53, 0.82)),
        ("W", anyof(poly((0.18, 0.72), (0.24, 0.72), (0.2, 0.62)), rect(0.12, 0.72, 0.26, 0.75))),
    ]

def tigr():
    head = anyof(ellipse(0.5, 0.55, 0.36, 0.33), circle(0.22, 0.25, 0.1), circle(0.78, 0.25, 0.1))
    return [
        ("D", everywhere),
        ("G", anyof(*[poly((x, 1), (x + 0.03, 0.82 - (i % 3) * 0.04), (x + 0.06, 1)) for i, x in enumerate([0.0, 0.08, 0.86, 0.93])])),
        ("O", head),
        ("N", anyof(circle(0.22, 0.25, 0.05), circle(0.78, 0.25, 0.05))),
        ("N", anyof(poly((0.42, 0.24), (0.58, 0.24), (0.5, 0.36)), poly((0.47, 0.22), (0.53, 0.22), (0.5, 0.3)),
                    poly((0.15, 0.45), (0.3, 0.48), (0.15, 0.5)), poly((0.85, 0.45), (0.7, 0.48), (0.85, 0.5)),
                    poly((0.15, 0.58), (0.28, 0.58), (0.17, 0.63)), poly((0.85, 0.58), (0.72, 0.58), (0.83, 0.63)),
                    poly((0.3, 0.27), (0.38, 0.32), (0.32, 0.36)), poly((0.7, 0.27), (0.62, 0.32), (0.68, 0.36)))),
        ("W", anyof(ellipse(0.5, 0.72, 0.2, 0.14), ellipse(0.33, 0.45, 0.08, 0.05), ellipse(0.67, 0.45, 0.08, 0.05))),
        ("Y", anyof(circle(0.35, 0.45, 0.04), circle(0.65, 0.45, 0.04))),
        ("N", anyof(rect(0.34, 0.42, 0.36, 0.48), rect(0.64, 0.42, 0.66, 0.48))),
        ("S", poly((0.43, 0.6), (0.57, 0.6), (0.5, 0.67))),
        ("N", anyof(rect(0.49, 0.66, 0.51, 0.74), line(0.5, 0.74, 0.42, 0.78, 0.02), line(0.5, 0.74, 0.58, 0.78, 0.02))),
        ("N", anyof(*[circle(x, y, 0.012) for x in (0.38, 0.62) for y in (0.69, 0.73)])),
    ]

def korabl():
    hull = poly((0.12, 0.62), (0.88, 0.62), (0.78, 0.76), (0.22, 0.76))
    return [
        ("B", everywhere),
        ("Y", circle(0.12, 0.12, 0.07)),
        ("W", anyof(ellipse(0.7, 0.08, 0.1, 0.035), ellipse(0.38, 0.14, 0.08, 0.03))),
        ("K", anyof(rect(0.33, 0.12, 0.36, 0.64), rect(0.6, 0.18, 0.63, 0.64))),
        ("W", anyof(poly((0.37, 0.15), (0.37, 0.56), (0.58, 0.56)), poly((0.32, 0.2), (0.32, 0.56), (0.14, 0.56)),
                    poly((0.64, 0.22), (0.64, 0.56), (0.85, 0.56)))),
        ("R", anyof(rect(0.33, 0.07, 0.42, 0.11), rect(0.6, 0.13, 0.69, 0.17))),
        ("R", anyof(both(poly((0.37, 0.15), (0.37, 0.56), (0.58, 0.56)), rect(0, 0.4, 1, 0.46)),
                    both(poly((0.64, 0.22), (0.64, 0.56), (0.85, 0.56)), rect(0, 0.4, 1, 0.46)))),
        ("K", hull),
        ("O", both(hull, rect(0, 0.62, 1, 0.66))),
        ("Y", anyof(*[circle(0.3 + i * 0.1, 0.7, 0.018) for i in range(5)])),
        ("P", rect(0, 0.76, 1, 1)),
        ("N", anyof(*[both(ellipse(0.06 + i * 0.13 + (r % 2) * 0.06, 0.8 + r * 0.07, 0.07, 0.03), rect(0, 0, 1, 0.8 + r * 0.07))
                      for i in range(8) for r in range(3)])),
        ("W", anyof(*[rect(0.1 + i * 0.25 + (r % 2) * 0.12, 0.83 + r * 0.06, 0.16 + i * 0.25 + (r % 2) * 0.12, 0.845 + r * 0.06)
                      for i in range(4) for r in range(3)])),
    ]

# ---------- фигуры: каждый пятый уровень ----------
# Только сам предмет, без фона: пустые клетки поля так и остаются пустыми.

def yabloko():
    body = anyof(circle(0.37, 0.57, 0.3), circle(0.63, 0.57, 0.3), ellipse(0.5, 0.75, 0.3, 0.17))
    return [
        ("R", minus(body, ellipse(0.5, 0.27, 0.07, 0.06))),
        ("Y", both(body, ellipse(0.74, 0.66, 0.2, 0.28))),
        ("S", ellipse(0.3, 0.45, 0.06, 0.1)),
        ("K", rect(0.44, 0.08, 0.56, 0.32)),
        ("G", poly((0.53, 0.2), (0.7, 0.1), (0.85, 0.14), (0.7, 0.26))),
    ]


def grusha():
    body = anyof(circle(0.5, 0.68, 0.27), ellipse(0.5, 0.42, 0.16, 0.24))
    return [
        ("G", body),
        ("Y", both(body, circle(0.36, 0.6, 0.2))),
        ("O", both(body, circle(0.66, 0.8, 0.12))),
        ("W", ellipse(0.38, 0.62, 0.05, 0.09)),
        ("K", rect(0.44, 0.04, 0.56, 0.22)),
        ("D", poly((0.53, 0.14), (0.68, 0.04), (0.82, 0.08), (0.67, 0.2))),
    ]


def klubnika():
    body = anyof(circle(0.36, 0.42, 0.2), circle(0.64, 0.42, 0.2), poly((0.17, 0.46), (0.83, 0.46), (0.5, 0.94)))
    seeds = [rect(x - 0.03, y - 0.03, x + 0.03, y + 0.03)
             for x, y in ((0.3, 0.38), (0.5, 0.36), (0.7, 0.38), (0.4, 0.5), (0.6, 0.5), (0.3, 0.58),
                          (0.5, 0.62), (0.7, 0.58), (0.42, 0.72), (0.58, 0.72), (0.5, 0.83))]
    # Недозрелая: кончик белый, над ним розовая полоса — чтобы красный не занимал всю ягоду.
    return [
        ("R", body),
        ("S", both(body, rect(0, 0.5, 1, 0.64))),
        ("W", both(body, rect(0, 0.64, 1, 1))),
        ("Y", anyof(*seeds)),
        ("D", anyof(poly((0.25, 0.26), (0.5, 0.18), (0.75, 0.26), (0.62, 0.32), (0.5, 0.27), (0.38, 0.32)),
                    poly((0.4, 0.24), (0.5, 0.06), (0.6, 0.24)))),
        ("G", rect(0.47, 0.04, 0.53, 0.16)),
    ]


def arbuz():
    def half(r):
        return both(circle(0.5, 0.26, r), rect(0, 0.26, 1, 1))
    seeds = [ellipse(x, y, 0.025, 0.04) for x, y in ((0.3, 0.35), (0.42, 0.45), (0.58, 0.45), (0.7, 0.35),
                                                    (0.5, 0.58), (0.36, 0.56), (0.64, 0.56), (0.5, 0.33))]
    return [
        ("D", half(0.48)),
        ("G", half(0.42)),
        ("W", half(0.38)),
        ("R", half(0.35)),
        ("N", anyof(*seeds)),
    ]


def vinograd():
    rows = [(0.22, [0.3, 0.44, 0.58, 0.72]), (0.36, [0.37, 0.51, 0.65]), (0.5, [0.3, 0.44, 0.58, 0.72]),
            (0.64, [0.37, 0.51, 0.65]), (0.78, [0.44, 0.58]), (0.9, [0.51])]
    berries = [circle(x, y + 0.04, 0.075) for y, xs in rows for x in xs]
    # Ягоды трёх сортов вперемешку, чтобы один цвет не занимал всю гроздь.
    return [
        ("P", anyof(*berries[0::3])),
        ("B", anyof(*berries[1::3])),
        ("R", anyof(*berries[2::3])),
        ("S", anyof(*[circle(x - 0.025, y + 0.015, 0.02) for y, xs in rows for x in xs])),
        ("K", line(0.51, 0.02, 0.51, 0.2, 0.05)),
        ("G", poly((0.53, 0.1), (0.72, 0.02), (0.92, 0.08), (0.8, 0.2), (0.62, 0.18))),
    ]


def ananas():
    body = ellipse(0.5, 0.66, 0.24, 0.3)
    return [
        ("O", body),
        # Верх ещё не дозрел — светлее, низ спелый — оранжевый.
        ("L", both(body, rect(0, 0, 1, 0.6))),
        ("Y", both(body, lambda x, y: int((x + y) * 14) % 2 == 0 and int((x - y) * 14) % 2 == 0)),
        ("K", both(body, lambda x, y: abs(((x + y) * 14) % 1 - 0.5) < 0.08 or abs(((x - y) * 14) % 1 - 0.5) < 0.08)),
        ("D", anyof(poly((0.5, 0.02), (0.56, 0.38), (0.44, 0.38)),
                    poly((0.3, 0.1), (0.5, 0.38), (0.4, 0.38)),
                    poly((0.7, 0.1), (0.6, 0.38), (0.5, 0.38)))),
        ("G", anyof(poly((0.18, 0.2), (0.45, 0.38), (0.35, 0.4)), poly((0.82, 0.2), (0.55, 0.4), (0.65, 0.38)))),
    ]


# Уровни-фигуры: без фона и без деталей на нём.
FIGURES = {"Яблоко", "Груша", "Клубника", "Арбуз", "Виноград", "Ананас"}


# (название, функция) по порядку уровней. Сложность = номер десятка.
LEVELS = [
    ("Колобок", kolobok), ("Мухомор", muhomor), ("Снеговик", snegovik), ("Ёлка", yolka),
    ("Яблоко", yabloko), ("Матрёшка", matreshka), ("Берёза", bereza), ("Избушка", izbushka),
    ("Самовар", samovar), ("Груша", grusha),
    ("Боровик", borovik), ("Рябина", ryabina), ("Снегирь", snegir), ("Ушанка", ushanka),
    ("Клубника", klubnika), ("Лиса", lisa), ("Петушок", petushok), ("Ракета", raketa),
    ("Башня", bashnya), ("Арбуз", arbuz),
    ("Собор", sobor), ("Хохлома", hohloma), ("Гжель", gzhel), ("Ёжик", yozhik), ("Виноград", vinograd),
    ("Филин", filin), ("Маяк", mayak), ("Тигр", tigr), ("Корабль", korabl), ("Ананас", ananas),
]

# Размер сетки для каждой сложности (по десяткам уровней).
SIZES = [16, 20, 24, 24, 24, 24, 24, 24, 24, 24]
# Фигуры не занимают всё поле, поэтому сетка у них крупнее — чтобы блоков было примерно как у соседей.
FIGURE_SIZES = [22, 26, 30, 30, 30, 30, 30, 30, 30, 30]


def fit(layers):
    """Растягивает фигуру, чтобы она почти касалась краёв поля (с сохранением пропорций)."""
    steps = 200
    points = [((c + 0.5) / steps, (r + 0.5) / steps) for r in range(steps) for c in range(steps)]
    inside = [(x, y) for x, y in points if any(shape(x, y) for _, shape in layers)]
    x0, x1 = min(x for x, _ in inside), max(x for x, _ in inside)
    y0, y1 = min(y for _, y in inside), max(y for _, y in inside)
    side = max(x1 - x0, y1 - y0) * 1.04
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2

    def remap(shape):
        return lambda x, y: shape(cx + (x - 0.5) * side, cy + (y - 0.5) * side)
    return [(color, remap(shape)) for color, shape in layers]


# Тень (нижний и правый край фигуры) и блик (верхний и левый) для каждого цвета.
# Свет падает слева сверху. None — тени или блика у цвета нет.
SHADE = {"R": "K", "W": "A", "Y": "O", "G": "D", "B": "P", "P": "N", "O": "K",
         "K": "N", "N": None, "D": "N", "S": "R", "A": "N", "L": "O"}
# Блик — только более светлый вариант того же оттенка, иначе картинка рябит.
LIGHT = {"R": "S", "W": None, "Y": "W", "G": None, "B": None, "P": None, "O": "Y",
         "K": "L", "N": None, "D": "G", "S": "W", "A": "W", "L": "W"}


def background_details(color, name):
    """Немного деталей на однотонном фоне: облака и солнце на небе, звёзды ночью.
    Фон должен быть спокойным, чтобы картинка на нём читалась."""
    rng = random.Random(name)
    if color == "B":
        clouds = []
        for cx, cy in ((0.2, 0.12), (0.62, 0.16), (0.14, 0.45)):
            cx, cy = cx + rng.uniform(-0.05, 0.05), cy + rng.uniform(-0.04, 0.04)
            clouds += [ellipse(cx, cy, 0.14, 0.06), circle(cx - 0.05, cy - 0.04, 0.06), circle(cx + 0.04, cy - 0.05, 0.065)]
        return [("Y", circle(0.9, 0.08, 0.1)), ("W", anyof(*clouds))]
    if color == "N":
        stars = [star(x, y, 0.045) for x, y in ((rng.random(), rng.random()) for _ in range(10))]
        return [("Y", anyof(*stars))]
    return []


def render(layers, n, name=""):
    figure = name in FIGURES
    if not figure:
        layers = layers[:1] + background_details(layers[0][0], name) + layers[1:]
    grid = [["."] * n for _ in range(n)]
    owner = [[-1] * n for _ in range(n)]  # какой слой нарисовал клетку
    for r in range(n):
        for c in range(n):
            x, y = (c + 0.5) / n, (r + 0.5) / n
            for i, (col, shape) in enumerate(layers):
                if shape(x, y):
                    grid[r][c] = col
                    owner[r][c] = i
    add_volume(grid, owner, 0 if figure else 1)
    return ["".join(row) for row in grid]


def add_volume(grid, owner, first_layer):
    """Тени и блики по краям фигур. Тонкие детали (глаза, полоски) не трогаем."""
    n = len(grid)
    out = [row[:] for row in grid]

    def same(r, c, k):
        return 0 <= r < n and 0 <= c < n and owner[r][c] == k

    for r in range(n):
        for c in range(n):
            k = owner[r][c]
            if k < first_layer:
                continue  # фон и пустые клетки
            color = grid[r][c]
            # Край снизу или справа, а фигура в эту сторону толщиной хотя бы 3 клетки.
            if (not same(r + 1, c, k) and same(r - 1, c, k) and same(r - 2, c, k)) or \
               (not same(r, c + 1, k) and same(r, c - 1, k) and same(r, c - 2, k)):
                if SHADE[color]:
                    out[r][c] = SHADE[color]
            elif not same(r - 1, c, k) and same(r + 1, c, k) and same(r + 2, c, k) and \
                    same(r, c - 1, k) and same(r, c + 1, k) and same(r + 1, c - 1, k):
                # Блик только на верхнем крае, и только посреди ровного участка.
                if LIGHT[color]:
                    out[r][c] = LIGHT[color]
    for r in range(n):
        grid[r][:] = out[r]


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = ["# Сгенерировано tools/make_levels.py — не редактируй руками.",
           "class_name Levels", "", "const LIST := ["]
    rendered = []
    for i, (name, fn) in enumerate(LEVELS):
        if name in FIGURES:
            rows = render(fit(fn()), FIGURE_SIZES[i // 10], name)
        else:
            rows = render(fn(), SIZES[i // 10], name)
        rendered.append((name, rows))
        out.append("\t{")
        out.append('\t\t"name": "%s",' % name)
        if name in FIGURES:
            out.append('\t\t"figure": true,')
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
