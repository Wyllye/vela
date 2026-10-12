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


# ---------------------------------------------------------------------------
# Etapa 2: Nen, Ecos e combate
# ---------------------------------------------------------------------------

def _echo(x: np.ndarray, delay: float = 0.11, fb: float = 0.4, taps: int = 3, darken: float = 3000.0) -> np.ndarray:
    """Eco de verdade para os Ecos: repetições cada vez mais baixas e escuras."""
    d = S.samples(delay)
    out = np.zeros(len(x) + d * taps)
    out[:len(x)] += x
    tap = x.copy()
    for k in range(1, taps + 1):
        tap = S.lowpass(tap, darken) * fb
        out[k * d:k * d + len(x)] += tap
    return out


def _loop(x: np.ndarray, seconds: float) -> np.ndarray:
    """Fecha um loop sem emenda somando a sobra do fim no começo."""
    loop = S.samples(seconds)
    m = len(x) - loop
    out = x[:loop].copy()
    fade = np.linspace(0, 1, m)
    out[:m] = out[:m] * fade + x[loop:] * (1 - fade)
    return out


def eco_hit() -> np.ndarray:
    """O cajado acerta um Eco: a aura fria se parte como vidro."""
    n = S.samples(0.55)
    t = S.tvec(n)
    crack = S.bandpass(S.white(n), 2500, 9000) * _env(n, 0.0005, 0.018) * 0.7
    thup = _sine_sweep(320, 90, 0.55, 0.05) * 0.8
    shards = np.zeros(n)
    for f in (1870, 2730, 3910):
        shards += np.sin(2 * np.pi * f * t + R.uniform(0, 6)) * np.exp(-t / 0.06)
    rings = _rings(base=2300, count=2, decay=0.18, gain=0.35)[:n]
    out = crack + thup + shards * 0.22 + rings
    return _finish(_echo(out, 0.09, 0.3, 3)[:S.samples(0.8)], 0.85, 0.15)


def sneak() -> np.ndarray:
    """Golpe num Eco desatento: um brilho a mais."""
    out = np.zeros(S.samples(1.0))
    S.place(out, S.glass_bell("E7", 0.9, 0.5), 0.0)
    S.place(out, S.glass_bell("B6", 0.9, 0.35), 0.03)
    knock = _sine_sweep(180, 60, 0.3, 0.06)
    out[:len(knock)] += knock * 0.6
    return _finish(out, 0.8, 0.2)


def eco_die() -> np.ndarray:
    """O Eco se desfaz: um suspiro de coro, sinos descendo e o eco indo embora."""
    n = S.samples(1.6)
    ch = S.choir(["A3", "E4"], 0.5, vowel="a", attack=0.02, release=1.1).mean(axis=0)[:n]
    air = S.sweep_filter(S.pink(n), 2500, 400, q=1.0) * S.env_ar(n, 0.02, 1.4) * 0.5
    bells = np.zeros(n)
    for i, note in enumerate(["E6", "B5", "G5", "E5"]):
        S.place(bells, S.glass_bell(note, 1.3, 0.3), 0.06 * i)
    out = np.zeros(n)
    out[:len(ch)] += ch * 0.9
    out += air + bells * 0.8
    return _finish(_echo(out, 0.14, 0.35, 3)[:S.samples(2.0)], 0.8, 0.4)


def eco_notice() -> np.ndarray:
    """Um Eco viu a chama: tilintar, sussurro e um tom grave, ecoando."""
    n = S.samples(0.8)
    t = S.tvec(n)
    tink = S.glass_bell("F#6", 0.6, 0.6)[:n]
    whisper = S.bandpass(S.white(n), 500, 1800)
    whisper = S.sweep_filter(whisper, 600, 1300, q=4.0) * S.env_ar(n, 0.05, 0.5) * 0.9
    low = np.sin(2 * np.pi * S.hz("D3") * t) * np.exp(-t / 0.25) * 0.5
    out = np.zeros(n)
    out[:len(tink)] += tink * 0.9
    out += whisper + low
    return _finish(_echo(out, 0.12, 0.38, 3)[:S.samples(1.2)], 0.8, 0.3)


def vigia_charge() -> np.ndarray:
    n = S.samples(0.7)
    rush = S.sweep_filter(S.white(n), 400, 2600, q=1.2) * S.env_ar(n, 0.08, 0.4) * 0.8
    rumble = S.lowpass(S.brown(n), 180) * S.env_ar(n, 0.05, 0.5) * 1.6
    lantern = _rings(base=1700, count=2, decay=0.2, gain=0.2)[:n]
    return _finish(rush + rumble + lantern, 0.8, 0.1)


def saltador_jump() -> np.ndarray:
    n = S.samples(0.22)
    hup = S.sweep_filter(S.white(n), 700, 1600, q=3.0) * _env(n, 0.01, 0.05)
    tone = _sine_sweep(300, 520, 0.22, 0.05) * 0.3
    return _finish(hup + tone, 0.6)


