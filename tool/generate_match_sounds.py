#!/usr/bin/env python3
"""Synthesize the match start and end cues shipped in `assets/audio/`.

Both WAVs are built from scratch — additive synthesis, no recordings and no
third-party samples — so the audio the app ships carries the project's own
licence and no one else's. Regenerate with:

    python3 tool/generate_match_sounds.py

Design: a referee hears these across a noisy mat, often with their back to the
phone, so the two cues are deliberate opposites. The start is a short, bright
bell strike (G5, 784 Hz); the end is a long, hard klaxon blast almost three
octaves below it (A2, 110 Hz) — the sound most competition tables already use.
High against low, ringing against rasping, 1.3 s against 2 s: nobody can
mistake one for the other with their back turned.

One constraint shapes both, and the klaxon especially. Phone speakers roll off
hard below ~400 Hz, so a low cue is barely heard through its fundamental at all
— the harmonics above it are what carries, and the ear reconstructs the pitch
that is missing. Dropping the fundamental without keeping energy up in the band
the speaker can actually move buys a cue that measures deeper and sounds thinner
on the only device that matters.

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


# ── End: klaxon ─────────────────────────────────────────────────────────────


def horn(f0=110.0, duration=2.00):
    """Hard low klaxon blast — regulation time is over.

    Deliberately harsher than a clean tone. A klaxon's odd-harmonic rasp cuts
    through gym noise where a pure horn gets swallowed by it, and it is what a
    competitor already hears as "time" without being taught.
    """
    n = int(SAMPLE_RATE * duration)
    out = [0.0] * n

    # Opens in 8 ms — an end-of-regulation cue is late the moment it is soft.
    attack, release = 0.008, 0.16
    harmonics = 25

    # Two horns, slightly out of tune with each other. The beating between them
    # is what separates a real klaxon from a synthesizer holding a note.
    for detune, voice_amp in ((1.000, 1.00), (1.004, 0.60)):
        phase = 0.0
        for i in range(n):
            t = i / SAMPLE_RATE
            # Air runs out as the blast releases, and the pitch sags with it.
            sag = 1.0 - 0.015 * smoothstep(
                (t - (duration - release)) / release
            )
            phase += 2.0 * math.pi * f0 * detune * sag / SAMPLE_RATE

            # Odd harmonics only — a square-shaped spectrum rather than the
            # sawtooth of an air horn. That is what makes it bite, and it also
            # puts the energy higher up, where a phone speaker can move it.
            total = 0.0
            for h in range(1, harmonics + 1, 2):
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

        # The mechanical warble of a klaxon's diaphragm. Without it two seconds
        # of held tone reads as an alarm clock, not as a horn being sounded.
        envelope *= 0.78 + 0.22 * (
            0.5 + 0.5 * math.cos(2.0 * math.pi * 26.0 * t)
        )
        out[i] *= envelope

    return out


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, samples, peak in (
        ("match_start.wav", bell(), 0.95),
        # Far below the bell's peak, and deliberately so — this number looks
        # wrong until you measure it. The bell is a transient with a 12.7 dB
        # crest factor; the klaxon is a near-square wave that sustains, at
        # 6.0 dB. Matching their *peaks* would leave the klaxon roughly 6 dB
        # louder to the ear. 0.55 lands it at -11.2 dBFS RMS against the bell's
        # -13.1: a hair louder, which is right for the cue that ends a fight.
        ("match_end.wav", horn(), 0.55),
    ):
        path = os.path.join(OUT_DIR, name)
        seconds = write_wav(path, samples, peak=peak)
        size = os.path.getsize(path)
        print(f"{name}: {seconds:.2f}s, {size / 1024:.0f} KiB")


if __name__ == "__main__":
    main()
