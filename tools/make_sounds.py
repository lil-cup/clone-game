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
    """Тап по стрелку: короткий восходящий «блюп».
    Чистый синус, высота за ~20 мс скользит с 650 до ~1200 Гц: сначала быстро
    (почти до 900 Гц за пару миллисекунд), потом плавно. Атака ~1.5 мс,
    громкость держится ~4 мс и мягко гаснет к 25 мс."""
    length = 0.035
    out = []
    phase = 0.0
    for i in range(int(RATE * length)):
        t = i / RATE
        f = 640 + 190 * (1 - math.exp(-t / 0.0015)) + 21000 * t
        phase += 2 * math.pi * f / RATE
        # Спад ~2.5 дБ/мс с мягким «коленом» после короткого удержания.
        d = (t - 0.003) * 1000
        env = min(1.0, t / 0.0015) * 10 ** (-0.125 * (math.sqrt(d * d + 12.25) - 3.5)) if d > 0 else min(1.0, t / 0.0015)
        out.append(-env * math.sin(phase))
    return out


def shot(scale, seed):
    """Выстрел стрелка по блоку: сухой короткий «тик».
    Один острый импульс шириной ~0.6 мс, за ним маленький отскок,
    потом низкий отрицательный «тук»-хвост, который гаснет за ~15 мс.
    Сверху едва слышный шумовой щелчок в первую миллисекунду."""
    rng = random.Random(seed)
    length = 0.03

    def bump(t, center, width):
        u = (t - center) / width
        return 0.5 * (1 + math.cos(math.pi * u)) if abs(u) < 1 else 0.0

    out = []
    for i in range(int(RATE * length)):
        t = i / RATE / scale
        v = 1.2 * bump(t, 0.0004, 0.00045)
        v += 0.27 * bump(t, 0.0016, 0.0009)
        if t > 0.0025:
            u = t - 0.0025
            v -= 0.21 * min(1.0, u / 0.0018) * math.exp(-u / 0.007)
        v += 0.07 * rng.uniform(-1, 1) * math.exp(-t / 0.0008)
        out.append(v)
    return out


def click():
    """Нажатие кнопки: мягкий короткий «тук» — почти чистый тон 860 Гц
    с призвуком 1.3 кГц, плавная атака в пару миллисекунд и затухание за ~20 мс."""
    length = 0.05
    out = []
    for i in range(int(RATE * length)):
        t = i / RATE
        v = math.sin(2 * math.pi * 860 * t) + 0.8 * math.sin(2 * math.pi * 1335 * t) * math.exp(-t * 60)
        out.append(min(1.0, t / 0.004) * v * math.exp(-t * 150))
    return out


def fail():
    """Уровень не пройден: грустный «уа-уа-уа-уааа», как у тромбона с сурдиной.
    Четыре ноты сползают вниз по полутонам (соль-диез, соль, фа-диез, фа),
    каждая чуть съезжает вниз в конце, последняя тянется с вибрато.
    Тембр медный: основной тон, октава ниже и несколько обертонов."""
    notes = [(0.0, 0.3, 415.3), (0.3, 0.3, 392.0), (0.6, 0.35, 370.0), (0.95, 1.05, 349.2)]
    length = 2.0
    harmonics = [(0.5, 0.55), (1, 1.0), (2, 0.45), (3, 0.22), (4, 0.1)]
    out = []
    phase = 0.0
    for i in range(int(RATE * length)):
        t = i / RATE
        f = 0.0
        amp = 0.0
        for n, (start, dur, freq) in enumerate(notes):
            if start <= t < start + dur:
                u = t - start
                last = n == len(notes) - 1
                f = freq * (1 - 0.03 * (u / dur) ** 2)  # нота «опускается» к концу
                if last:
                    f *= 1 + 0.012 * math.sin(2 * math.pi * 5.5 * u) * min(1.0, u / 0.3)
                attack = min(1.0, u / 0.03)
                release = min(1.0, (start + dur - t) / 0.05)
                body = math.exp(-u * 1.6) if last else 1.0 - 0.3 * u / dur
                amp = attack * release * body
        phase += 2 * math.pi * f / RATE
        v = sum(a * math.sin(h * phase) for h, a in harmonics)
        out.append(amp * v)
    # Сглаживание делает звук глуше, как через сурдину.
    smooth = 0.0
    for i, v in enumerate(out):
        smooth += 0.25 * (v - smooth)
        out[i] = smooth
    return out


def coin():
    """Монетка долетела до счётчика: очень короткий высокий металлический «тик».
    Несколько близких негармоничных призвуков около 9.4–10.7 кГц дают звон,
    тихий тон 600 Гц добавляет телу веса. Всё гаснет за ~40 мс,
    поэтому быстрая очередь монеток звучит как дробь, а не как каша."""
    length = 0.06
    modes = [(9410, 1.0, 110), (9711, 0.6, 125), (10724, 0.3, 150), (603, 0.35, 90)]
    out = []
    for i in range(int(RATE * length)):
        t = i / RATE
        v = sum(a * math.sin(2 * math.pi * f * t) * math.exp(-t * k) for f, a, k in modes)
        out.append(min(1.0, t / 0.0005) * v)
    return out


