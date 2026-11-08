"""Render a dark industrial soundtrack sketch from the user-supplied reference.

The bass, rhythm and metallic motif are newly sequenced. Short fragments of the
reference are granulated into background textures; this is a reference-based
variation, not an independently cleared original recording.
"""
from pathlib import Path
import json
import subprocess

import imageio_ffmpeg
import numpy as np
from scipy import signal

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(r"D:\staacher\游戏《恶魔轮盘⧸Buckshot Roulette》原声带（OST）.m4a")
FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
SR = 48000
BPM = 110
BEAT = 60 / BPM
BAR = 4 * BEAT
BARS = 56
DURATION = BARS * BAR + 2 * BAR
N = round(DURATION * SR)
rng = np.random.default_rng(200811)


def time_axis(seconds):
    return np.arange(round(seconds * SR), dtype=np.float32) / SR


def lowpass(x, hz, order=2):
    return signal.sosfilt(signal.butter(order, hz, fs=SR, output="sos"), x, axis=0).astype(np.float32)


def highpass(x, hz, order=2):
    return signal.sosfilt(signal.butter(order, hz, fs=SR, btype="highpass", output="sos"), x, axis=0).astype(np.float32)


def fade(x, attack=.008, release=.05):
    x = x.copy()
    a = min(round(attack * SR), len(x))
    r = min(round(release * SR), len(x))
    x[:a] *= np.linspace(0, 1, a, dtype=np.float32)
    x[-r:] *= np.linspace(1, 0, r, dtype=np.float32)
    return x


def place(bus, sound, seconds, gain=1., pan=0.):
    i = round(seconds * SR)
    count = min(len(sound), len(bus) - i)
    if count <= 0:
        return
    s = sound[:count] * gain
    if s.ndim == 1:
        bus[i:i + count, 0] += s * np.sqrt((1 - pan) / 2)
        bus[i:i + count, 1] += s * np.sqrt((1 + pan) / 2)
    else:
        bus[i:i + count] += s


def hz(midi):
    return 440 * 2 ** ((midi - 69) / 12)


def kick():
    t = time_axis(.75)
    f = 43 + 97 * np.exp(-t * 42) + 6 * np.exp(-t * 5)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 8)
    knock = highpass(rng.normal(0, 1, len(t)).astype(np.float32), 1200) * np.exp(-t * 180)
    return fade(np.tanh(body * 1.8) * .72 + knock * .075, .001, .08)


def snare():
    t = time_axis(.52)
    noise = rng.normal(0, 1, len(t)).astype(np.float32)
    skin = lowpass(highpass(noise, 550), 5300)
    wire = lowpass(highpass(noise, 2500), 7200)
    ring = np.sin(2 * np.pi * 161 * t) + .45 * np.sin(2 * np.pi * 227 * t)
    flam = np.zeros_like(t)
    for offset, amp in [(0, .8), (.013, .45), (.029, .24)]:
        k = round(offset * SR)
        flam[k:] += amp * skin[:len(t) - k] * np.exp(-t[:len(t) - k] * 18)
    return fade(np.tanh((flam + .16 * ring * np.exp(-t * 26)) * 1.5) * .32
                + .07 * wire * np.exp(-t * 10), .001, .08)


def hat(open_hat=False):
    t = time_axis(.30 if open_hat else .09)
    noise = rng.normal(0, 1, len(t)).astype(np.float32)
    metallic = sum(np.sign(np.sin(2 * np.pi * f * t)) for f in [1873, 2761, 4081]) / 3
    s = highpass(.5 * noise + .4 * metallic, 5700)
    return fade(s * np.exp(-t * (15 if open_hat else 65)) * .13, .001, .025)


def metal(midi, seconds=2.3):
    t = time_axis(seconds)
    f = hz(midi)
    s = np.zeros(len(t), dtype=np.float32)
    for ratio, gain, decay in [(1, 1, 2.1), (2.76, .43, 3.4), (4.12, .21, 5.6), (6.31, .11, 8)]:
        s += gain * np.sin(2 * np.pi * f * ratio * t + .8 * np.sin(2 * np.pi * 1.8 * t)) * np.exp(-t * decay)
    return fade(lowpass(s, 4200) * .22, .002, .2)


