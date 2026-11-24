#!/usr/bin/env python3
"""Synthesizes the Dead City's world audio (original, no samples): ambience loops,
footsteps per surface, interaction sounds, radio static and the Echo motif.
Run: python3 tools/assets/make_world_audio.py"""
import os, wave
import numpy as np
from scipy import signal

SR = 44100
ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio")
rng = np.random.default_rng(97)


def noise(n): return rng.standard_normal(n)
def sos(x, *args, **kw): return signal.sosfilt(signal.butter(2, *args, fs=SR, output="sos", **kw), x)
def band(x, lo, hi): return sos(x, [lo, hi], btype="band")
def low(x, hz): return sos(x, hz)
def high(x, hz): return sos(x, hz, btype="high")
def env(n, attack, decay):
    t = np.arange(n) / SR
    return np.minimum(t / max(attack, 1e-4), 1.0) * np.exp(-t / decay)
def tone(n, f0, f1=None):
    f = np.linspace(f0, f1 if f1 else f0, n)
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def save(folder, name, x, peak=0.89, stereo=False):
    os.makedirs(os.path.join(ROOT, folder), exist_ok=True)
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    with wave.open(os.path.join(ROOT, folder, name + ".wav"), "wb") as w:
        w.setnchannels(2 if stereo else 1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


def loopable(x, fade=0.5):
    """Crossfades the tail into the head so the clip loops without a click."""
    f = int(SR * fade)
    ramp = np.linspace(0, 1, f)
    head = x[:f] * ramp + x[-f:] * (1 - ramp)
    return np.concatenate([head, x[f:-f]])


def slow(n, hz, depth):
    """A slow random wobble around 1.0."""
    return 1.0 + depth * low(noise(n), hz) / (np.std(low(noise(n), hz)) + 1e-9) * 0.5


# --- Ambience loops ---------------------------------------------------------
def rain(seconds, bright):
    n = int(SR * seconds)
    hiss = band(noise(n), 1500, 9000 if bright else 2500) * slow(n, 0.4, 0.25)
    body = band(noise(n), 300, 1400) * 0.6
    drops = np.zeros(n)
    for _ in range(int(seconds * (260 if bright else 60))):
        i = rng.integers(0, n - 600)
        d = 200 + rng.integers(0, 380)
        drops[i:i + d] += band(noise(d), 2000, 7000) * env(d, 0.0005, 0.003) * rng.uniform(0.3, 1.0)
    out = hiss + body + drops * (2.2 if bright else 1.0)
    if not bright:
        out = low(out, 1800) + low(noise(n), 160) * 0.5
    return loopable(out)

save("ambience", "rain_loop", rain(12.0, True), 0.6)
save("ambience", "rain_interior_loop", rain(12.0, False), 0.5)

n = int(SR * 14.0)
wind = band(noise(n), 120, 700) * slow(n, 0.15, 0.9) + band(noise(n), 700, 1600) * slow(n, 0.25, 0.9) * 0.25
save("ambience", "wind_loop", loopable(wind, 1.0), 0.5)

n = int(SR * 16.0)
drone = sum(tone(n, f) * slow(n, 0.1, 0.5) / (i + 1) for i, f in enumerate([41.2, 61.9, 82.6, 123.9]))
drone = drone + low(noise(n), 90) * 1.5 + band(noise(n), 2200, 2600) * slow(n, 0.08, 1.0) * 0.02
save("ambience", "city_drone_loop", loopable(drone, 1.5), 0.55)

n = int(SR * 12.0)
drip = low(noise(n), 110) * 0.8 + tone(n, 55) * 0.3
for _ in range(16):
    i = rng.integers(0, n - 9000); d = 8000
    drip[i:i + d] += tone(d, rng.uniform(900, 1700), 500) * env(d, 0.001, 0.03) * 1.6
    drip[i + 900:i + d] += tone(d - 900, rng.uniform(700, 1200), 400) * env(d - 900, 0.001, 0.05) * 0.5
save("ambience", "tunnel_loop", loopable(drip, 1.0), 0.5)

n = int(SR * 4.0)
buzz = (signal.sawtooth(2 * np.pi * 100 * np.arange(n) / SR) * 0.3 + band(noise(n), 3000, 6000) * 0.25) * slow(n, 6.0, 0.5)
save("ambience", "neon_buzz_loop", loopable(high(buzz, 90), 0.3), 0.4)

n = int(SR * 6.0)
hum = sum(tone(n, 50.0 * k) / k for k in (1, 2, 3, 5)) * slow(n, 0.3, 0.15) + band(noise(n), 400, 900) * 0.12
save("ambience", "generator_loop", loopable(hum, 0.5), 0.5)

for index, (dur, f) in enumerate([(5.5, 70), (7.0, 48)], 1):
    n = int(SR * dur)
    crack = band(noise(n), 60, 2500) * env(n, 0.01, 0.25)
    rumble = low(noise(n), f * 2.2) * env(n, 0.3, dur / 2.6) * slow(n, 1.2, 1.2) * 3.0
    save("sfx", "thunder_%d" % index, crack * 0.7 + rumble, 0.8)

# --- Footsteps ----------------------------------------------------------------
def step(kind):
    if kind == "concrete":
        n = int(SR * 0.16)
        return tone(n, rng.uniform(120, 150), 60) * env(n, 0.002, 0.03) + band(noise(n), 500, 2800) * env(n, 0.001, 0.018) * 0.7
    if kind == "wet":
        n = int(SR * 0.26)
        x = tone(n, rng.uniform(110, 140), 60) * env(n, 0.002, 0.03) * 0.8
        return x + band(noise(n), 1200, 6500) * env(n, 0.012, 0.05) * 0.9 + band(noise(n), 400, 1100) * env(n, 0.002, 0.03) * 0.5
    if kind == "metal":
        n = int(SR * 0.3)
        x = sum(tone(n, f * rng.uniform(0.97, 1.03)) * env(n, 0.001, 0.05 + 0.02 * i) / (i + 1) for i, f in enumerate([310, 742, 1190, 1870]))
        return x + low(noise(n), 300) * env(n, 0.001, 0.02) * 1.2
    if kind == "grass":
        n = int(SR * 0.24)
        return band(noise(n), 1800, 7500) * env(n, 0.02, 0.06) * slow(n, 40, 1.0) + low(noise(n), 200) * env(n, 0.003, 0.03) * 0.8
    n = int(SR * 0.22)  # gravel
    x = np.zeros(n)
    for _ in range(9):
        i = rng.integers(0, n // 2); d = 500 + rng.integers(0, 900)
        x[i:i + d] += band(noise(d), 900, 5200) * env(d, 0.0005, 0.006) * rng.uniform(0.4, 1.0)
    return x + low(noise(n), 260) * env(n, 0.002, 0.03)

for kind in ("concrete", "wet", "metal", "grass", "gravel"):
    for variation in range(1, 4):
        save("sfx", "step_%s_%d" % (kind, variation), step(kind), 0.7)

# --- Interaction ------------------------------------------------------------
n = int(SR * 0.35)
save("sfx", "pickup", tone(n, 660) * env(n, 0.002, 0.08) + np.pad(tone(n - 3500, 990) * env(n - 3500, 0.002, 0.1), (3500, 0)), 0.6)
n = int(SR * 0.4)
save("sfx", "page", band(noise(n), 2500, 9000) * env(n, 0.05, 0.08) * slow(n, 30, 1.2), 0.5)
n = int(SR * 0.18)
save("sfx", "switch", tone(n, 1900, 700) * env(n, 0.0005, 0.008) + low(noise(n), 500) * env(n, 0.001, 0.02) * 1.5, 0.7)
n = int(SR * 0.5)
save("sfx", "fuse_insert", sum(tone(n, f) * env(n, 0.001, 0.07) for f in (540, 1310, 2140)) + low(noise(n), 400) * env(n, 0.001, 0.03) * 2.0
     + np.pad(band(noise(n - 6000), 3000, 9000) * env(n - 6000, 0.002, 0.05), (6000, 0)), 0.7)
n = int(SR * 2.6)
save("sfx", "power_up", (tone(n, 38, 110) + 0.5 * tone(n, 76, 220) + 0.2 * signal.sawtooth(2 * np.pi * np.cumsum(np.linspace(30, 100, n)) / SR))
     * np.minimum(np.arange(n) / (SR * 1.6), 1.0) * np.minimum((n - np.arange(n)) / (SR * 0.5), 1.0), 0.8)
n = int(SR * 1.5)
gate = band(noise(n), 250, 1400) * slow(n, 14, 1.4) * env(n, 0.15, 0.7) + tone(n, 190, 120) * slow(n, 9, 0.9) * env(n, 0.2, 0.5) * 0.5
gate[-8000:] += tone(8000, 140, 60) * env(8000, 0.001, 0.03) * 3.0
save("sfx", "gate_open", gate, 0.75)
n = int(SR * 1.1)
rattle = np.zeros(n)
for k in range(7):
    i = int(k * n / 9); d = 5000
    rattle[i:i + d] += sum(tone(d, f * rng.uniform(0.95, 1.05)) * env(d, 0.001, 0.03) for f in (420, 910, 1630)) * (0.5 + k * 0.1)
save("sfx", "ladder_drop", rattle + np.pad(low(noise(9000), 300) * env(9000, 0.001, 0.05) * 5.0, (n - 9000, 0)), 0.8)
n = int(SR * 0.9)
save("sfx", "core_pickup", sum(tone(n, f) * env(n, 0.01, 0.3) / (i + 1) for i, f in enumerate([392, 587, 784, 1175])), 0.6)
n = int(SR * 0.12)
save("sfx", "ui_tick", tone(n, 1400) * env(n, 0.001, 0.02), 0.4)
n = int(SR * 0.5)
save("sfx", "ui_wrong", tone(n, 150) * env(n, 0.005, 0.15) + tone(n, 159) * env(n, 0.005, 0.15), 0.5)
n = int(SR * 0.7)
save("sfx", "checkpoint", tone(n, 523) * env(n, 0.005, 0.2) + np.pad(tone(n - 5000, 784) * env(n - 5000, 0.005, 0.25), (5000, 0)), 0.45)

# --- Radio and the Echo ---------------------------------------------------------
n = int(SR * 0.45)
save("sfx", "radio_in", band(noise(n), 900, 4200) * env(n, 0.01, 0.12) * slow(n, 50, 1.5) + tone(n, 2100, 1300) * env(n, 0.002, 0.03) * 0.5, 0.5)
n = int(SR * 0.3)
save("sfx", "radio_out", band(noise(n), 900, 4200) * env(n, 0.002, 0.05) + tone(n, 1300) * env(n, 0.002, 0.02) * 0.4, 0.45)
n = int(SR * 8.0)
static = band(noise(n), 700, 5000) * slow(n, 3.0, 1.6) * 0.5 + tone(n, 2740) * slow(n, 0.6, 1.6) * 0.04
save("ambience", "radio_static_loop", loopable(static, 0.5), 0.35)

# Lyra's motif: five falling-then-rising notes, glassy, with a slow shimmer.
notes = [(659.3, 0.0), (587.3, 0.7), (440.0, 1.4), (493.9, 2.3), (659.3, 3.1)]
n = int(SR * 6.5)
motif = np.zeros(n)
for f, at in notes:
    i = int(SR * at); d = n - i
    voice = sum(tone(d, f * h * (1 + 0.002 * k)) / (h * h) for k, h in enumerate((1, 2, 3.01, 4.02)))
    motif[i:] += voice * env(d, 0.06, 1.3) * (1 + 0.25 * np.sin(2 * np.pi * 5.2 * np.arange(d) / SR))
echo = np.zeros(n)
for k, delay in enumerate((0.31, 0.62, 0.93)):
    s = int(SR * delay); echo[s:] += motif[:-s] * 0.45 ** (k + 1)
save("sfx", "echo_motif", motif + echo + band(noise(n), 3000, 7000) * 0.01, 0.6)
n = int(SR * 3.0)
save("sfx", "echo_swell", (tone(n, 55, 58) + tone(n, 110.7) * 0.5 + tone(n, 329.6) * 0.15 + low(noise(n), 200) * 0.6)
     * np.sin(np.pi * np.arange(n) / n) ** 2, 0.8)

# M10: crows taking off, a caw, water dripping in the Facility.
n = int(SR * 1.3)
t = np.arange(n) / SR
flutter = band(noise(n), 300, 2400) * (0.55 + 0.45 * np.sign(np.sin(2 * np.pi * 13.0 * t * (1 - 0.3 * t)))) * env(n, 0.01, 0.45)
save("sfx", "wings_takeoff", flutter + low(noise(n), 160) * env(n, 0.005, 0.08) * 1.5, 0.7)
n = int(SR * 0.9)
caw = np.zeros(n)
for start in (0.0, 0.42):
    i = int(SR * start); d = int(SR * 0.3)
    raw = signal.sawtooth(2 * np.pi * np.cumsum(np.linspace(620, 470, d)) / SR) + band(noise(d), 800, 3000) * 0.6
    caw[i:i + d] += band(raw, 500, 2600) * env(d, 0.01, 0.12)
save("sfx", "crow_caw", caw, 0.6)
for index in (1, 2):
    n = int(SR * 0.5)
    drop = tone(n, 1700 + index * 250, 700) * env(n, 0.0005, 0.03) + tone(n, 420 + index * 60) * env(n, 0.002, 0.09) * 0.4
    save("sfx", "water_drip_%d" % index, drop, 0.45)
print("world audio written")
