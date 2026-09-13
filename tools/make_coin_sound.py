"""Generate the coin pickup sound as a chiptune square-wave blip.

Run from the project root:
    python3 tools/make_coin_sound.py

Writes assets/audio/coin.wav (16-bit mono PCM), the classic two-note coin
arpeggio: a short high note that jumps up to a longer note which fades out.
"""

import math
import os
import struct
import wave

SAMPLE_RATE = 44100
AMPLITUDE = 0.32
FADE_SECONDS = 0.002

FIRST_NOTE_HZ = 987.77  # B5
FIRST_NOTE_SECONDS = 0.075
SECOND_NOTE_HZ = 1318.51  # E6
SECOND_NOTE_SECONDS = 0.38

OUTPUT_PATH = os.path.join("assets", "audio", "coin.wav")


def square_wave(frequency, seconds, decay):
    total = int(SAMPLE_RATE * seconds)
    fade = max(int(SAMPLE_RATE * FADE_SECONDS), 1)
    samples = []
    for index in range(total):
        time = index / SAMPLE_RATE
        phase = (frequency * time) % 1.0
        value = 1.0 if phase < 0.5 else -1.0
        if decay:
            value *= math.pow(0.0025, time / seconds)
        if index < fade:
            value *= index / fade
        remaining = total - index
        if remaining < fade:
            value *= remaining / fade
        samples.append(value * AMPLITUDE)
    return samples


def write_wave(path, samples):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    frames = b"".join(
        struct.pack("<h", int(max(-1.0, min(1.0, value)) * 32767)) for value in samples
    )
    with wave.open(path, "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(frames)


def main():
    samples = square_wave(FIRST_NOTE_HZ, FIRST_NOTE_SECONDS, decay=False)
    samples += square_wave(SECOND_NOTE_HZ, SECOND_NOTE_SECONDS, decay=True)
    write_wave(OUTPUT_PATH, samples)
    print("wrote %s (%d samples)" % (OUTPUT_PATH, len(samples)))


if __name__ == "__main__":
    main()