def coins_burst():
    """Награда разлетается монетками: колокольный аккорд соль-мажор (соль и си в нескольких
    октавах) с медленным затуханием около секунды. Каждая нота звучит парой чуть
    расстроенных синусов, их биения дают мерцание. Сверху в первые полсекунды
    рассыпаются короткие высокие искорки."""
    rng = random.Random(7)
    length = 1.2
    # (частота, громкость, скорость затухания)
    notes = [(392, 0.45, 3.5), (494, 0.35, 4.0), (784, 0.8, 4.0), (988, 0.3, 5.0),
             (1568, 0.9, 4.5), (1976, 0.25, 6.0), (3136, 0.3, 7.0)]
    sparks = [(rng.uniform(0.0, 0.45), rng.uniform(7500, 11000), rng.uniform(0.15, 0.35)) for _ in range(14)]
    out = []
    for i in range(int(RATE * length)):
        t = i / RATE
        v = 0.0
        for f, a, k in notes:
            v += a * 0.5 * (math.sin(2 * math.pi * f * t) + math.sin(2 * math.pi * (f + 2.5) * t)) * math.exp(-t * k)
        for start, f, a in sparks:
            if t >= start:
                u = t - start
                v += a * math.sin(2 * math.pi * f * u) * math.exp(-u * 60)
        out.append(min(1.0, t / 0.006) * v)
    return out


def win():
    """Уровень пройден: короткая фанфара «та-да-дам» в фа-мажоре.
    Три удара подряд: фа (с октавами), потом до-ля, потом полный аккорд фа-ля-до
    в нескольких октавах, который медленно гаснет около секунды.
    Каждая нота звенит как колокольчик: основной тон, пара чуть расстроенных
    синусов для мерцания и быстро гаснущие обертоны. Сверху высокие искорки."""
    rng = random.Random(11)
    length = 1.6
    F3, C4, F4, A4, C5, F5, A5, C6, E6, F6 = 174.6, 261.6, 349.2, 440.0, 523.3, 698.5, 880.0, 1046.5, 1318.5, 1396.9
    # (начало, частота, громкость, скорость затухания)
    hits = [(0.0, F4, 1.0, 6), (0.0, F5, 0.5, 7), (0.0, F6, 0.25, 9),
            (0.17, C5, 0.8, 6), (0.17, A5, 0.45, 7), (0.17, C4, 0.4, 6),
            (0.34, F3, 0.6, 3.2), (0.34, C4, 0.6, 3.2), (0.34, F4, 0.8, 3.5), (0.34, A4, 0.55, 3.5),
            (0.34, C5, 0.6, 3.8), (0.34, F5, 0.5, 4.0), (0.34, A5, 0.35, 4.5), (0.34, C6, 0.3, 5.0),
            (0.34, E6, 0.15, 6.0), (0.34, F6, 0.25, 6.0)]
    sparks = [(rng.uniform(0.3, 0.9), rng.uniform(8500, 10600), rng.uniform(0.08, 0.2)) for _ in range(12)]
    out = []
    for i in range(int(RATE * length)):
        t = i / RATE
        v = 0.0
        for start, f, a, k in hits:
            if t < start:
                continue
            u = t - start
            tone = 0.5 * (math.sin(2 * math.pi * f * u) + math.sin(2 * math.pi * (f + 1.8) * u))
            tone += 0.3 * math.sin(2 * math.pi * f * 2 * u) * math.exp(-u * 12)
            tone += 0.12 * math.sin(2 * math.pi * f * 3 * u) * math.exp(-u * 20)
            v += a * tone * math.exp(-u * k) * min(1.0, u / 0.004)
        for start, f, a in sparks:
            if t >= start:
                u = t - start
                v += a * math.sin(2 * math.pi * f * u) * math.exp(-u * 50)
        out.append(v)
    return out


# Чуть разная высота щелчка у вариантов, чтобы очередь выстрелов не звучала механически.
POP_SCALES = [0.96, 0.99, 1.02, 1.05]


def main():
    folder = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "sounds")
    os.makedirs(folder, exist_ok=True)
    save(os.path.join(folder, "launch.wav"), launch())
    save(os.path.join(folder, "coin.wav"), coin())
    save(os.path.join(folder, "coins_burst.wav"), coins_burst())
    save(os.path.join(folder, "win.wav"), win())
    save(os.path.join(folder, "click.wav"), click())
    save(os.path.join(folder, "fail.wav"), fail())
    for old in os.listdir(folder):
        if old.startswith("pop_") and old.endswith(".wav"):
            os.remove(os.path.join(folder, old))
    for n, scale in enumerate(POP_SCALES):
        save(os.path.join(folder, "pop_%d.wav" % (n + 1)), shot(scale, n))


if __name__ == "__main__":
    main()