def bass(midi, length, brightness=1):
    t = time_axis(length + .13)
    f = hz(midi)
    # Detuned saws, a sine fundamental, and a short opening of the upper filter.
    s = (signal.sawtooth(2 * np.pi * f * .997 * t)
         + signal.sawtooth(2 * np.pi * f * 1.003 * t + .43)) * .32
    sub = np.sin(2 * np.pi * f * t) * .65
    dark = lowpass(s, 170)
    bright = lowpass(s, 1050 * brightness)
    transient = np.exp(-t * 9) * .60 + .16
    voice = dark * .5 + bright * transient + sub * .55
    voice = np.tanh(voice * 2.4) * .42
    return fade(voice * (.80 + .20 * np.exp(-t * 2.5)), .008, .12)


def echo(bus, taps):
    wet = np.zeros_like(bus)
    for seconds, gain, swap in taps:
        d = round(seconds * SR)
        wet[d:] += (bus[:-d, ::-1] if swap else bus[:-d]) * gain
    return wet


def chamber(bus, decay=2.6, wet=.24):
    # A dark, diffuse stereo room; direct transients remain in the dry bus.
    m = round(decay * SR)
    t = np.arange(m, dtype=np.float32) / SR
    impulse = rng.normal(0, 1, (m, 2)).astype(np.float32)
    impulse = lowpass(impulse, 2800) * np.exp(-6.8 * t[:, None] / decay)
    impulse[:round(.035 * SR)] = 0
    impulse *= .055 / (np.sqrt(np.sum(impulse ** 2, axis=0)) + 1e-8)
    result = np.empty_like(bus)
    for ch in range(2):
        result[:, ch] = signal.fftconvolve(bus[:, ch], impulse[:, ch], mode="full")[:N]
    result += echo(lowpass(bus, 2300), [(.071, .20, True), (.127, .15, False), (.239, .10, True)])
    return bus + result * wet


def read_reference(start, seconds=16):
    p = subprocess.run([FFMPEG, "-v", "error", "-ss", str(start), "-t", str(seconds),
                        "-i", str(SOURCE), "-ac", "1", "-ar", str(SR),
                        "-f", "f32le", "pipe:1"], capture_output=True, check=True)
    return np.frombuffer(p.stdout, dtype=np.float32).copy()


