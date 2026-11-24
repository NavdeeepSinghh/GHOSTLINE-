#!/usr/bin/env python3
"""Synthesizes the adaptive music (original, no samples).

Each area gets four layers of the same length, tempo and key, meant to play
together in sync: `explore` (always on), `tension` (pulse), `combat` (drums
and bass) and `boss` (heavy hits and brass or voices). The game fades layers
in and out (scripts/audio/music_director.gd). The menu has one layer.
Loops are rendered with their reverb tails folded back to the start, so they
repeat without a seam.

Run: python3 tools/assets/make_music.py
"""
import os, wave
import numpy as np
from scipy import signal

SR = 32000
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio", "music")
rng = np.random.default_rng(1234)


def hz(midi): return 440.0 * 2 ** ((midi - 69) / 12.0)
def lp(x, f, order=2): return signal.sosfilt(signal.butter(order, f, fs=SR, output="sos"), x)
def hp(x, f, order=2): return signal.sosfilt(signal.butter(order, f, btype="high", fs=SR, output="sos"), x)
def bp(x, lo, hi): return signal.sosfilt(signal.butter(2, [lo, hi], btype="band", fs=SR, output="sos"), x)
def t_of(n): return np.arange(n) / SR


def saw(f, n, phase=0.0):
    p = (np.arange(n) * f / SR + phase) % 1.0
    return 2.0 * p - 1.0


def adsr(n, a, d, s, r):
    e = np.ones(n) * s
    na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
    na = min(na, n); e[:na] = np.linspace(0, 1, na) if na else e[:na]
    nd = min(nd, n - na); e[na:na + nd] = np.linspace(1, s, nd) if nd else e[na:na + nd]
    if nr and nr < n:
        e[-nr:] *= np.linspace(1, 0, nr)
    return e


class Track:
    """A loop buffer. Notes that run past the end wrap around to the start."""
    def __init__(self, bpm, bars, beats=4):
        self.beat = 60.0 / bpm
        self.length = int(round(self.beat * beats * bars * SR))
        self.buf = np.zeros(self.length)

    def at(self, beat): return int(round(beat * self.beat * SR))

    def add(self, start_beat, x, gain=1.0):
        i = self.at(start_beat) % self.length
        while len(x):
            take = min(len(x), self.length - i)
            self.buf[i:i + take] += x[:take] * gain
            x = x[take:]
            i = 0


# --- Instruments ----------------------------------------------------------
def pad(notes, seconds, cutoff=900, detune=0.006, attack=1.5, release=1.8):
    n = int(seconds * SR)
    x = np.zeros(n)
    for m in notes:
        for d in (-detune, 0.0, detune):
            x += saw(hz(m) * (1 + d), n, rng.random())
    x = lp(x, cutoff, 4)
    return x * adsr(n, attack, 0.5, 0.9, release) / (len(notes) * 3)


def pluck(m, seconds=1.2, bright=2500, decay=0.35):
    n = int(seconds * SR)
    x = saw(hz(m), n) + 0.5 * saw(hz(m) * 2.003, n)
    env = np.exp(-t_of(n) / decay)
    return lp(x, bright, 2) * env * adsr(n, 0.003, 0, 1, 0.05)


def bell(m, seconds=3.0, index=2.5, ratio=3.5, decay=1.1):
    n = int(seconds * SR)
    t = t_of(n)
    f = hz(m)
    mod = index * np.exp(-t / (decay * 0.5)) * np.sin(2 * np.pi * f * ratio * t)
    return np.sin(2 * np.pi * f * t + mod) * np.exp(-t / decay) * adsr(n, 0.002, 0, 1, 0.1)


def flute(m, seconds, vibrato=5.0):
    n = int(seconds * SR)
    t = t_of(n)
    f = hz(m) * (1 + 0.004 * np.sin(2 * np.pi * vibrato * t) * np.minimum(t / 0.6, 1))
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = np.sin(ph) + 0.18 * np.sin(2 * ph) + 0.05 * np.sin(3 * ph)
    breath = bp(rng.standard_normal(n), hz(m) * 0.8, hz(m) * 2.5) * 0.08
    return (x + breath) * adsr(n, 0.25, 0.2, 0.8, 0.6)


