"""Trilha de VELA composta em código.

Cada faixa é escrita como dados (acordes, melodia, forma) e renderizada com os
instrumentos de synth.py. As faixas fecham em loop sem emenda: a cauda do
reverb do fim é somada ao começo.

Temas (todos originais):
  titulo  — a chama sozinha no escuro (Ré menor, tigela + piano esparso)
  poco    — Poço do Despertar (Ré menor, i–VI–iv–V, piano, cordas, coro)
  limiar  — o altar do Limiar (Ré dórico, mais quente, esperança contida)
  amb_poco — ambiência: vento na caverna, gotas, ronco grave
"""
from __future__ import annotations

import numpy as np

import synth as S


class Track:
    def __init__(self, bpm: float, bars: int, beats_per_bar: int = 4, tail: float = 8.0):
        self.beat = 60.0 / bpm
        self.bar = self.beat * beats_per_bar
        self.length = self.bar * bars
        n = S.samples(self.length + tail)
        self.dry = np.zeros((2, n))
        self.send = np.zeros((2, n))

    def at(self, bar: float, beat: float = 0.0) -> float:
        return bar * self.bar + beat * self.beat

    def add(self, sound: np.ndarray, time: float, gain: float, pan: float = 0.0, send: float = 0.5) -> None:
        if sound.ndim == 1:
            sound = S.pan(sound, pan)
        S.place(self.dry, sound * gain, time)
        S.place(self.send, sound * gain * send, time)

    def render(self, ir: np.ndarray, wet: float, peak_db: float = -1.5, target_rms_db: float = -21.0) -> np.ndarray:
        wet_part = S.apply_reverb(self.send, ir, wet, dry=0.0)[:, :self.dry.shape[1]]
        mix = self.dry + wet_part
        mix = S.highpass(mix, 32.0, 2)
        # loop sem emenda: dobra a cauda sobre o começo
        n = S.samples(self.length)
        tail = mix[:, n:]
        mix = mix[:, :n].copy()
        m = min(tail.shape[1], n)
        mix[:, :m] += tail[:, :m]
        # nível
        rms = S.rms_db(mix)
        mix *= 10 ** ((target_rms_db - rms) / 20)
        mix = S.soft_clip(mix, 1.15)
        peak = 10 ** (peak_db / 20)
        if np.max(np.abs(mix)) > peak:
            mix = S.normalize(mix, peak)
        return mix


def melody(track: Track, notes, bar0: int, vel_scale: float = 1.0, octave: int = 0, gain: float = 0.55, bright: float = 0.45) -> None:
    for (bar, beat, name, dur_beats, vel) in notes:
        m = S.midi(name) + 12 * octave
        snd = S.piano(m, dur_beats * track.beat, vel=vel * vel_scale, bright=bright)
        track.add(snd, track.at(bar0 + bar, beat), gain, pan=0.08, send=0.55)


# ---------------------------------------------------------------------------
# Poço do Despertar
# ---------------------------------------------------------------------------

POCO_THEME = [
    # (compasso, tempo, nota, duração em tempos, intensidade)
    (0, 0, "A4", 2, 0.58), (0, 2, "F4", 1, 0.44), (0, 3, "E4", 1, 0.44),
    (1, 0, "D4", 3, 0.52), (1, 3.5, "A3", 0.5, 0.34),
    (2, 0, "D4", 1, 0.48), (2, 1, "F4", 1, 0.48), (2, 2, "A4", 2, 0.58),
    (3, 0, "G4", 1.5, 0.5), (3, 1.5, "F4", 0.5, 0.4), (3, 2, "D4", 2, 0.44),
    (4, 0, "Bb4", 2, 0.6), (4, 2, "A4", 1, 0.5), (4, 3, "G4", 1, 0.47),
    (5, 0, "D4", 2, 0.5), (5, 2, "G4", 1, 0.4), (5, 3, "A4", 1, 0.42),
    (6, 0, "E4", 1, 0.5), (6, 1, "A4", 1, 0.52), (6, 2, "D5", 2, 0.6),
    (7, 0, "C#5", 3, 0.56), (7, 3, "E4", 1, 0.34),
]

# fim alternativo que resolve na tônica
POCO_THEME_RESOLVE = POCO_THEME[:-2] + [(7, 0, "C#5", 2, 0.5), (7, 2, "E5", 1, 0.45), (7, 3, "D5", 1, 0.5)]