def mariposa_windup() -> np.ndarray:
    """Asas batendo cada vez mais rápido antes do mergulho."""
    n = S.samples(0.5)
    t = S.tvec(n)
    rate = 18 + 30 * (t / t[-1])
    gate = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * np.cumsum(rate) / S.SR))
    gate = S.lowpass(gate, 120)
    wings = S.bandpass(S.white(n), 300, 2500) * gate * S.env_ar(n, 0.1, 0.08)
    shimmer = S.glass_bell("C7", 0.5, 0.2)[:n]
    out = wings.copy()
    out[:len(shimmer)] += shimmer * 0.4
    return _finish(out, 0.7)


def mariposa_dive() -> np.ndarray:
    n = S.samples(0.45)
    t = S.tvec(n)
    w = S.sweep_filter(S.white(n), 3000, 500, q=1.5) * _env(n, 0.01, 0.15)
    return _finish(w * (0.6 + 0.4 * np.sin(2 * np.pi * 22 * t)), 0.75)


def shade_wake() -> np.ndarray:
    """O Eco da própria Vela acorda: os anéis dela, ao contrário."""
    rev = ring()[::-1].copy()
    n = len(rev)
    drone = S.lowpass(S.brown(n), 200) * S.env_ar(n, 0.6, 0.4) * 1.2
    return _finish(_echo(rev * 0.8 + drone, 0.16, 0.4, 3)[:S.samples(2.2)], 0.8, 0.3)


def eco_strike() -> np.ndarray:
    """Um Eco acerta a Vela: um corte frio."""
    n = S.samples(0.35)
    slash = S.sweep_filter(S.white(n), 4000, 900, q=1.3) * _env(n, 0.003, 0.06)
    cold = S.resonator(S.white(n) * _env(n, 0.0005, 0.01), 1400, 12) * 0.8
    return _finish(slash + cold, 0.75)


def death() -> np.ndarray:
    """A chama apaga: sopro, queda grave e um sino longe."""
    dur = 3.2
    n = S.samples(dur)
    snuff = S.sweep_filter(S.white(n), 2500, 200, q=0.9) * _env(n, 0.01, 0.25) * 0.8
    sub = _sine_sweep(110, 35, dur, 0.9) * 0.9
    bell = S.temple_bell("D2", dur, 0.7)
    hiss = S.highpass(S.white(n), 4000) * S.env_ar(n, 0.3, 1.5) * 0.08
    return _finish(snuff + sub + bell * 1.2 + hiss, 0.85, 0.8)


def melt() -> np.ndarray:
    """Derreter: a cera chia e pinga."""
    n = S.samples(0.55)
    sizzle = S.highpass(S.white(n), 3000) * _env(n, 0.01, 0.15) * 0.6
    clicks = np.zeros(n)
    for k in range(14):
        i = R.integers(0, n - 120)
        clicks[i:i + 100] += S.bandpass(S.white(100), 2500, 8000) * np.exp(-S.tvec(100) / 0.002) * R.uniform(0.2, 0.5)
    plip = _sine_sweep(900, 300, 0.12, 0.03) * 0.5
    out = sizzle + clicks * _env(n, 0.01, 0.2)
    i = S.samples(0.18)
    out[i:i + len(plip)] += plip
    return _finish(out, 0.7)


def fizzle() -> np.ndarray:
    """A chama não responde (sem aura, ou fechada no Zetsu)."""
    n = S.samples(0.18)
    return _finish(S.lowpass(S.white(n), 1600) * _env(n, 0.005, 0.04), 0.45)


def zetsu_on() -> np.ndarray:
    """Fechar os nós: inspiração, um baque abafado e a chama apaga."""
    n = S.samples(0.65)
    out = np.zeros(n)
    m = S.samples(0.35)
    out[:m] += S.sweep_filter(S.pink(m), 400, 2000, q=1.0) * S.env_ar(m, 0.25, 0.08) * 0.8
    thump = _sine_sweep(150, 55, 0.3, 0.07)
    k = min(len(thump), n - m)
    out[m:m + k] += thump[:k] * 0.8
    pn = S.samples(0.12)
    puff = S.lowpass(S.white(pn), 1200) * _env(pn, 0.002, 0.03)
    out[m:m + pn] += puff * 0.4
    return _finish(out, 0.7)


def zetsu_off() -> np.ndarray:
    """A chama reacende."""
    n = S.samples(0.5)
    fwump = S.sweep_filter(S.white(n), 300, 2400, q=0.9) * _env(n, 0.02, 0.1) * 0.7
    warm = _sine_sweep(180, 330, 0.5, 0.15) * 0.35
    return _finish(fwump + warm, 0.65)


