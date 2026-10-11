"""Efeitos sonoros de VELA, sintetizados.

Som-assinatura: os anéis do cajado (`ring`). Os outros sons tentam soar
"de pano, cera e pedra" — macios, sem estalos digitais.
"""
from __future__ import annotations

import numpy as np

import synth as S

R = np.random.default_rng(19)


def _env(n: int, attack: float, decay: float) -> np.ndarray:
    t = S.tvec(n)
    return np.clip(t / max(attack, 1e-4), 0, 1) * np.exp(-np.maximum(t - attack, 0) / decay)


def _sine_sweep(f0: float, f1: float, seconds: float, decay: float) -> np.ndarray:
    n = S.samples(seconds)
    t = S.tvec(n)
    f = f0 * (f1 / f0) ** (t / seconds)
    return np.sin(2 * np.pi * np.cumsum(f) / S.SR) * _env(n, 0.004, decay)


def _finish(x: np.ndarray, peak: float = 0.9, fade_out: float = 0.02) -> np.ndarray:
    n = S.samples(fade_out)
    if n > 0 and len(x) > n:
        x[-n:] *= np.linspace(1, 0, n)
    return S.normalize(x, peak)


def jump() -> np.ndarray:
    n = S.samples(0.16)
    whoosh = S.sweep_filter(S.white(n), 700, 2300, q=1.4) * _env(n, 0.01, 0.05)
    puff = _sine_sweep(260, 420, 0.16, 0.04) * 0.25
    return _finish(whoosh + puff, 0.7)


def air_jump() -> np.ndarray:
    n = S.samples(0.5)
    body = _sine_sweep(240, 620, 0.5, 0.09)
    body += 0.4 * _sine_sweep(480, 1240, 0.5, 0.07)
    breath = S.sweep_filter(S.white(n), 900, 3200, q=1.1) * _env(n, 0.005, 0.07) * 0.6
    shimmer = S.glass_bell("A6", 0.5, 0.25)[:n] + S.glass_bell("E7", 0.5, 0.15)[:n]
    return _finish(body * 0.6 + breath + shimmer * 0.5, 0.8)


def land(hard: bool = False) -> np.ndarray:
    seconds = 0.4 if hard else 0.2
    n = S.samples(seconds)
    thump = _sine_sweep(130 if hard else 150, 48, seconds, 0.09 if hard else 0.05)
    dust = S.lowpass(S.white(n), 1400 if hard else 1100) * _env(n, 0.002, 0.04 if hard else 0.025)
    out = thump * (1.0 if hard else 0.7) + dust * 0.5
    if hard:
        crunch = S.bandpass(S.white(n), 1200, 3800) * _env(n, 0.001, 0.02) * 0.35
        out += crunch
    return _finish(out, 0.9 if hard else 0.75)


def step(i: int) -> np.ndarray:
    n = S.samples(0.07)
    tone = [900, 1100, 1300][i % 3]
    tap = S.bandpass(S.white(n), tone * 0.6, tone * 1.6) * _env(n, 0.001, 0.012)
    click = _sine_sweep(tone * 0.25, tone * 0.18, 0.07, 0.01) * 0.3
    return _finish(tap + click, 0.6)


def dash() -> np.ndarray:
    n = S.samples(0.38)
    whoosh = S.sweep_filter(S.white(n), 3200, 600, q=1.3) * _env(n, 0.012, 0.11)
    swell = _sine_sweep(110, 70, 0.38, 0.12) * 0.45
    crackle = np.zeros(n)
    for k in range(18):
        i = R.integers(0, n - 200)
        crackle[i:i + 160] += S.bandpass(S.white(160), 2500, 7000) * np.exp(-S.tvec(160) / 0.002) * R.uniform(0.1, 0.3)
    return _finish(whoosh + swell + crackle * _env(n, 0.01, 0.12), 0.85)


def wall_slide(seconds: float = 1.2) -> np.ndarray:
    n = S.samples(seconds + 0.2)
    t = S.tvec(n)
    grit = S.bandpass(S.white(n), 1100, 3600)
    mod = 0.65 + 0.35 * np.abs(np.sin(2 * np.pi * 11.0 * t + R.uniform(0, 6))) * (0.7 + 0.3 * np.sin(2 * np.pi * 3.1 * t))
    x = grit * mod
    loop = S.samples(seconds)
    m = n - loop
    out = x[:loop].copy()
    fade = np.linspace(0, 1, m)
    out[:m] = out[:m] * fade + x[loop:] * (1 - fade)
    return S.normalize(out, 0.5)


def wall_jump() -> np.ndarray:
    scrape = S.bandpass(S.white(S.samples(0.12)), 1500, 4500) * _env(S.samples(0.12), 0.002, 0.03)
    j = jump()
    j[:len(scrape)] += scrape * 0.5
    return _finish(j, 0.75)


def swing(i: int) -> np.ndarray:
    n = S.samples(0.2)
    lo, hi = (2000, 500) if i == 1 else (2400, 650)
    whoosh = S.sweep_filter(S.white(n), lo, hi, q=1.6) * _env(n, 0.015, 0.05)
    jingle = _rings(base=3100 + 150 * i, count=2, decay=0.12, gain=0.12)[:n]
    return _finish(whoosh + jingle, 0.7)