POCO_CHORDS_A = [  # (compasso, duração em compassos, vozes, baixo)
    (0, 2, ["D3", "A3", "E4", "F4"], "D2"),
    (2, 2, ["Bb2", "F3", "C4", "D4"], "Bb1"),
    (4, 2, ["G2", "D3", "A3", "Bb3"], "G1"),
    (6, 1, ["A2", "E3", "A3", "D4"], "A1"),
    (7, 1, ["A2", "E3", "A3", "C#4"], "A1"),
]

POCO_CHORDS_B = [
    (0, 1, ["Bb2", "F3", "A3", "D4"], "Bb1"),
    (1, 1, ["A2", "F3", "C4", "F4"], "A1"),
    (2, 1, ["G2", "F3", "Bb3", "D4"], "G1"),
    (3, 1, ["C3", "G3", "C4", "E4"], "C2"),
    (4, 1, ["Bb2", "F3", "A3", "D4"], "Bb1"),
    (5, 1, ["A2", "F3", "C4", "F4"], "A1"),
    (6, 1, ["G2", "F3", "Bb3", "D4"], "G1"),
    (7, 1, ["A2", "E3", "A3", "C#4"], "A1"),
]

SPARKLE_SCALE = ["D5", "F5", "G5", "A5", "C6", "D6"]


def pads(track: Track, chords, bar0: int, gain: float, bright: float, choir_gain: float = 0.0, vowel: str = "o") -> None:
    for (bar, bars, voices, bass) in chords:
        dur = bars * track.bar
        t = track.at(bar0 + bar)
        track.add(S.strings_pad(voices, dur, attack=min(1.6, dur * 0.4), release=2.6, bright=bright), t, gain, send=0.65)
        track.add(S.piano(bass, min(dur, 3.0), vel=0.42, bright=0.25), t, 0.42, pan=-0.15, send=0.5)
        if choir_gain > 0:
            track.add(S.choir(voices[-2:], dur, vowel=vowel, attack=min(2.0, dur * 0.5)), t, choir_gain, send=0.8)


def arpeggio(track: Track, chords, bar0: int, gain: float, rng: np.random.Generator) -> None:
    for (bar, bars, voices, bass) in chords:
        tones = [S.midi(v) for v in voices] + [S.midi(voices[1]) + 12, S.midi(voices[2]) + 12]
        pattern = [0, 1, 2, 3, 4, 3, 2, 1]
        for b in range(bars):
            for i, idx in enumerate(pattern):
                vel = 0.26 + 0.06 * (i == 0) + rng.uniform(-0.03, 0.03)
                t = track.at(bar0 + bar + b, i * 0.5)
                track.add(S.piano(tones[idx], 0.9 * track.beat, vel=vel, bright=0.3), t, gain, pan=-0.25 + 0.5 * (i / 7), send=0.6)


def sparkles(track: Track, bar0: int, bars: int, prob: float, rng: np.random.Generator, gain: float = 0.16) -> None:
    for b in range(bars):
        for beat in range(4):
            if rng.random() < prob:
                note = SPARKLE_SCALE[rng.integers(len(SPARKLE_SCALE))]
                track.add(S.glass_bell(note, 2.4, 0.35 + rng.uniform(0, 0.2)), track.at(bar0 + b, beat + rng.choice([0, 0.5])), gain, pan=rng.uniform(-0.7, 0.7), send=0.8)