def ren_burst() -> np.ndarray:
    """A aura explode: estrondo grave, sopro, acorde de coro e os anéis."""
    dur = 1.6
    n = S.samples(dur)
    boom = _sine_sweep(130, 38, dur, 0.35) * 1.2
    blast = S.lowpass(S.white(n), 2200) * _env(n, 0.003, 0.12) * 0.9
    roar = S.sweep_filter(S.white(n), 300, 4000, q=1.0) * _env(n, 0.01, 0.3) * 0.5
    chord = S.choir(["D3", "A3", "D4", "F#4"], 0.4, vowel="a", attack=0.03, release=1.0).mean(axis=0)
    rings = _rings(base=2050, count=3, decay=0.45, gain=0.5)
    out = boom + blast + roar
    out[:min(len(rings), n)] += rings[:n]
    k = min(len(chord), n)
    out[:k] += chord[:k] * 1.4
    return _finish(out, 0.9, 0.4)


def ren_hum(seconds: float = 2.0) -> np.ndarray:
    """Zumbido enquanto o Ren está aberto (loop)."""
    n = S.samples(seconds + 0.3)
    t = S.tvec(n)
    f = S.hz("D2")
    hum = np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * 2 * f * t + 1.0) + 0.25 * np.sin(2 * np.pi * 3 * f * t + 2.0)
    hum *= 0.8 + 0.2 * np.sin(2 * np.pi * 3.0 * t)
    sparks = S.bandpass(S.white(n), 2000, 7000) * (R.random(n) > 0.996)
    air = S.bandpass(S.pink(n), 300, 1500) * 0.3
    return S.normalize(_loop(hum * 0.6 + air + sparks * 0.5, seconds), 0.5)


def shell_ting() -> np.ndarray:
    """O cajado bate numa casca de aura: só tilinta."""
    n = S.samples(0.5)
    t = S.tvec(n)
    out = np.zeros(n)
    for f, a in ((2630, 1.0), (3970, 0.6), (5810, 0.35)):
        out += a * np.sin(2 * np.pi * f * t + R.uniform(0, 6)) * np.exp(-t / 0.09)
    return _finish(out * np.clip(t / 0.001, 0, 1), 0.6, 0.1)


def shell_break() -> np.ndarray:
    """A casca racha inteira: estalo, baque e uma chuva de estilhaços."""
    dur = 1.3
    n = S.samples(dur)
    crunch = S.bandpass(S.white(n), 1500, 8000) * _env(n, 0.001, 0.07) * 0.8
    thud = _sine_sweep(140, 45, dur, 0.12) * 0.9
    out = crunch + thud
    m = S.samples(0.25)
    tt = S.tvec(m)
    for k in range(26):
        at = R.uniform(0.0, 0.5) ** 1.6
        tink = np.sin(2 * np.pi * R.uniform(2200, 7500) * tt + R.uniform(0, 6)) * np.exp(-tt / R.uniform(0.03, 0.09)) * R.uniform(0.15, 0.4)
        S.place(out, tink, at)
    return _finish(out, 0.85, 0.3)


def lesson() -> np.ndarray:
    """Uma lição de Nen aprendida no altar."""
    dur = 5.0
    n = S.samples(dur)
    out = S.singing_bowl("D3", dur, 0.9)[:n] * 1.2
    ch = S.choir(["D3", "A3", "D4", "F#4", "A4"], 2.2, vowel="o", attack=0.4, release=2.2).mean(axis=0)[:n]
    out[:len(ch)] += ch * 1.3
    for i, note in enumerate(["A5", "D6", "F#6", "A6"]):
        S.place(out, S.glass_bell(note, 2.8, 0.35), 0.25 + 0.18 * i)
    return _finish(out, 0.85, 1.2)


def shade_free() -> np.ndarray:
    """O Eco póstumo se desfaz e a aura volta para a Vela."""
    dur = 2.6
    n = S.samples(dur)
    out = np.zeros(n)
    for i, note in enumerate(["D5", "F#5", "A5", "D6", "F#6", "A6"]):
        S.place(out, S.glass_bell(note, 1.8, 0.4), 0.06 * i)
    ch = S.choir(["D4", "A4"], 0.8, vowel="a", attack=0.1, release=1.4).mean(axis=0)[:n]
    out[:len(ch)] += ch
    swell = S.sweep_filter(S.white(n), 500, 4000, q=1.0) * S.env_ar(n, 0.4, 1.2) * 0.2
    return _finish(out + swell, 0.8, 0.6)


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
    "eco_hit": eco_hit,
    "sneak": sneak,
    "eco_die": eco_die,
    "eco_notice": eco_notice,
    "vigia_charge": vigia_charge,
    "saltador_jump": saltador_jump,
    "mariposa_windup": mariposa_windup,
    "mariposa_dive": mariposa_dive,
    "shade_wake": shade_wake,
    "eco_strike": eco_strike,
    "death": death,
    "melt": melt,
    "fizzle": fizzle,
    "zetsu_on": zetsu_on,
    "zetsu_off": zetsu_off,
    "ren_burst": ren_burst,
    "ren_hum": ren_hum,
    "shell_ting": shell_ting,
    "shell_break": shell_break,
    "lesson": lesson,
    "shade_free": shade_free,
}
