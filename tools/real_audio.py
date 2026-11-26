#!/usr/bin/env python3
"""Chaos: real recorded sound for the run screens and the Signal Box fight (standards item 6, step 1).

Only CC0 sources (OpenGameArt), so nothing needs a credit in the game; every clip is still logged
in assets/audio/SOURCES.md (a rule test checks each .ogg has a row). Needs ffmpeg + numpy (+ py7zr
for the footsteps archive). Tools never ship.

    python3 tools/real_audio.py            # downloads the sources once, writes assets/audio/*.ogg
    python3 tools/real_audio.py --only shots

Each clip is levelled to a fixed loudness (LOUD, RMS dB) so the mix lives here, not in code.
Web plays audio without bus effects, so any room tail is baked in.
"""
import os
import subprocess
import sys
import urllib.request

import numpy as np

SR = 44100
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "audio")
CACHE = os.path.expanduser("~/.cache/chaos_audio")
OGA = "https://opengameart.org/sites/default/files/"

# cache name -> url (every one CC0, OpenGameArt; page names in SOURCES.md)
SOURCES = {
    "22 Pistol.wav": OGA + "22%20Pistol.wav",
    "sounds.zip": OGA + "sounds.zip",
    "alarm_0.wav": OGA + "alarm_0.wav",
    "static1.wav": OGA + "static1.wav",
    "typewriter1.wav": OGA + "typewriter1.wav",
    "amb_rain_loop_1.ogg": OGA + "amb_rain_loop_1.ogg",
    "25-CC0-bang-sfx.zip": OGA + "25-CC0-bang-sfx.zip",
    "steam_hisses.zip": OGA + "steam_hisses.zip",
    "death pain grunts.wav": OGA + "death%20pain%20grunts.wav",
    "10_clicks_and_switches.zip": OGA + "10_clicks_and_switches.zip",
    "cold_silence.ogg": OGA + "cold_silence.ogg",
    "EmptyCity.ogg": OGA + "EmptyCity.ogg",
    "Fantozzi-footsteps.7z": OGA + "Fantozzi-footsteps.7z",
    "paper_sound_-_1.mp3": OGA + "paper_sound_-_1.mp3",
}


def fetch(name):
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, name)
    if not os.path.exists(path):
        req = urllib.request.Request(SOURCES[name], headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=120) as r, open(path, "wb") as f:
            f.write(r.read())
    return path


def unpack(name, member):
    """A file from inside a zip or 7z source."""
    path = fetch(name)
    out = os.path.join(CACHE, os.path.splitext(name)[0] + ".d")
    if not os.path.isdir(out):
        if name.endswith(".zip"):
            import zipfile
            zipfile.ZipFile(path).extractall(out)
        else:
            import py7zr  # pip install py7zr
            py7zr.SevenZipFile(path).extractall(out)
    for root, _dirs, files in os.walk(out):
        if member in files:
            return os.path.join(root, member)
    raise FileNotFoundError(member)


def load(path, start=0.0, dur=None, channels=1):
    cmd = ["ffmpeg", "-v", "quiet", "-ss", str(start)] + (["-t", str(dur)] if dur else []) + [
        "-i", path, "-ac", str(channels), "-ar", str(SR), "-f", "f32le", "-"]
    x = np.frombuffer(subprocess.run(cmd, capture_output=True, check=True).stdout, np.float32).astype(np.float64)
    return x.reshape(-1, channels).T.copy() if channels > 1 else x


def onsets(x, thresh=0.25, gap=0.15):
    """Sample indexes where the envelope first crosses `thresh` of the peak, at least `gap` s apart."""
    env = np.abs(x)
    lim = thresh * env.max()
    out, last = [], -10 ** 9
    for i in np.flatnonzero(env > lim):
        if i - last > gap * SR:
            out.append(int(i))
        last = i
    return out


def take(x, at, dur, pre=0.005):
    a = max(0, at - int(pre * SR))
    return x[a: a + int(dur * SR)].copy()


def fade(x, fin, fout):
    x = x.copy()
    n_in, n_out = int(fin * SR), int(fout * SR)
    if n_in:
        x[..., :n_in] *= np.linspace(0, 1, n_in)
    if n_out:
        x[..., -n_out:] *= np.linspace(1, 0, n_out) ** 2
    return x


def highpass(x, f):
    X = np.fft.rfft(x)
    fr = np.fft.rfftfreq(x.shape[-1], 1 / SR)
    X[..., fr < f] *= 0.0
    return np.fft.irfft(X, x.shape[-1])


def lowpass(x, f):
    X = np.fft.rfft(x)
    fr = np.fft.rfftfreq(x.shape[-1], 1 / SR)
    X *= 1.0 / np.sqrt(1 + (fr / f) ** 4)
    return np.fft.irfft(X, x.shape[-1])


def yard(x, tail=0.9, wet=0.22, seed=1):
    """A baked slap off the rail-yard walls: decaying noise convolved in, then trimmed."""
    rng = np.random.default_rng(seed)
    n = int(tail * SR)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / (0.18 * SR))
    ir = lowpass(ir, 3000)
    ir /= np.sqrt(np.sum(ir ** 2))
    pad = np.concatenate([x, np.zeros(n)])
    w = np.fft.irfft(np.fft.rfft(pad) * np.fft.rfft(ir, len(pad)), len(pad))
    return pad + wet * w * (np.abs(x).max() / (np.abs(w).max() + 1e-12))


def loopify(x, cross):
    """Seamless loop: the last `cross` seconds fade into the start."""
    n = int(cross * SR)
    body = x[..., :-n].copy()
    head = body[..., :n].copy()
    t = np.linspace(0, 1, n)
    body[..., :n] = head * np.sqrt(t) + x[..., -n:] * np.sqrt(1 - t)
    return body


