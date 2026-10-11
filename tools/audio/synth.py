"""Instrumentos e efeitos de áudio sintetizados com numpy.

Tudo é gerado do zero (nenhuma amostra gravada): piano de feltro, cordas em pad,
coro com formantes, sinos de templo, tigela tibetana, ruídos e reverb por
convolução. Usado por compose.py (música) e sfx.py (efeitos).
"""
from __future__ import annotations

import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 44100
RNG = np.random.default_rng(7)

NOTE_INDEX = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5,
              "F#": 6, "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


# ---------------------------------------------------------------------------
# Notas e utilidades
# ---------------------------------------------------------------------------

def midi(name: str) -> int:
    """'C#4' -> 61."""
    return 12 * (int(name[-1]) + 1) + NOTE_INDEX[name[:-1]]


def hz(note: str | int | float) -> float:
    if isinstance(note, str):
        note = midi(note)
    return 440.0 * 2.0 ** ((float(note) - 69.0) / 12.0)


def tvec(n: int) -> np.ndarray:
    return np.arange(n) / SR


def samples(seconds: float) -> int:
    return int(round(seconds * SR))


def lowpass(x: np.ndarray, fc: float, order: int = 2) -> np.ndarray:
    sos = signal.butter(order, min(fc, SR * 0.45), "lowpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x, axis=-1)


def highpass(x: np.ndarray, fc: float, order: int = 2) -> np.ndarray:
    sos = signal.butter(order, fc, "highpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x, axis=-1)


def bandpass(x: np.ndarray, lo: float, hi: float, order: int = 2) -> np.ndarray:
    sos = signal.butter(order, [lo, min(hi, SR * 0.45)], "bandpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x, axis=-1)


def resonator(x: np.ndarray, f: float, q: float) -> np.ndarray:
    b, a = signal.iirpeak(f, q, fs=SR)
    return signal.lfilter(b, a, x)


def white(n: int) -> np.ndarray:
    return RNG.standard_normal(n)


def pink(n: int) -> np.ndarray:
    # filtro de Paul Kellet (aproximação de ruído rosa)
    b = [0.049922035, -0.095993537, 0.050612699, -0.004408786]
    a = [1, -2.494956002, 2.017265875, -0.522189400]
    return signal.lfilter(b, a, white(n)) * 3.5


def brown(n: int) -> np.ndarray:
    x = np.cumsum(white(n)) * 0.02
    return highpass(x, 15.0, 1)


def sweep_filter(x: np.ndarray, f_start: float, f_end: float, q: float = 1.2, block: int = 256) -> np.ndarray:
    """Passa-banda com frequência central variando no tempo (exponencialmente)."""
    out = np.zeros_like(x)
    n = len(x)
    zi = None
    for i in range(0, n, block):
        k = i / max(n - 1, 1)
        fc = f_start * (f_end / f_start) ** k
        bw = fc / q
        lo = max(fc - bw / 2, 20.0)
        hi = min(fc + bw / 2, SR * 0.45)
        sos = signal.butter(2, [lo, hi], "bandpass", fs=SR, output="sos")
        if zi is None:
            zi = np.zeros((sos.shape[0], 2))
        out[i:i + block], zi = signal.sosfilt(sos, x[i:i + block], zi=zi)
    return out


def env_ar(n: int, attack: float, release: float, curve: float = 2.0) -> np.ndarray:
    """Envelope ataque/liberação suave ao longo de n amostras."""
    t = tvec(n)
    total = n / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    r = np.clip((total - t) / max(release, 1e-4), 0, 1)
    return (np.sin(a * np.pi / 2) ** curve) * (np.sin(r * np.pi / 2) ** curve)


def pan(mono: np.ndarray, p: float) -> np.ndarray:
    """p em [-1, 1]; potência constante."""
    a = (p + 1) * np.pi / 4
    return np.vstack([mono * np.cos(a), mono * np.sin(a)])


def place(buf: np.ndarray, sound: np.ndarray, at: float) -> None:
    """Soma `sound` em `buf` (mono ou estéreo) a partir de `at` segundos."""
    i = samples(at)
    if i >= buf.shape[-1]:
        return
    m = min(sound.shape[-1], buf.shape[-1] - i)
    if buf.ndim == 2 and sound.ndim == 1:
        sound = np.vstack([sound, sound])
    buf[..., i:i + m] += sound[..., :m]


def normalize(x: np.ndarray, peak: float = 0.89) -> np.ndarray:
    m = np.max(np.abs(x))
    return x if m < 1e-9 else x * (peak / m)


def soft_clip(x: np.ndarray, drive: float = 1.0) -> np.ndarray:
    return np.tanh(x * drive) / np.tanh(drive)


def rms_db(x: np.ndarray) -> float:
    return 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-12)


def write_wav(path: str, x: np.ndarray) -> None:
    data = np.clip(x, -1, 1)
    if data.ndim == 2:
        data = data.T
    wavfile.write(path, SR, (data * 32767).astype(np.int16))


# ---------------------------------------------------------------------------
# Reverb (convolução com resposta ao impulso sintética)
# ---------------------------------------------------------------------------

def reverb_ir(seconds: float = 3.6, predelay: float = 0.03, bright: float = 0.5) -> np.ndarray:
    n = samples(seconds)
    t = tvec(n)
    ir = np.zeros((2, n + samples(predelay)))
    for ch in range(2):
        noise = white(n)
        low = lowpass(noise, 500.0)
        mid = bandpass(noise, 500.0, 3500.0)
        high = highpass(noise, 3500.0)
        rt = np.array([seconds * 1.1, seconds * 0.85, seconds * (0.35 + 0.35 * bright)])
        decay = [np.exp(-6.9 * t / r) for r in rt]
        tail = low * decay[0] + mid * decay[1] * 0.8 + high * decay[2] * (0.25 + 0.4 * bright)
        # entrada suave da cauda
        tail *= np.clip(t / 0.08, 0, 1)
        ir[ch, samples(predelay):] = tail
        # reflexões iniciais
        for k, (d, g) in enumerate([(0.011, 0.5), (0.019, 0.42), (0.027, 0.36), (0.041, 0.3), (0.053, 0.24), (0.067, 0.2)]):
            ir[ch, samples(d + 0.002 * ch * (k % 2))] += g * (1 if (k + ch) % 2 == 0 else -1)
    return ir / np.max(np.abs(ir))


def apply_reverb(x: np.ndarray, ir: np.ndarray, wet: float, dry: float = 1.0) -> np.ndarray:
    """Convolução estéreo; a cauda fica no fim do buffer devolvido."""
    if x.ndim == 1:
        x = np.vstack([x, x])
    out = np.zeros((2, x.shape[1] + ir.shape[1] - 1))
    for ch in range(2):
        g = 1.0 / np.sqrt(np.sum(ir[ch] ** 2))
        out[ch] = signal.fftconvolve(x[ch], ir[ch]) * g * wet
    out[:, :x.shape[1]] += x * dry
    return out


# ---------------------------------------------------------------------------
# Instrumentos
# ---------------------------------------------------------------------------

def piano(note, dur: float, vel: float = 0.6, bright: float = 0.45, tail: float = 3.0) -> np.ndarray:
    """Piano de feltro: parciais levemente inarmônicas, as agudas morrem antes;
    martelo de feltro; abafador ao soltar a nota."""
    f0 = hz(note)
    n = samples(dur + tail)
    t = tvec(n)
    base_tau = float(np.clip(3.4 * (220.0 / f0) ** 0.55, 0.7, 7.0))
    inharm = 0.00032
    out = np.zeros(n)
    for k in range(1, 16):
        fk = k * f0 * np.sqrt(1 + inharm * k * k)
        if fk > 15000:
            break
        amp = (1.0 / k ** 1.35) * np.exp(-(k - 1) * (0.62 - 0.4 * vel) * (1.2 - bright))
        tau = base_tau / (1 + 0.5 * (k - 1))
        ph = RNG.uniform(0, 2 * np.pi)
        det = 1.0 + 0.0007 * (1 if k % 2 else -1)
        out += amp * np.exp(-t / tau) * (np.sin(2 * np.pi * fk * t + ph) + 0.55 * np.sin(2 * np.pi * fk * det * t + ph * 1.7))
    # abafador
    idx = samples(dur)
    damper = np.ones(n)
    damper[idx:] = np.exp(-(t[idx:] - dur) / 0.42)
    out *= damper
    # martelo de feltro
    hn = samples(0.02)
    hammer = bandpass(white(hn), min(f0 * 2, 3000), min(f0 * 8, 9000)) * np.exp(-tvec(hn) / 0.004)
    out[:hn] += hammer * 0.25 * vel
    out *= np.clip(t / 0.004, 0, 1) * vel
    return lowpass(out, 1600 + 5200 * vel * bright, 2)


def saw_bank(freqs, n: int, detune_cents: float, voices: int, vibrato: float = 0.0022, harmonics: int = 18) -> np.ndarray:
    """Banco de serras com detune e vibrato; devolve estéreo."""
    t = tvec(n)
    out = np.zeros((2, n))
    for f in freqs:
        for v in range(voices):
            spread = 0.0 if voices == 1 else (v / (voices - 1) * 2 - 1)
            cents = spread * detune_cents
            rate = 4.4 + 0.37 * v
            vib = 1 + vibrato * np.sin(2 * np.pi * rate * t + RNG.uniform(0, 6.28))
            fv = f * 2 ** (cents / 1200)
            phase = 2 * np.pi * np.cumsum(fv * vib) / SR + RNG.uniform(0, 6.28)
            kmax = int(min(harmonics, (SR * 0.42) / fv))
            wave = np.zeros(n)
            for k in range(1, kmax + 1):
                wave += np.sin(k * phase) / k
            p = spread * 0.7
            out += pan(wave, p)
    return out / max(len(freqs) * voices, 1) ** 0.5


def strings_pad(notes, dur: float, attack: float = 1.6, release: float = 2.8, bright: float = 0.35) -> np.ndarray:
    freqs = [hz(x) for x in notes]
    n = samples(dur + release)
    x = saw_bank(freqs, n, detune_cents=9.0, voices=4)
    env = env_ar(n, attack, release, 1.3)
    cutoff = 700 + 1500 * bright
    x = lowpass(x, cutoff, 2) * env
    return x * 0.5


def choir(notes, dur: float, vowel: str = "o", attack: float = 2.2, release: float = 3.0) -> np.ndarray:
    formants = {
        "a": [(730, 9, 1.0), (1090, 10, 0.55), (2440, 14, 0.22)],
        "o": [(470, 8, 1.0), (840, 9, 0.5), (2600, 14, 0.18)],
        "u": [(320, 7, 1.0), (760, 9, 0.3), (2400, 14, 0.1)],
    }[vowel]
    freqs = [hz(x) for x in notes]
    n = samples(dur + release)
    src = saw_bank(freqs, n, detune_cents=14.0, voices=3, vibrato=0.0045, harmonics=30)
    out = np.zeros_like(src)
    for f, q, g in formants:
        for ch in range(2):
            out[ch] += resonator(src[ch], f, q) * g
    breath = bandpass(pink(n), 1800, 6000) * 0.04
    out += np.vstack([breath, breath[::-1]])
    return out * env_ar(n, attack, release, 1.4) * 0.6


def temple_bell(note, dur: float = 6.0, vel: float = 0.5) -> np.ndarray:
    """Sino grave com parciais inarmônicas (estilo Risset)."""
    f0 = hz(note)
    n = samples(dur)
    t = tvec(n)
    partials = [(0.56, 1.0, 1.0), (0.56 * 1.002, 0.67, 0.9), (0.92, 1.0, 0.65), (0.92 * 1.003, 1.8, 0.55),
                (1.19, 2.67, 0.325), (1.70, 1.67, 0.35), (2.00, 1.46, 0.25), (2.74, 1.33, 0.2),
                (3.00, 1.33, 0.15), (3.76, 1.0, 0.1), (4.07, 1.33, 0.075)]
    out = np.zeros(n)
    for ratio, amp, dscale in partials:
        f = f0 * ratio * 2
        if f > 16000:
            continue
        out += amp * np.exp(-t / (dur * dscale * 0.45)) * np.sin(2 * np.pi * f * t + RNG.uniform(0, 6.28))
    out *= np.clip(t / 0.003, 0, 1)
    return out / 6.0 * vel


def glass_bell(note, dur: float = 2.5, vel: float = 0.4) -> np.ndarray:
    """Sininho agudo/celesta para brilhos."""
    f0 = hz(note)
    n = samples(dur)
    t = tvec(n)
    out = np.zeros(n)
    for ratio, amp, tau in [(1.0, 1.0, 0.9), (2.76, 0.4, 0.35), (5.40, 0.18, 0.15), (8.93, 0.08, 0.07)]:
        f = f0 * ratio
        if f < 16000:
            out += amp * np.exp(-t / (tau * dur * 0.6)) * np.sin(2 * np.pi * f * t + RNG.uniform(0, 6.28))
    return out * np.clip(t / 0.002, 0, 1) * vel * 0.6


def singing_bowl(note, dur: float = 9.0, vel: float = 0.6) -> np.ndarray:
    """Tigela tibetana: pares de parciais levemente desafinados (batimento lento)."""
    f0 = hz(note)
    n = samples(dur)
    t = tvec(n)
    out = np.zeros(n)
    for ratio, amp, tau, beat in [(1.0, 1.0, 0.55, 0.7), (2.71, 0.55, 0.38, 1.3), (5.15, 0.28, 0.22, 2.1), (8.5, 0.12, 0.12, 3.0)]:
        f = f0 * ratio
        if f > 15000:
            continue
        env = np.exp(-t / (tau * dur))
        out += amp * env * (np.sin(2 * np.pi * f * t) + 0.8 * np.sin(2 * np.pi * (f + beat) * t + 1.0))
    mallet = lowpass(white(samples(0.03)), 2500) * np.exp(-tvec(samples(0.03)) / 0.006)
    out[:len(mallet)] += mallet * 0.3
    return out * np.clip(t / 0.004, 0, 1) * vel / 3.0


def drone(note, dur: float, gain: float = 1.0) -> np.ndarray:
    f = hz(note)
    n = samples(dur)
    t = tvec(n)
    lfo = 0.75 + 0.25 * np.sin(2 * np.pi * 0.07 * t + 1.3)
    x = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * 2 * f * t + 0.6) + 0.12 * np.sin(2 * np.pi * 3.01 * f * t)
    air = lowpass(pink(n), 260) * 0.25
    x = (x + air) * lfo * env_ar(n, 3.0, 3.0, 1.2) * gain * 0.3
    return np.vstack([x, np.roll(x, 210)])
