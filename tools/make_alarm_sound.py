#!/usr/bin/env python3
"""Generates the foreground alarm tone.

Synthesised from sine waves rather than shipping a sound file: an original work
with no third-party rights attached, same reasoning as the beer artwork in
tools/make_beer_background.swift.

The result is a seamless loop — two short chirps and a rest, 1.6 s — so
AVAudioPlayer can repeat it indefinitely without a click at the seam. Both tones
start and end at a zero crossing and are enveloped, which is what removes the
click; a raw sine cut mid-cycle pops audibly on every repeat.

Usage: python3 tools/make_alarm_sound.py [out.wav]
"""
import math
import struct
import sys
import wave
from pathlib import Path

RATE = 44_100
LOOP = 1.6           # seconds
BEEP = 0.14          # length of one chirp
GAP = 0.11           # silence between the two chirps
TONES = (880.0, 1174.7)   # A5 and D6 — a fourth apart, alerting without shrieking
ATTACK = 0.008
RELEASE = 0.045


def envelope(position, length):
    """Short attack, longer release, so each chirp starts and ends at silence."""
    if position < ATTACK:
        return position / ATTACK
    if position > length - RELEASE:
        return max(0.0, (length - position) / RELEASE)
    return 1.0


def render():
    samples = [0.0] * int(RATE * LOOP)
    for index, frequency in enumerate(TONES):
        start = index * (BEEP + GAP)
        for n in range(int(RATE * BEEP)):
            position = n / RATE
            offset = int((start + position) * RATE)
            if offset >= len(samples):
                break
            value = math.sin(2 * math.pi * frequency * position)
            # A quiet octave above adds bite without raising the peak much.
            value += 0.22 * math.sin(4 * math.pi * frequency * position)
            samples[offset] += 0.62 * value * envelope(position, BEEP)
    return samples


def main(path):
    samples = render()
    peak = max(abs(s) for s in samples) or 1.0
    frames = b"".join(struct.pack("<h", int(32767 * 0.9 * s / peak)) for s in samples)

    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(frames)

    # A loop that does not start and end at silence clicks on every repeat, so
    # assert it rather than trusting the arithmetic above.
    edge = max(abs(samples[0]), abs(samples[-1]))
    if edge > 0.001:
        raise SystemExit(f"loop seam is not silent ({edge:.4f}) — it would click")

    print(f"{path}: {len(samples) / RATE:.2f} s, {len(frames) // 1024} KB, "
          f"seam {edge:.5f}")


if __name__ == "__main__":
    default = Path(__file__).resolve().parent.parent / "BeerChiller/Resources/alarm.wav"
    target = Path(sys.argv[1]) if len(sys.argv) > 1 else default
    target.parent.mkdir(parents=True, exist_ok=True)
    main(target)