## Loudness (RMS dB, stereo per channel). Shots sit loudest, the beds well under everything.
LOUD = {"shot": -16.0, "guard_shot": -17.0, "step": -30.0, "hurt": -21.0, "alarm": -21.0,
        "static": -27.0, "flash": -15.0, "smoke": -22.0, "lights": -22.0, "click": -26.0,
        "type": -26.0, "paper": -28.0, "rain_loop": -30.0, "music_fight": -27.0, "music_dossier": -27.0}


def put(name, x, kind=None, q=3):
    """Level to LOUD[kind], soft-limit peaks under 0 dB, write assets/audio/<name>.ogg."""
    target = LOUD[kind or name]
    gain = 10 ** (target / 20) / (np.sqrt(np.mean(x ** 2)) + 1e-12)
    y = 0.8 * np.tanh(x * gain / 0.8)   # headroom: Vorbis overshoots sharp transients
    os.makedirs(OUT, exist_ok=True)
    ch = 2 if y.ndim == 2 else 1
    raw = (y.T if ch == 2 else y).astype(np.float32).tobytes()
    subprocess.run(["ffmpeg", "-v", "quiet", "-y", "-f", "f32le", "-ar", str(SR), "-ac", str(ch), "-i", "-",
                    "-c:a", "libvorbis", "-q:a", str(q), os.path.join(OUT, name + ".ogg")], input=raw, check=True)
    print("wrote", name, "%.2f s" % (y.shape[-1] / SR))


# ------------------------------------------------------------------ the clips

def shots():
    """Ours: a .22 pistol, three takes. Theirs: rifles (SKS, Mosin), heavier, two takes."""
    x = load(fetch("22 Pistol.wav"))
    for i, at in enumerate(onsets(x, 0.3, 0.3)[:3]):
        s = highpass(take(x, at, 0.35), 80)
        put(f"shot_{i}", fade(yard(s, seed=i), 0.001, 0.25), "shot")
    for i, f in enumerate(["sks.wav", "mosin.wav"]):
        x = load(unpack("sounds.zip", f))
        at = onsets(x, 0.3)[0]
        s = highpass(take(x, at, 0.5), 60)
        put(f"guard_shot_{i}", fade(yard(s, seed=10 + i), 0.001, 0.3), "guard_shot")


def steps():
    """Boots on yard gravel, four takes."""
    for i, f in enumerate(["Fantozzi-SandL1.ogg", "Fantozzi-SandR1.ogg", "Fantozzi-SandL2.ogg", "Fantozzi-SandR2.ogg"]):
        x = load(unpack("Fantozzi-footsteps.7z", f))
        x = x[max(0, int(np.argmax(np.abs(x))) - int(0.01 * SR)):][: int(0.4 * SR)]
        put(f"step_{i}", fade(highpass(x, 70), 0.002, 0.1), "step")


def hurt():
    """A man hit: three grunts."""
    x = load(fetch("death pain grunts.wav"))
    for i, t in enumerate([0.53, 4.01, 6.96]):
        s = take(x, int(t * SR), 0.7, pre=0.03)
        put(f"hurt_{i}", fade(highpass(s, 90), 0.01, 0.2), "hurt")


def alarm():
    """The depot alarm: the two-second klaxon twice, far off across the yard."""
    x = load(fetch("alarm_0.wav"))
    x = lowpass(np.concatenate([x, x]), 4500)
    put("alarm", fade(yard(x, 1.2, 0.3, seed=3), 0.02, 0.6))


def radio():
    """Upload/broadcast static and the fake radio call: short bursts of a dead frequency."""
    x = load(fetch("static1.wav"), 10.0, 1.4)
    put("static", fade(lowpass(highpass(x, 300), 3500), 0.03, 0.3))


def tools():
    """Flashbang, smoke canister, lights out (a breaker thrown)."""
    put("flash", fade(yard(load(unpack("25-CC0-bang-sfx.zip", "bang_01.ogg")), 1.0, 0.3, 5), 0.001, 0.4))
    put("smoke", fade(load(unpack("steam_hisses.zip", "steam hisses - Marker #1.wav")), 0.01, 0.5))
    sw = load(unpack("10_clicks_and_switches.zip", "click.5.ogg"))
    put("lights", fade(yard(lowpass(sw, 2500), 0.8, 0.35, 6), 0.001, 0.3))


def ui():
    """A button press, the typewriter key (end turn, stamps) and paper turned over (new screen)."""
    put("click", fade(load(unpack("10_clicks_and_switches.zip", "click.1.ogg")), 0.001, 0.03))
    t = load(fetch("typewriter1.wav"))
    put("type", fade(t[: int(0.3 * SR)], 0.001, 0.1))
    p = load(fetch("paper_sound_-_1.mp3"))
    put("paper", fade(p[: int(min(len(p) / SR, 0.9) * SR)], 0.003, 0.2))


def beds():
    """Rain over the yard (30 s loop) and the two music beds (stereo, looped)."""
    put("rain_loop", loopify(load(fetch("amb_rain_loop_1.ogg"), 5.0, 32.0, channels=2), 2.0), q=1)
    put("music_fight", loopify(load(fetch("cold_silence.ogg"), 20.0, 94.0, channels=2), 4.0), q=1)
    put("music_dossier", loopify(load(fetch("EmptyCity.ogg"), 0.0, 100.0, channels=2), 4.0), q=1)


CLIPS = {"shots": shots, "steps": steps, "hurt": hurt, "alarm": alarm, "radio": radio,
         "tools": tools, "ui": ui, "beds": beds}


def main():
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else None
    for name, fn in CLIPS.items():
        if only is None or only == name:
            fn()


if __name__ == "__main__":
    main()