def compose_poco() -> np.ndarray:
    rng = np.random.default_rng(11)
    tr = Track(bpm=64, bars=40)
    # I — só o poço respirando
    tr.add(S.singing_bowl("D3", 10.0, 0.7), 0.0, 0.5, send=0.7)
    tr.add(S.drone("D2", tr.bar * 8 + 4), 0.0, 0.5, send=0.4)
    pads(tr, POCO_CHORDS_A, 0, gain=0.3, bright=0.2)
    sparkles(tr, 4, 4, 0.12, rng)
    # A — o tema
    pads(tr, POCO_CHORDS_A, 8, gain=0.32, bright=0.3)
    melody(tr, POCO_THEME, 8)
    # A' — o tema sobe uma oitava, cordas e coro entram
    pads(tr, POCO_CHORDS_A, 16, gain=0.36, bright=0.45, choir_gain=0.16)
    melody(tr, POCO_THEME[:13], 16, octave=1, vel_scale=0.9, gain=0.45, bright=0.5)
    melody(tr, POCO_THEME[13:], 16, vel_scale=1.0)
    sparkles(tr, 16, 8, 0.14, rng)
    # B — clareira em Si bemol, arpejos
    pads(tr, POCO_CHORDS_B, 24, gain=0.3, bright=0.4, choir_gain=0.12, vowel="a")
    arpeggio(tr, POCO_CHORDS_B, 24, gain=0.3, rng=rng)
    melody(tr, [(1, 0, "C5", 2, 0.48), (1, 2, "A4", 2, 0.42), (3, 0, "E5", 2, 0.5), (3, 2, "D5", 1, 0.44), (3, 3, "C5", 1, 0.42),
                (5, 0, "F5", 2, 0.5), (5, 2, "E5", 1, 0.45), (5, 3, "C5", 1, 0.42), (7, 0, "C#5", 4, 0.48)], 24, gain=0.48)
    sparkles(tr, 24, 8, 0.1, rng)
    # A'' — volta ao silêncio
    tr.add(S.singing_bowl("A2", 10.0, 0.55), tr.at(32), 0.45, send=0.7)
    tr.add(S.drone("D2", tr.bar * 8 + 4), tr.at(32), 0.45, send=0.4)
    pads(tr, POCO_CHORDS_A, 32, gain=0.28, bright=0.22)
    melody(tr, POCO_THEME_RESOLVE[:7], 32, vel_scale=0.85)
    ir = S.reverb_ir(4.2, 0.035, bright=0.45)
    return tr.render(ir, wet=0.9)


# ---------------------------------------------------------------------------
# Título
# ---------------------------------------------------------------------------

TITLE_MOTIF = [
    (0, 0, "A4", 2, 0.5), (0, 2, "D5", 1, 0.46), (0, 3, "C5", 1, 0.42),
    (1, 0, "A4", 4, 0.48),
    (2, 0, "F4", 2, 0.44), (2, 2, "G4", 1, 0.4), (2, 3, "A4", 1, 0.42),
    (3, 0, "E4", 4, 0.44),
    (5, 0, "D5", 2, 0.5), (5, 2, "E5", 1, 0.45), (5, 3, "F5", 1, 0.47),
    (6, 0, "E5", 2, 0.46), (6, 2, "C5", 2, 0.42),
    (7, 0, "A4", 4, 0.45),
]


def compose_title() -> np.ndarray:
    rng = np.random.default_rng(5)
    tr = Track(bpm=60, bars=16)
    chords = [
        (0, 4, ["D3", "A3", "E4", "F4"], "D2"),
        (4, 2, ["Bb2", "F3", "A3", "E4"], "Bb1"),
        (6, 2, ["A2", "E3", "A3", "D4"], "A1"),
        (8, 4, ["G2", "D3", "A3", "Bb3"], "G1"),
        (12, 2, ["Bb2", "F3", "A3", "D4"], "Bb1"),
        (14, 2, ["A2", "E3", "A3", "C#4"], "A1"),
    ]
    for (bar, bars, voices, bass) in chords:
        dur = bars * tr.bar
        tr.add(S.strings_pad(voices, dur, attack=2.5, release=3.0, bright=0.22), tr.at(bar), 0.3, send=0.7)
        tr.add(S.choir(voices[1:3], dur, vowel="u", attack=3.0), tr.at(bar), 0.1, send=0.9)
    tr.add(S.singing_bowl("D3", 12.0, 0.75), 0.0, 0.55, send=0.7)
    tr.add(S.singing_bowl("A2", 12.0, 0.6), tr.at(8), 0.5, send=0.7)
    tr.add(S.drone("D2", tr.length + 4), 0.0, 0.35, send=0.4)
    melody(tr, TITLE_MOTIF, 0, gain=0.5, bright=0.4)
    melody(tr, TITLE_MOTIF[:7], 8, octave=1, vel_scale=0.8, gain=0.38, bright=0.45)
    sparkles(tr, 8, 8, 0.08, rng, gain=0.12)
    return tr.render(S.reverb_ir(4.5, 0.04, 0.4), wet=1.0, target_rms_db=-22.0)


# ---------------------------------------------------------------------------
# Limiar
# ---------------------------------------------------------------------------