def _rings(base: float, count: int, decay: float, gain: float) -> np.ndarray:
    """Anéis metálicos do cajado: parciais inarmônicas, entradas levemente defasadas."""
    n = S.samples(1.4)
    t = S.tvec(n)
    out = np.zeros(n)
    for r in range(count):
        f = base * (1 + 0.137 * r) * R.uniform(0.98, 1.02)
        start = S.samples(0.006 + 0.017 * r + R.uniform(0, 0.006))
        ring = np.zeros(n)
        tt = t[: n - start]
        for ratio, amp, tau in [(1.0, 1.0, 1.0), (1.43, 0.6, 0.7), (2.11, 0.4, 0.5), (2.97, 0.25, 0.35), (4.2, 0.12, 0.2)]:
            fr = f * ratio
            if fr < 17000:
                ring[start:] += amp * np.exp(-tt / (decay * tau)) * np.sin(2 * np.pi * fr * tt + R.uniform(0, 6.28))
        out += ring * (1.0 - 0.2 * r)
    return out * gain


def ring() -> np.ndarray:
    """Pogo/golpe: os anéis tilintam — o som-assinatura do jogo."""
    n = S.samples(1.4)
    out = _rings(base=2050, count=3, decay=0.5, gain=1.0)
    knock = S.resonator(S.white(S.samples(0.05)) * _env(S.samples(0.05), 0.0005, 0.004), 420, 6) * 0.8
    out[:len(knock)] += knock
    sparkle = S.glass_bell("D7", 1.0, 0.2)
    out[:len(sparkle)] += sparkle * 0.6
    return _finish(out[:n], 0.85, 0.1)


def wall_hit() -> np.ndarray:
    n = S.samples(0.5)
    imp = S.white(S.samples(0.006)) * np.linspace(1, 0, S.samples(0.006))
    body = np.zeros(n)
    body[:len(imp)] = imp
    stone = S.resonator(body, 900, 9) * 1.4 + S.resonator(body, 1850, 12) * 0.8 + S.resonator(body, 3400, 16) * 0.3
    stone *= _env(n, 0.0005, 0.05)
    jingle = _rings(base=2600, count=2, decay=0.25, gain=0.25)[:n]
    return _finish(stone + jingle, 0.8, 0.08)


def hurt() -> np.ndarray:
    n = S.samples(0.75)
    t = S.tvec(n)
    cluster = sum(np.sin(2 * np.pi * f * t + R.uniform(0, 6)) for f in (220, 233.1, 311.1)) * _env(n, 0.003, 0.18) * 0.35
    melt = _sine_sweep(420, 110, 0.75, 0.2) * 0.5
    burst = S.lowpass(S.white(n), 2200) * _env(n, 0.001, 0.06) * 0.6
    thud = _sine_sweep(110, 45, 0.75, 0.12) * 0.7
    return _finish(cluster + melt + burst + thud, 0.9, 0.1)


def respawn() -> np.ndarray:
    n = S.samples(1.6)
    out = np.zeros(n)
    for i, note in enumerate(["D5", "F5", "A5", "D6", "F6"]):
        b = S.glass_bell(note, 1.4, 0.35)
        S.place(out, b, 0.07 * i)
    swell = S.sweep_filter(S.white(n), 400, 3000, q=1.0) * S.env_ar(n, 0.6, 0.6) * 0.25
    return _finish(out + swell, 0.75, 0.2)


def tablet() -> np.ndarray:
    bell = S.temple_bell("G2", 4.0, 0.6)
    shimmer = S.glass_bell("D6", 2.5, 0.2)
    out = bell.copy()
    out[:len(shimmer)] += shimmer * 0.5
    return _finish(out, 0.6, 0.6)


def transition() -> np.ndarray:
    n = S.samples(0.4)
    air = S.lowpass(S.pink(n), 1500) * S.env_ar(n, 0.15, 0.2)
    return _finish(air, 0.5)


def ui_start() -> np.ndarray:
    bowl = S.singing_bowl("D3", 9.0, 0.8)
    return _finish(bowl, 0.85, 1.5)


def altar() -> np.ndarray:
    n = S.samples(6.0)
    pad = S.strings_pad(["D3", "A3", "C4", "F4"], 3.0, attack=0.6, release=2.8, bright=0.4)
    mono = pad.mean(axis=0)[:n]
    out = np.zeros(n)
    out[:len(mono)] += mono * 1.2
    out += S.singing_bowl("A2", 6.0, 0.6)[:n] * 0.8
    for i, note in enumerate(["A5", "D6", "E6"]):
        S.place(out, S.glass_bell(note, 2.5, 0.25), 0.4 + 0.25 * i)
    return _finish(out, 0.8, 1.0)


ALL = {
    "jump": jump,
    "air_jump": air_jump,
    "land": lambda: land(False),
    "land_hard": lambda: land(True),
    "step_1": lambda: step(0),
    "step_2": lambda: step(1),
    "step_3": lambda: step(2),
    "dash": dash,
    "wall_slide": wall_slide,
    "wall_jump": wall_jump,
    "swing_1": lambda: swing(1),
    "swing_2": lambda: swing(2),
    "ring": ring,
    "wall_hit": wall_hit,
    "hurt": hurt,
    "respawn": respawn,
    "tablet": tablet,
    "transition": transition,
    "ui_start": ui_start,
    "altar": altar,
}
