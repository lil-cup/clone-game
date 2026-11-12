#!/usr/bin/env python3
"""Синтезирует звуки игры в sounds/*.wav (только стандартная библиотека).

Запуск:  python3 tools/make_sounds.py
"""
import math
import os
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
    """Стрелок выезжает на ленту: короткий «фьюить» с тоном, идущим вверх."""
    length = 0.16
    out = []
    phase = 0.0
    for i in range(int(RATE * length)):
        t = i / RATE
        k = t / length
        freq = 320 + 900 * k * k
        phase += 2 * math.pi * freq / RATE
        env = min(1.0, t / 0.008) * (1 - k) ** 1.5
        out.append(env * (math.sin(phase) + 0.3 * math.sin(2 * phase)))
    return out


def bubble(base):
    """Блок лопается: мягкий «плоп», как у пузырька — тон коротко взлетает вверх."""
    length = 0.14
    out = []
    phase = 0.0
    for i in range(int(RATE * length)):
        t = i / RATE
        freq = base * (0.75 + 0.6 * (1 - math.exp(-t * 40)))
        phase += 2 * math.pi * freq / RATE
        env = min(1.0, t / 0.002) * math.exp(-t * 32)
        out.append(env * (math.sin(phase) + 0.15 * math.sin(2 * phase)))
    return out


# Ноты пентатоники (до, ре, ми, соль): любые подряд звучат благозвучно.
POP_NOTES = [523.3, 587.3, 659.3, 784.0]


def main():
    folder = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "sounds")
    os.makedirs(folder, exist_ok=True)
    save(os.path.join(folder, "launch.wav"), launch())
    for n, note in enumerate(POP_NOTES):
        save(os.path.join(folder, "pop_%d.wav" % (n + 1)), bubble(note))


if __name__ == "__main__":
    main()