def granular_fragment(source, duration, ratio, reverse=False):
    # Overlapping, relocated grains destroy the reference phrase and its beat.
    n = round(duration * SR)
    result = np.zeros(n, dtype=np.float32)
    weights = np.zeros(n, dtype=np.float32)
    size = round(.82 * SR)
    window = np.hanning(size).astype(np.float32)
    for position in range(-size // 2, n, round(.21 * SR)):
        origin = rng.integers(0, len(source) - round(size * ratio) - 2)
        idx = origin + np.arange(size) * ratio
        grain = np.interp(idx, np.arange(len(source)), source).astype(np.float32)
        if reverse:
            grain = grain[::-1]
        a, b = max(0, position), min(n, position + size)
        ga, gb = a - position, b - position
        result[a:b] += grain[ga:gb] * window[ga:gb]
        weights[a:b] += window[ga:gb]
    result /= np.maximum(weights, .1)
    result = lowpass(highpass(np.tanh(result * 2), 210), 2100)
    result /= max(np.sqrt(np.mean(result * result)), .001)
    return fade(result * .045, .8, 1.8)


def compose():
    drums = np.zeros((N, 2), np.float32)
    low = np.zeros_like(drums)
    air = np.zeros_like(drums)
    bells = np.zeros_like(drums)
    k, s = kick(), snare()
    hats = [hat(), hat(), hat(True)]
    kicks = []

    # D Phrygian: the semitone above the root keeps the harmony unresolved.
    riffs = [
        [(0, 26, .65), (1.5, 26, .32), (2.5, 38, .36), (3.25, 27, .36)],
        [(0, 26, 1.05), (1.75, 33, .32), (2.5, 26, .58), (3.5, 24, .30)],
        [(0, 26, .65), (1.5, 27, .32), (2.5, 26, .36), (3.25, 33, .36)],
        [(0, 26, 1.05), (1.5, 38, .32), (2.5, 24, .56), (3.5, 27, .30)],
    ]
    for bar in range(BARS):
        at = bar * BAR
        intro = bar < 4
        sparse = 4 <= bar < 12 or 24 <= bar < 28 or 48 <= bar < 52
        outro = bar >= 52
        active = not (intro or outro)
        drive = .56 if sparse else .86
        if active:
            positions = [0, 2.75] if sparse else [0, 1.5, 2.75]
            if 40 <= bar < 48 and bar % 2:
                positions += [3.5]
            if bar in [11, 23, 27, 39, 47, 51]:
                positions = positions[:1]
            for beat in positions:
                position = at + beat * BEAT
                place(drums, k, position, drive)
                kicks.append(position)
            if not sparse:
                place(drums, s, at + 2 * BEAT, .80, -.06)
                if bar % 4 == 3:
                    place(drums, s, at + 3.75 * BEAT, .22, .10)
            if bar >= 8 and not 24 <= bar < 28:
                for step in range(8):
                    if sparse and step % 2 == 0:
                        continue
                    offset = .018 if step % 2 else 0
                    sample = hats[2 if step == 7 and not sparse else step % 2]
                    place(drums, sample, at + step * BEAT / 2 + offset,
                          (.36 if sparse else .64) * (1 if step % 2 else .65),
                          -.23 if step % 2 else .30)
            pattern = riffs[(bar + (2 if 28 <= bar < 48 else 0)) % 4]
            if sparse:
                pattern = pattern[:1] if bar % 2 == 0 else [(0, 26, 1.5), (3, 27, .45)]
            for beat, note, length in pattern:
                place(low, bass(note, length * BEAT, 1.2 if 40 <= bar < 48 else 1),
                      at + beat * BEAT + .006, .58 if sparse else .84)

        # Sparse metal answers: no continuous lead melody over the gambling table.
        if bar % 4 == 0:
            place(bells, metal(62 if bar % 8 == 0 else 63, 4), at + .75 * BEAT,
                  .30 if intro or outro else .52, -.42)
        if 12 <= bar < 48 and bar % 4 == 2:
            place(bells, metal(69, 3), at + 3.25 * BEAT, .30, .42)
            place(bells, metal(63, 2), at + 3.75 * BEAT, .14, -.28)
        if bar in [11, 23, 27, 39, 47, 51]:
            # A reverse inhalation followed by a small, dry mechanical catch.
            swell = fade(metal(50, 2)[::-1], .2, .025)
            place(bells, swell, at + BAR - 2, .48, -.12)
            place(drums, highpass(metal(81, .18), 1500), at + BAR - .065, .5, .20)

    print("Rhythm and bass rendered", flush=True)

    # An unstable motor hum and two detuned room resonances.
    t = np.arange(N, dtype=np.float32) / SR
    motion = .72 + .17 * np.sin(2 * np.pi * .09 * t) + .08 * np.sin(2 * np.pi * .037 * t)
    for ch, detune in enumerate([-.0009, .0009]):
        hum = np.sin(2 * np.pi * hz(26) * (1 + detune) * t + .08 * np.sin(2 * np.pi * .13 * t))
        hum += .35 * np.sin(2 * np.pi * hz(38) * (1 - detune) * t)
        unease = np.sin(2 * np.pi * hz(51) * (1 + detune) * t + .5 * np.sin(2 * np.pi * .06 * t))
        unease += .50 * np.sin(2 * np.pi * hz(57) * (1 - detune) * t)
        air[:, ch] += (.025 * hum + .009 * unease) * motion

    # Quiet recycled reference texture, with no unaltered full musical passage.
    reference_starts = [41, 159, 329, 471]
    fragments = [read_reference(start) for start in reference_starts]
    for bar in range(0, BARS, 4):
        index = (bar // 4) % len(fragments)
        texture = granular_fragment(fragments[index], 4 * BAR + 1, 2 ** (-5 / 12), bar % 8 == 0)
        intensity = .34 if 12 <= bar < 24 or 28 <= bar < 48 else .65
        place(air, texture, bar * BAR, intensity, -.32 if bar % 8 else .32)
    print("Reference fragments reworked", flush=True)

    # New filtered ventilation noise, faint dropouts, and slow pressure swells.
    noise = rng.normal(0, 1, (N, 2)).astype(np.float32)
    noise = lowpass(highpass(noise, 500), 3300)
    air += noise * (.012 + .007 * np.sin(2 * np.pi * .074 * t)[:, None])
    for bar in [10, 22, 26, 38, 46, 50]:
        tt = time_axis(2 * BAR)
        rise = highpass(rng.normal(0, 1, len(tt)).astype(np.float32), 900)
        rise = lowpass(rise, 4000) * (tt / tt[-1]) ** 3 * .035
        place(air, fade(rise, .4, .05), bar * BAR, 1, .12)

    # Bass moves aside at kick transients; the very lowest frequencies stay mono.
    duck = np.ones(N, np.float32)
    tt = time_axis(.40)
    recovery = 1 - .61 * np.exp(-tt * 13)
    for position in kicks:
        a = round(position * SR)
        b = min(N, a + len(recovery))
        duck[a:b] = np.minimum(duck[a:b], recovery[:b - a])
    low *= duck[:, None]
    air *= (.78 + .22 * duck[:, None])

    bells = chamber(bells + echo(bells, [(BEAT * .75, .25, True), (BEAT * 1.5, .11, False)]), 3.5, .70)
    air = chamber(air, 2.8, .50)
    drums = chamber(drums, .65, .12)
    mix = drums + low + air + bells

    # A brief intake of silence before the final, denser return.
    a = round((28 * BAR - .12) * SR)
    b = round(28 * BAR * SR)
    mix[a:a + round(.02 * SR)] *= np.linspace(1, .03, round(.02 * SR))[:, None]
    mix[a + round(.02 * SR):b - round(.008 * SR)] *= .03
    mix[b - round(.008 * SR):b] *= np.linspace(.03, 1, round(.008 * SR))[:, None]

    mix = highpass(mix, 26)
    center = mix.mean(axis=1)
    side = highpass((mix[:, 0] - mix[:, 1]) * .5, 150)
    mix[:, 0] = center + side
    mix[:, 1] = center - side
    # Gentle tape rounding, with a fixed gain rather than clipping peaks.
    mix = np.tanh(mix * 1.15) / 1.15
    attack = round(1.8 * SR)
    release = round(2 * BAR * SR)
    mix[:attack] *= np.sin(np.linspace(0, np.pi / 2, attack))[:, None] ** 2
    mix[-release:] *= np.cos(np.linspace(0, np.pi / 2, release))[:, None] ** 2
    mix -= mix.mean(axis=0, keepdims=True)
    mix[0] = 0
    mix[-1] = 0
    return mix.astype(np.float32)


def export(mix):
    name = "地下赌局_锈蚀心跳_变奏试听"
    raw = ROOT / "制作文件" / "premaster.f32"
    mix.astype("<f4").tofile(raw)
    # Two-pass EBU R128 measurement and normalization; target is -16 LUFS.
    common = [FFMPEG, "-hide_banner", "-nostats", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", str(raw)]
    measured = subprocess.run(common + ["-af", "loudnorm=I=-16:TP=-1.5:LRA=9:print_format=json", "-f", "null", "-"], capture_output=True, text=True, encoding="utf-8", errors="replace", check=True)
    stats = json.JSONDecoder().raw_decode(measured.stderr[measured.stderr.rfind("{"):])[0]
    normalizer = ("loudnorm=I=-16:TP=-1.5:LRA=9:linear=true:"
                  f"measured_I={stats['input_i']}:measured_TP={stats['input_tp']}:"
                  f"measured_LRA={stats['input_lra']}:measured_thresh={stats['input_thresh']}:"
                  f"offset={stats['target_offset']}:print_format=json")
    wav = ROOT / f"{name}.wav"
    mastered = subprocess.run(common + ["-y", "-af", normalizer, "-ar", str(SR),
                                        "-c:a", "pcm_s24le", str(wav)], capture_output=True, text=True, encoding="utf-8", errors="replace", check=True)
    mastering_stats = json.JSONDecoder().raw_decode(mastered.stderr[mastered.stderr.rfind("{"):])[0]
    subprocess.run([FFMPEG, "-v", "error", "-y", "-i", str(wav), "-c:a", "libmp3lame", "-b:a", "256k",
                    "-metadata", "title=锈蚀心跳 · 地下赌局", "-metadata", "artist=Reference-based variation sketch",
                    str(ROOT / f"{name}.mp3")], check=True)
    report = {"bpm": BPM, "duration_seconds": DURATION, "sample_rate": SR, "wav_bits": 24,
              "reference": str(SOURCE), "reference_fragments_start_seconds": [41, 159, 329, 471],
              "mastering": mastering_stats,
              "sections": [{"start_s": round(a * BAR, 3), "end_s": round(b * BAR, 3), "description": label}
                           for a, b, label in [(0, 4, "进入地下空间"), (4, 12, "落座与试探"),
                                              (12, 24, "赌局主节奏"), (24, 28, "抽空与等待"),
                                              (28, 40, "变奏再入"), (40, 48, "筹码加压"),
                                              (48, 56, "抽离与悬置")]]}
    (ROOT / "制作文件" / "render_report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    raw.unlink()
    print(json.dumps(report, ensure_ascii=False), flush=True)
    print(f"Saved: {wav}", flush=True)


if __name__ == "__main__":
    export(compose())