def compose_limiar() -> np.ndarray:
    rng = np.random.default_rng(23)
    tr = Track(bpm=58, bars=16)
    chords = [
        (0, 2, ["D3", "A3", "C4", "E4", "F4"], "D2"),
        (2, 2, ["D3", "G3", "B3", "D4"], "D2"),
        (4, 2, ["F3", "A3", "C4", "E4"], "F2"),
        (6, 2, ["E3", "G3", "C4", "E4"], "C2"),
        (8, 2, ["D3", "A3", "C4", "E4", "F4"], "D2"),
        (10, 2, ["D3", "G3", "B3", "D4"], "D2"),
        (12, 2, ["Bb2", "F3", "A3", "E4"], "Bb1"),
        (14, 1, ["A2", "E3", "A3", "D4"], "A1"),
        (15, 1, ["A2", "E3", "A3", "C#4"], "A1"),
    ]
    pads(tr, chords, 0, gain=0.3, bright=0.42, choir_gain=0.1, vowel="a")
    arpeggio(tr, chords[:8], 0, gain=0.24, rng=rng)
    tune = [
        (1, 0, "F5", 1, 0.46), (1, 1, "E5", 1, 0.44), (1, 2, "D5", 1, 0.44), (1, 3, "A4", 1, 0.4),
        (2, 0, "B4", 4, 0.48),
        (5, 0, "C5", 1, 0.44), (5, 1, "D5", 1, 0.45), (5, 2, "E5", 1, 0.47), (5, 3, "G5", 1, 0.5),
        (6, 0, "E5", 4, 0.48),
        (9, 0, "F5", 1, 0.46), (9, 1, "E5", 1, 0.44), (9, 2, "D5", 1, 0.44), (9, 3, "A4", 1, 0.4),
        (10, 0, "B4", 2, 0.46), (10, 2, "D5", 2, 0.48),
        (13, 0, "A5", 2, 0.5), (13, 2, "G5", 1, 0.46), (13, 3, "E5", 1, 0.44),
        (14, 0, "D5", 2, 0.46), (15, 0, "C#5", 4, 0.44),
    ]
    melody(tr, tune, 0, gain=0.48, bright=0.5)
    tr.add(S.singing_bowl("D3", 12.0, 0.6), 0.0, 0.45, send=0.7)
    tr.add(S.temple_bell("D3", 7.0, 0.5), tr.at(8), 0.35, send=0.7)
    sparkles(tr, 0, 16, 0.08, rng, gain=0.12)
    return tr.render(S.reverb_ir(3.8, 0.03, 0.55), wet=0.85, target_rms_db=-21.5)


# ---------------------------------------------------------------------------
# Ambiência do Poço
# ---------------------------------------------------------------------------

def compose_ambience(seconds: float = 48.0) -> np.ndarray:
    rng = np.random.default_rng(3)
    tail = 6.0
    n = S.samples(seconds + tail)
    t = S.tvec(n)
    wind = np.zeros((2, n))
    for ch in range(2):
        base = S.pink(n)
        lo = S.bandpass(base, 180, 520)
        hi = S.bandpass(base, 600, 1500)
        mod = 0.55 + 0.45 * np.sin(2 * np.pi * (0.045 + 0.01 * ch) * t + ch * 1.7) * np.sin(2 * np.pi * 0.11 * t + ch)
        gust = 0.5 + 0.5 * np.sin(2 * np.pi * 0.023 * t + 0.6 + ch)
        wind[ch] = (lo * mod * 0.5 + hi * mod * gust * 0.12)
    rumble = S.lowpass(S.brown(n), 70) * 0.8
    wind += np.vstack([rumble, rumble])
    drips = np.zeros((2, n))
    time = 1.2
    while time < seconds:
        f = rng.uniform(1300, 2500)
        dn = S.samples(0.14)
        dt = S.tvec(dn)
        freq = f * (1 + 0.6 * np.exp(-dt / 0.012))
        ping = np.sin(2 * np.pi * np.cumsum(freq) / S.SR) * np.exp(-dt / 0.035)
        ping2 = np.sin(2 * np.pi * f * 1.48 * dt) * np.exp(-dt / 0.018) * 0.4
        S.place(drips, S.pan((ping + ping2) * rng.uniform(0.08, 0.2), rng.uniform(-0.8, 0.8)), time)
        time += rng.uniform(1.8, 6.5)
    ir = S.reverb_ir(3.2, 0.02, 0.6)
    mix = wind * 0.9 + S.apply_reverb(drips, ir, wet=1.2, dry=0.4)[:, :n]
    loop = S.samples(seconds)
    out = mix[:, :loop].copy()
    m = n - loop
    # cruzamento suave no ponto do loop
    fade = np.linspace(0, 1, m)
    out[:, :m] = out[:, :m] * fade + mix[:, loop:loop + m] * (1 - fade)
    out *= 10 ** ((-27.0 - S.rms_db(out)) / 20)
    return S.normalize(out, 0.7) if np.max(np.abs(out)) > 0.7 else out