def bass(m, seconds, cutoff=500):
    n = int(seconds * SR)
    x = saw(hz(m), n) + 0.6 * np.sin(2 * np.pi * hz(m) / 2 * t_of(n))
    return lp(x, cutoff, 2) * adsr(n, 0.005, 0.15, 0.6, 0.06)


def brass(notes, seconds):
    n = int(seconds * SR)
    x = np.zeros(n)
    for m in notes:
        x += saw(hz(m), n) + saw(hz(m) * 1.004, n)
    sweep = 400 + 1800 * np.exp(-t_of(n) / 0.25)
    # Time-varying lowpass by blocks.
    out = np.zeros(n)
    block = 512
    zi = None
    for i in range(0, n, block):
        sos = signal.butter(2, min(sweep[i], SR / 2 - 100), fs=SR, output="sos")
        if zi is None:
            zi = np.zeros((sos.shape[0], 2))
        out[i:i + block], zi = signal.sosfilt(sos, x[i:i + block], zi=zi)
    return out * adsr(n, 0.04, 0.3, 0.6, 0.3) / (2 * len(notes))


def voices(notes, seconds, vowel=(700, 1220, 2600)):
    """A wordless choir: detuned saws through vowel formants."""
    n = int(seconds * SR)
    x = np.zeros(n)
    t = t_of(n)
    for m in notes:
        for d in (-0.004, 0.0, 0.005):
            f = hz(m) * (1 + d) * (1 + 0.003 * np.sin(2 * np.pi * (4.5 + d * 100) * t))
            x += 2.0 * ((np.cumsum(f) / SR + rng.random()) % 1.0) - 1.0
    y = sum(bp(x, f * 0.9, f * 1.1) * g for f, g in zip(vowel, (1.0, 0.6, 0.25)))
    return y * adsr(n, 0.8, 0.4, 0.85, 1.0) / (3 * len(notes))


def kick(level=1.0):
    n = int(0.5 * SR)
    t = t_of(n)
    f = 45 + 80 * np.exp(-t / 0.04)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.18)
    click = hp(rng.standard_normal(n), 2000) * np.exp(-t / 0.004) * 0.3
    return (x + click) * level


def snare(level=1.0, tone_hz=185):
    n = int(0.35 * SR)
    t = t_of(n)
    body = np.sin(2 * np.pi * tone_hz * t) * np.exp(-t / 0.06)
    rattle = bp(rng.standard_normal(n), 1500, 7000) * np.exp(-t / 0.11)
    return (0.6 * body + rattle) * level


def hat(level=1.0, open_=False):
    n = int((0.3 if open_ else 0.08) * SR)
    x = hp(rng.standard_normal(n), 7000) * np.exp(-t_of(n) / (0.12 if open_ else 0.025))
    return x * level


def shaker(level=1.0):
    n = int(0.06 * SR)
    return bp(rng.standard_normal(n), 2000, 5000) * np.exp(-t_of(n) / 0.02) * level


def taiko(level=1.0, pitch=70):
    n = int(1.2 * SR)
    t = t_of(n)
    f = pitch * (1 + 0.6 * np.exp(-t / 0.05))
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.4)
    slap = lp(rng.standard_normal(n), 900) * np.exp(-t / 0.03) * 0.6
    return (x + slap) * level


def metal_hit(level=1.0):
    n = int(1.0 * SR)
    t = t_of(n)
    x = sum(np.sin(2 * np.pi * f * t) for f in (311, 467, 829, 1373, 2011)) / 5
    noise = bp(rng.standard_normal(n), 2000, 6000) * np.exp(-t / 0.05)
    return (x * np.exp(-t / 0.35) + noise) * level


def reverb(x, seconds=2.2, wet=0.35, bright=3500):
    n = int(seconds * SR)
    ir = rng.standard_normal(n) * np.exp(-t_of(n) / (seconds / 5))
    ir = lp(ir, bright)
    ir /= np.sqrt(np.sum(ir ** 2))
    # Circular so the tail wraps into the loop start.
    wet_sig = np.real(np.fft.ifft(np.fft.fft(x) * np.fft.fft(ir, len(x)))) if n <= len(x) else x
    return x * (1 - wet) + wet_sig * wet * 1.5


