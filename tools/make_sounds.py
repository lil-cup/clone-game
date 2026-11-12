#!/usr/bin/env python3
"""Синтезирует звуки игры в sounds/*.wav (только стандартная библиотека).

Запуск:  python3 tools/make_sounds.py
"""
import math
import os
import random
import struct
import wave

RATE = 44100


def save(path, samples):
    peak = max(abs(s) for s in samples) or 1.0
    with wave.open(path, "w") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(struct.pack("<h", int(s / peak * 0.9 * 32767)) for s in samples))


def launch():
    """Стрелок выезжает на ленту: мягкий деревянный «ток» в том же духе, что и выстрел,
    но ниже, чуть длиннее и с лёгким подъёмом тона — будто стрелка подбросили."""
    length = 0.14
    modes = [(380, 0.3, 45), (470, 0.35, 55), (610, 0.2, 70)]
    phases = [0.0] * len(modes)
    thump_phase = 0.0
    out = []
    for i in range(int(RATE * length)):
        t = i / RATE
        bend = 1 + 0.18 * (1 - math.exp(-t * 30))  # тон плавно поднимается на ~18%
        ring = 0.0
        for m, (f, a, k) in enumerate(modes):
            phases[m] += 2 * math.pi * f * bend / RATE
            ring += a * math.sin(phases[m]) * math.exp(-t * k)
        thump_phase += 2 * math.pi * 95 * bend / RATE
        thump = math.sin(thump_phase) * math.exp(-t * 90)
        out.append(min(1.0, t / 0.003) * (thump + ring))
    smooth = 0.0
    for i, v in enumerate(out):
        smooth += 0.3 * (v - smooth)
        out[i] = smooth
    return out


def wood(scale, seed):
    """Блок лопается: короткий деревянный «ток», как стук по деревяшке.
    Низкий глухой удар плюс несколько близких негармоничных резонансов около 0.7–1.3 кГц —
    они и дают «деревянность». Всё гаснет за несколько десятков миллисекунд."""
    rng = random.Random(seed)
    length = 0.08
    # (частота, громкость, скорость затухания) резонансов деревяшки
    # Резонансы пониже, тише и короче — звук тусклее и мягче.
    modes = [(560, 0.18, 110), (700, 0.25, 125), (910, 0.22, 140), (990, 0.12, 160)]
    out = []
    low = 0.0
    for i in range(int(RATE * length)):
        t = i / RATE
        thump = math.sin(2 * math.pi * 130 * scale * t) * math.exp(-t * 200)
        ring = sum(a * math.sin(2 * math.pi * f * scale * t) * math.exp(-t * k) for f, a, k in modes)
        low += 0.3 * (rng.uniform(-1, 1) - low)
        knock = 0.2 * low * math.exp(-t * 600)
        out.append(min(1.0, t / 0.0015) * (thump + ring + knock))
    # Сглаживание срезает остатки звона сверху: звук становится тусклее.
    smooth = 0.0
    for i, v in enumerate(out):
        smooth += 0.35 * (v - smooth)
        out[i] = smooth
    return out


# Чуть разный «размер» деревяшки у вариантов, чтобы очередь не звучала механически.
POP_SCALES = [0.92, 0.97, 1.02, 1.07]


def main():
    folder = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "sounds")
    os.makedirs(folder, exist_ok=True)
    save(os.path.join(folder, "launch.wav"), launch())
    for old in os.listdir(folder):
        if old.startswith("pop_"):
            os.remove(os.path.join(folder, old))
    for n, scale in enumerate(POP_SCALES):
        save(os.path.join(folder, "pop_%d.wav" % (n + 1)), wood(scale, n))


if __name__ == "__main__":
    main()
