"""Generate the game's original mono WAV effects using only the standard library.

The fixed seed and fixed effect order make output reproducible. Run this file from
any directory; it writes assets/audio relative to the project, not the shell cwd.
"""

import math
import random
import struct
import wave
from pathlib import Path

OUTPUT_DIRECTORY = Path(__file__).resolve().parents[1] / "assets/audio"
SAMPLE_RATE = 22050  # Samples per second; mono, signed 16-bit PCM.
PCM_AMPLITUDE = 23000  # Leave headroom below the signed 16-bit maximum of 32767.
EFFECT_DURATIONS = (
    ("thrust", 1.0),
    ("cannon", 0.09),
    ("explosion", 0.8),
    ("infection", 0.18),
    ("missile", 0.5),
    ("bomb", 1.2),
    ("warning", 0.5),
)


def sample_value(name: str, time: float, progress: float, rng: random.Random) -> float:
    """Return one floating-point waveform sample before PCM clamping.

    time is seconds since the effect began; progress is the fraction of its length.
    Consume one noise value for every sample, even tonal ones, to preserve the
    deterministic sequence shared by the generated effects.
    """
    # One-shots fade quadratically; the sustained engine keeps a constant envelope.
    envelope = 1 if name == "thrust" else (1 - progress) ** 2
    noise = rng.uniform(-1, 1)
    if name == "thrust":
        return 0.16 * noise + 0.18 * math.sin(2 * math.pi * 55 * time)
    if name in ("explosion", "bomb"):
        return (
            0.65 * noise + 0.3 * math.sin(2 * math.pi * (70 - 30 * progress) * time)
        ) * envelope
    if name == "cannon":
        return (0.5 * noise + 0.4 * math.sin(2 * math.pi * 170 * time)) * envelope
    if name == "warning":
        frequency = 660 if progress < 0.5 else 880
        return 0.5 * math.sin(2 * math.pi * frequency * time) * envelope
    # Missile and infection sounds combine noise with a descending pitch sweep.
    return (
        0.35 * noise + 0.5 * math.sin(2 * math.pi * (700 - 500 * progress) * time)
    ) * envelope


def generate_effect(name: str, duration: float, rng: random.Random) -> None:
    """Synthesize one named effect and write its mono little-endian PCM WAV.

    duration is measured in seconds. The shared RNG keeps the original effect
    sequence reproducible; changing the generation order would change later noise.
    """
    samples = []
    for sample_index in range(int(SAMPLE_RATE * duration)):
        time = sample_index / SAMPLE_RATE
        progress = time / duration
        value = sample_value(name, time, progress, rng)
        # Clamp before integer conversion to stay within the PCM amplitude range.
        samples.append(struct.pack("<h", int(max(-1, min(1, value)) * PCM_AMPLITUDE)))

    with wave.open(str(OUTPUT_DIRECTORY / (name + ".wav")), "wb") as output:
        output.setparams((1, 2, SAMPLE_RATE, 0, "NONE", "not compressed"))
        output.writeframes(b"".join(samples))


def main() -> None:
    """Create the output folder and regenerate all effects in their fixed seed order."""
    OUTPUT_DIRECTORY.mkdir(parents=True, exist_ok=True)
    rng = random.Random(1987)
    for name, duration in EFFECT_DURATIONS:
        generate_effect(name, duration, rng)


if __name__ == "__main__":
    main()