def delay(x, beats, beat_seconds, feedback=0.35, mix=0.3):
    d = int(beats * beat_seconds * SR)
    out = x.copy()
    tap = x.copy()
    for _ in range(5):
        tap = np.roll(tap, d) * feedback
        out += tap * mix / feedback
    return out


def save(name, x, rms=0.12):
    os.makedirs(OUT, exist_ok=True)
    x = x - np.mean(x)
    level = np.sqrt(np.mean(x ** 2)) + 1e-9
    x = x * (rms / level)
    peak = np.max(np.abs(x))
    if peak > 0.95:
        x = np.tanh(x / peak * 1.4) / np.tanh(1.4) * 0.95
    # Tiny fade at the seam guards against a click if the wrap is imperfect.
    f = int(0.004 * SR)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())
    print(f"{name}: {len(x) / SR:.1f} s")


# --- Pieces -----------------------------------------------------------------
def area(name, bpm, root, progression, scale, style):
    """progression: list of (chord intervals from root) per 2 bars; 8 bars total."""
    bars = 8
    explore, tension, combat, boss = (Track(bpm, bars) for _ in range(4))
    b = explore.beat
    # Explore: a slow pad over the progression, plus a sparse lead.
    for i, chord in enumerate(progression):
        notes = [root + c for c in chord]
        explore.add(i * 8, pad(notes, 8 * b + 1.5, cutoff=style["pad_cutoff"], attack=style["attack"]))
        explore.add(i * 8, pad([root - 12 + chord[0]], 8 * b + 1.5, cutoff=300), 0.7)
    lead_rng = np.random.default_rng(len(name) * 7)
    for i in range(6):
        beat = int(lead_rng.integers(0, 30)) + 0.5 * int(lead_rng.integers(0, 2))
        m = root + 12 + scale[int(lead_rng.integers(0, len(scale)))]
        if style["lead"] == "bell":
            explore.add(beat, bell(m, 3.5), 0.35)
        elif style["lead"] == "flute":
            explore.add(beat, flute(m, 2.5 * b + 0.5), 0.3)
        else:
            explore.add(beat, bell(m + 12, 4.0, index=1.2, ratio=2.0, decay=1.6), 0.28)
    # Tension: an arpeggiated pulse in eighths, through a dotted delay.
    for i, chord in enumerate(progression):
        notes = [root + 12 + c for c in chord] + [root + 24 + chord[0]]
        for k in range(16):
            m = notes[[0, 1, 2, 3, 2, 1, 0, 2][k % 8]]
            if style["pulse"] == "tick":
                tension.add(i * 8 + k * 0.5, bell(m + 12, 0.4, index=0.8, ratio=1.0, decay=0.08), 0.6)
            else:
                tension.add(i * 8 + k * 0.5, pluck(m, 0.5, bright=style["pluck_bright"], decay=0.12), 0.5)
    tension.buf = delay(tension.buf, 0.75, b, 0.4, 0.35)
    for i in range(0, 32, 2):
        tension.add(i, pad([root - 12], 2 * b, cutoff=200, attack=0.4, release=0.3), 0.5)
    # Combat: drums and a driving bass.
    for bar in range(bars):
        s = bar * 4
        if style["drums"] == "tribal":
            for k in (0, 1.5, 2.0, 3.0, 3.5):
                combat.add(s + k, taiko(0.9 if k in (0, 2.0) else 0.5, pitch=80 if k in (0, 2.0) else 120))
            for k in range(8):
                combat.add(s + k * 0.5, shaker(0.5 if k % 2 else 0.8))
        else:
            for k in (0, 1.5, 2.5):
                combat.add(s + k, kick(1.0))
            for k in (1, 3):
                combat.add(s + k, snare(0.8, 160 if style["drums"] == "industrial" else 190))
            for k in range(8):
                combat.add(s + k * 0.5, hat(0.35 if k % 2 else 0.2, open_=(k == 7)))
            if style["drums"] == "industrial" and bar % 2 == 1:
                combat.add(s + 3.75, metal_hit(0.45))
        chord = progression[bar // 2]
        for k in range(8):
            m = root - 12 + chord[0] + (12 if k in (3, 7) else 0)
            combat.add(s + k * 0.5, bass(m, 0.45 * b, cutoff=style["bass_cutoff"]), 0.8)
    # Boss: big hits on the downbeats and a held brass or choir line.
    for bar in range(bars):
        s = bar * 4
        boss.add(s, taiko(1.2, pitch=55))
        if bar % 2 == 1:
            boss.add(s + 2.5, taiko(0.9, pitch=65))
            boss.add(s + 3.0, taiko(0.9, pitch=65))
    for i, chord in enumerate(progression):
        notes = [root + c for c in chord]
        if style["boss"] == "voices":
            boss.add(i * 8, voices([n + 12 for n in notes[:2]], 8 * b + 1.0), 1.0)
        else:
            for k in (0, 3, 6):
                boss.add(i * 8 + k, brass(notes, 1.5 * b), 0.9)
    # Shared space so the layers sit together.
    explore.buf = reverb(explore.buf, 3.0, 0.45)
    tension.buf = reverb(tension.buf, 2.0, 0.3)
    combat.buf = reverb(combat.buf, 1.2, 0.15)
    boss.buf = reverb(boss.buf, 2.5, 0.3)
    save(f"{name}_explore", explore.buf, 0.11)
    save(f"{name}_tension", tension.buf, 0.07)
    save(f"{name}_combat", combat.buf, 0.10)
    save(f"{name}_boss", boss.buf, 0.10)


def menu():
    track = Track(60, 8)
    root = 50  # D
    prog = [[0, 3, 7, 10], [-4, 0, 3, 7], [-2, 2, 5, 9], [-5, 0, 2, 7]]
    for i, chord in enumerate(prog):
        track.add(i * 8, pad([root + c for c in chord], 8 + 2.0, cutoff=700, attack=2.5, release=2.5))
    # The Echo motif: a falling figure answered by its echo.
    motif = [(0, 74), (1, 72), (1.5, 69), (3, 67)]
    for rep in range(4):
        for beat, m in motif:
            track.add(rep * 8 + beat, bell(m, 4.0, index=1.5, ratio=2.0, decay=1.8), 0.4)
            track.add(rep * 8 + beat + 4, bell(m - 12, 4.0, index=0.8, ratio=2.0, decay=1.8), 0.2)
    track.buf = reverb(track.buf, 4.0, 0.55)
    save("menu_explore", track.buf, 0.1)


if __name__ == "__main__":
    D, A, Cs = 50, 45, 49
    # Dead City: D minor, 80 bpm, rain-grey synths.
    area("dead_city", 80, D, [[0, 3, 7], [-4, 0, 3], [-7, -4, 0], [-5, -1, 2]], [0, 2, 3, 5, 7, 8, 10],
         {"pad_cutoff": 800, "attack": 1.5, "lead": "bell", "pulse": "pluck", "pluck_bright": 1800,
          "drums": "kit", "bass_cutoff": 450, "boss": "brass"})
    # Forest: A dorian, 72 bpm, wood and breath.
    area("forest", 72, A, [[0, 3, 7], [5, 9, 12], [3, 7, 10], [2, 5, 9]], [0, 2, 3, 5, 7, 9, 10],
         {"pad_cutoff": 1100, "attack": 2.0, "lead": "flute", "pulse": "pluck", "pluck_bright": 3200,
          "drums": "tribal", "bass_cutoff": 380, "boss": "brass"})
    # Facility: C# minor, 90 bpm, cold and mechanical; the Choir sings.
    area("facility", 90, Cs, [[0, 3, 7], [1, 5, 8], [-4, 0, 3], [-2, 2, 5]], [0, 2, 3, 5, 7, 8, 11],
         {"pad_cutoff": 650, "attack": 1.0, "lead": "glass", "pulse": "tick", "pluck_bright": 2500,
          "drums": "industrial", "bass_cutoff": 520, "boss": "voices"})
    menu()
