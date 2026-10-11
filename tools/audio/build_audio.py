"""Gera toda a trilha e os efeitos de VELA.

Uso (na raiz do projeto):
    python3 tools/audio/build_audio.py            # tudo
    python3 tools/audio/build_audio.py sfx         # só efeitos
    python3 tools/audio/build_audio.py poco titulo # faixas específicas

Requisitos: Python 3.10+, numpy, scipy e ffmpeg (com libvorbis) no PATH.
"""
from __future__ import annotations

import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import compose  # noqa: E402
import sfx  # noqa: E402
import synth as S  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
MUSIC_DIR = os.path.join(ROOT, "assets", "audio", "music")
SFX_DIR = os.path.join(ROOT, "assets", "audio", "sfx")
TMP_DIR = os.path.join(HERE, "out")

MUSIC = {
    "titulo": (compose.compose_title, 5),
    "poco": (compose.compose_poco, 5),
    "limiar": (compose.compose_limiar, 5),
    "amb_poco": (compose.compose_ambience, 3),
}


def to_ogg(wav: str, ogg: str, quality: int) -> None:
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", str(quality), ogg], check=True)


def build_music(names: list[str]) -> None:
    os.makedirs(MUSIC_DIR, exist_ok=True)
    os.makedirs(TMP_DIR, exist_ok=True)
    for name in names:
        fn, q = MUSIC[name]
        t0 = time.time()
        mix = fn()
        wav = os.path.join(TMP_DIR, name + ".wav")
        S.write_wav(wav, mix)
        ogg = os.path.join(MUSIC_DIR, name + ".ogg")
        to_ogg(wav, ogg, q)
        print(f"  música {name:9s} {mix.shape[1] / S.SR:6.1f}s  rms {S.rms_db(mix):6.1f} dB  pico {20 * __import__('numpy').log10(abs(mix).max()):5.1f} dB  ({time.time() - t0:.1f}s)")


def build_sfx() -> None:
    os.makedirs(SFX_DIR, exist_ok=True)
    for name, fn in sfx.ALL.items():
        x = fn()
        S.write_wav(os.path.join(SFX_DIR, name + ".wav"), x)
        print(f"  efeito {name:11s} {len(x) / S.SR:5.2f}s")


def main(args: list[str]) -> None:
    if not args:
        build_sfx()
        build_music(list(MUSIC))
        return
    if "sfx" in args:
        build_sfx()
    names = [a for a in args if a in MUSIC]
    if names:
        build_music(names)


if __name__ == "__main__":
    main(sys.argv[1:])
