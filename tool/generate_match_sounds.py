#!/usr/bin/env python3
"""Synthesize the match start and end cues shipped in `assets/audio/`.

Both WAVs are built from scratch — additive synthesis, no recordings and no
third-party samples — so the audio the app ships carries the project's own
licence and no one else's. Regenerate with:

    python3 tool/generate_match_sounds.py

Design: a referee hears these across a noisy mat, often with their back to the
phone, so the two cues are deliberate opposites. The start is a short, bright
bell strike (G5); the end is a long, low twin air-horn blast two octaves below
it (G3). Same note, opposite register — they read as one app, and nobody can
mistake one for the other.

Only the Python standard library is used, so this runs anywhere.
"""

import math
import os
import random
import struct
import wave

SAMPLE_RATE = 44100

_REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(_REPO, "assets", "audio")


def smoothstep(x):
    """Ease 0..1 with zero slope at both ends — envelopes that don't click."""
    x = min(1.0, max(0.0, x))
    return x * x * (3.0 - 2.0 * x)


def write_wav(path, samples, peak=0.92):
    """Peak-normalize to `peak` and write mono 16-bit PCM."""
    loudest = max(abs(s) for s in samples) or 1.0
    gain = peak / loudest
    frames = b"".join(
        struct.pack("<h", int(max(-32767, min(32767, s * gain * 32767))))
        for s in samples
    )
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SAMPLE_RATE)
        f.writeframes(frames)
    return len(samples) / SAMPLE_RATE


# ── Start: bell strike ──────────────────────────────────────────────────────
#
# A struck bell is inharmonic — its partials are not whole multiples of the
# fundamental, which is exactly what makes it read as "metal" instead of
# "beep". Ratios below follow a classic bell spectrum (prime, nominal, tierce,
# quint...). Higher partials decay faster, so the strike is bright and the tail
# is pure: the same thing a real bell does as it rings out.
BELL_PARTIALS = [
    # (frequency ratio, amplitude, decay seconds)
    (1.00, 1.00, 1.05),
    (2.00, 0.62, 0.80),
    (2.76, 0.42, 0.58),
    (3.00, 0.34, 0.52),
    (4.07, 0.24, 0.38),
    (5.43, 0.15, 0.26),
    (6.79, 0.10, 0.18),
]


def bell(f0=784.0, duration=1.30):
    """Bright single bell strike — the fight is on."""
    n = int(SAMPLE_RATE * duration)
    out = [0.0] * n

    for ratio, amp, decay in BELL_PARTIALS:
        w = 2.0 * math.pi * f0 * ratio
        for i in range(n):
            t = i / SAMPLE_RATE
            out[i] += amp * math.exp(-t / decay) * math.sin(w * t)

    # The hammer itself: a few milliseconds of noise, high-passed by first
    # difference. Without it the bell sounds struck by nothing at all.
    random.seed(1415)  # deterministic — the same run gives the same file
    previous = 0.0
    for i in range(int(SAMPLE_RATE * 0.030)):
        t = i / SAMPLE_RATE
        sample = random.uniform(-1.0, 1.0)
        out[i] += 0.30 * math.exp(-t / 0.005) * (sample - previous)
        previous = sample

    # 1.5 ms in, 40 ms out: kills the DC clicks at both ends without softening
    # the attack enough to hear.
    attack = int(SAMPLE_RATE * 0.0015)
    release = int(SAMPLE_RATE * 0.040)
    for i in range(attack):
        out[i] *= smoothstep(i / attack)
    for i in range(release):
        out[n - 1 - i] *= smoothstep(i / release)

    return out


# ── End: air horn ───────────────────────────────────────────────────────────


def horn(f0=196.0, duration=1.50):
    """Low twin air-horn blast — regulation time is over."""
    n = int(SAMPLE_RATE * duration)
    out = [0.0] * n

    attack, release = 0.020, 0.30
    harmonics = 16

    # Two horns, slightly out of tune with each other. The beating between them
    # is what separates a real air horn from a synthesizer holding a chord.
    for detune, voice_amp in ((1.000, 1.00), (1.008, 0.85)):
        phase = 0.0
        for i in range(n):
            t = i / SAMPLE_RATE
            # Air runs out as the blast releases, and the pitch sags with it.
            sag = 1.0 - 0.035 * smoothstep(
                (t - (duration - release)) / release
            )
            phase += 2.0 * math.pi * f0 * detune * sag / SAMPLE_RATE

            # 1/h harmonic stack: a sawtooth-shaped spectrum, which is roughly
            # what a horn's resonating column produces.
            total = 0.0
            for h in range(1, harmonics + 1):
                total += math.sin(phase * h) / h
            out[i] += voice_amp * total

    for i in range(n):
        t = i / SAMPLE_RATE
        if t < attack:
            envelope = smoothstep(t / attack)
        elif t > duration - release:
            envelope = smoothstep((duration - t) / release)
        else:
            envelope = 1.0
        out[i] *= envelope

    return out


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, samples, peak in (
        ("match_start.wav", bell(), 0.95),
        # The horn sustains where the bell decays, so equal peaks would leave
        # it far louder. Trimming it keeps the pair even to the ear.
        ("match_end.wav", horn(), 0.82),
    ):
        path = os.path.join(OUT_DIR, name)
        seconds = write_wav(path, samples, peak=peak)
        size = os.path.getsize(path)
        print(f"{name}: {seconds:.2f}s, {size / 1024:.0f} KiB")


if __name__ == "__main__":
    main()
