#!/usr/bin/env python3
"""Synthesizes the combat sound effects (original, no samples). Run: python3 tools/assets/make_sfx.py"""
import os, wave
import numpy as np
from scipy import signal

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio", "sfx")
rng = np.random.default_rng(7)

def env(n, attack, decay):
    t = np.arange(n) / SR
    return np.minimum(t / max(attack, 1e-4), 1.0) * np.exp(-t / decay)

def noise(n): return rng.standard_normal(n)

def band(x, lo, hi):
    sos = signal.butter(2, [lo, hi], btype="band", fs=SR, output="sos")
    return signal.sosfilt(sos, x)

def low(x, hz):
    return signal.sosfilt(signal.butter(2, hz, fs=SR, output="sos"), x)

def tone(n, f0, f1=None):
    f = np.linspace(f0, f1 if f1 else f0, n)
    return np.sin(2 * np.pi * np.cumsum(f) / SR)

def save(name, x):
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.89
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())

def swing(dur, lo, hi):
    n = int(SR * dur); t = np.linspace(0, 1, n)
    centre = lo + (hi - lo) * np.sin(np.pi * t) ** 2
    x = noise(n); out = np.zeros(n); step = 512
    for i in range(0, n, step):
        c = centre[i]
        out[i:i+step] = band(x, c * 0.7, c * 1.4)[i:i+step]
    return out * np.sin(np.pi * t) ** 1.5

def thud(dur, f0, f1, grit):
    n = int(SR * dur)
    return tone(n, f0, f1) * env(n, 0.002, dur / 4) + low(noise(n), 900) * env(n, 0.001, dur / 9) * grit

def clang(dur, freqs):
    n = int(SR * dur); x = np.zeros(n)
    for i, f in enumerate(freqs):
        x += tone(n, f) * env(n, 0.001, dur / (3 + i)) / (i + 1)
    return x + band(noise(n), 2500, 8000) * env(n, 0.0005, 0.02) * 0.8

os.makedirs(OUT, exist_ok=True)
save("swing_light", swing(0.22, 700, 2600))
save("swing_heavy", swing(0.38, 300, 1500))
save("hit_light", thud(0.22, 190, 70, 0.9))
save("hit_heavy", thud(0.4, 130, 40, 1.3) + np.pad(thud(0.2, 300, 90, 0.6), (0, int(SR * 0.2))))
save("hit_armor", clang(0.5, [820, 1370, 2210, 3140]))
save("block", clang(0.3, [420, 690, 1130]) + np.pad(thud(0.2, 160, 60, 0.6), (0, int(SR * 0.1))))
save("parry", clang(0.75, [1480, 2230, 2960, 4450]))
save("hurt", thud(0.3, 240, 90, 1.6))
save("dodge", swing(0.3, 250, 900))
save("guard_break", clang(0.6, [300, 470, 760]) + np.pad(thud(0.4, 110, 35, 1.2), (0, int(SR * 0.2))))
n = int(SR * 0.55)
save("enemy_telegraph", (tone(n, 180, 420) * 0.6 + band(noise(n), 300, 1200)) * np.linspace(0, 1, n) ** 2)
n = int(SR * 0.5)
save("enemy_alert", band(noise(n), 400, 1800) * env(n, 0.05, 0.16) + tone(n, 300, 150) * env(n, 0.02, 0.2) * 0.5)
n = int(SR * 0.7)
save("enemy_death", low(noise(n), 1400) * env(n, 0.01, 0.2) + tone(n, 160, 40) * env(n, 0.01, 0.25))
n = int(SR * 0.35)
save("spit", band(noise(n), 500, 2500) * env(n, 0.03, 0.08) + tone(n, 500, 180) * env(n, 0.01, 0.1) * 0.5)
n = int(SR * 0.5)
save("splat", low(noise(n), 1800) * env(n, 0.001, 0.07) + tone(n, 110, 60) * env(n, 0.002, 0.12))
n = int(SR * 0.6)
glass = sum(tone(n, f) * env(n, 0.0005, 0.03 + 0.05 * rng.random()) * np.roll(np.r_[1, np.zeros(n - 1)], 0).cumsum().clip(0, 1) for f in [2900, 3700, 4600, 5800, 7100])
save("bottle_break", glass * 0.5 + band(noise(n), 3000, 12000) * env(n, 0.0005, 0.08))
n = int(SR * 0.8)
save("heal", tone(n, 440, 880) * env(n, 0.2, 0.3) * 0.5 + band(noise(n), 2000, 6000) * env(n, 0.3, 0.2) * 0.2)
n = int(SR * 0.5)
save("takedown", thud(0.5, 150, 45, 1.4))
n = int(SR * 0.9)
save("death", tone(n, 220, 55) * env(n, 0.01, 0.4) + low(noise(n), 600) * env(n, 0.05, 0.3))
n = int(SR * 0.5)
save("slam", thud(0.5, 90, 28, 1.8))
print("wrote", len(os.listdir(OUT)), "files")
