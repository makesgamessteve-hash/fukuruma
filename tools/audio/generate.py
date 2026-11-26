"""Generates the game's sound effects and music with the ElevenLabs API (see docs/IMPLEMENTATION_PLAN.md 3.12).

usage: ELEVENLABS_API_KEY=... python3 tools/audio/generate.py [--dry-run] [--only ID ...]
       (from the repository root; needs ffmpeg with libvorbis)

Reads tools/audio/prompts.json. Only entries whose prompt, length or settings changed since the last run
(their hashes are in tools/audio/generated.json) are generated again. Results are converted to OGG Vorbis at
48 kHz (sound effects mono, music stereo) and written under data/; data/sounds/CREDITS.md and
data/music/CREDITS.md record where each file came from. The key is read from the environment and never stored.
"""
import argparse
import datetime
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
PROMPTS = os.path.join(ROOT, "tools", "audio", "prompts.json")
LOCK = os.path.join(ROOT, "tools", "audio", "generated.json")
API = "https://api.elevenlabs.io"


def entry_hash(entry):
    return hashlib.sha256(json.dumps(entry, sort_keys=True).encode()).hexdigest()[:16]


def request(path, body, key):
    req = urllib.request.Request(API + path, data=json.dumps(body).encode(), method="POST",
                                 headers={"xi-api-key": key, "Content-Type": "application/json", "Accept": "audio/*"})
    try:
        with urllib.request.urlopen(req, timeout=600) as response:
            return response.read()
    except urllib.error.HTTPError as e:
        raise SystemExit(f"ElevenLabs refused {path}: {e.code} {e.read().decode(errors='replace')[:400]}")


def generate(entry, key):
    if entry["kind"] == "sfx":
        body = {"text": entry["prompt"], "duration_seconds": entry["seconds"], "loop": entry.get("loop", False),
                "prompt_influence": entry.get("influence", 0.4), "model_id": "eleven_text_to_sound_v2"}
        return request("/v1/sound-generation?output_format=wav_48000", body, key), ".wav"
    body = {"prompt": entry["prompt"], "music_length_ms": int(entry["seconds"] * 1000), "force_instrumental": True,
            "model_id": "music_v1"}
    return request("/v1/music?output_format=mp3_48000_192", body, key), ".mp3"


def to_ogg(data, suffix, target, channels, quality):
    with tempfile.TemporaryDirectory() as tmp:
        source = os.path.join(tmp, "in" + suffix)
        with open(source, "wb") as f:
            f.write(data)
        os.makedirs(os.path.dirname(target), exist_ok=True)
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", source, "-ac", str(channels), "-ar", "48000",
                        "-af", "loudnorm=I=-18:TP=-1.5", "-c:a", "libvorbis", "-q:a", str(quality), target], check=True)


def write_credits(entries, lock):
    for folder, kind, title in (("sounds", "sfx", "Sound credits"), ("music", "music", "Music credits")):
        rows = [e for e in entries if e["kind"] == kind and e["id"] in lock]
        if not rows:
            continue
        lines = [f"# {title}", "",
                 "Generated for this project with the ElevenLabs API by `tools/audio/generate.py` from the prompts in",
                 "`tools/audio/prompts.json`, on the project owner's ElevenLabs account. Licence: CC BY 4.0 (see",
                 "`LICENSE-ASSETS.md`), as far as the owner's ElevenLabs plan allows publishing generated audio.", ""]
        model = "eleven_text_to_sound_v2" if kind == "sfx" else "music_v1"
        for e in rows:
            lines.append(f"- `{os.path.basename(e['path'])}` ({model}, {lock[e['id']]['date']}): {e['prompt']}")
        with open(os.path.join(ROOT, "data", folder, "CREDITS.md"), "w") as f:
            f.write("\n".join(lines) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--dry-run", action="store_true", help="list what would be generated")
    parser.add_argument("--only", nargs="*", help="generate only these ids (when changed)")
    args = parser.parse_args()
    entries = json.load(open(PROMPTS))
    ids = [e["id"] for e in entries]
    if len(ids) != len(set(ids)):
        raise SystemExit("prompts.json: ids must be unique")
    lock = json.load(open(LOCK)) if os.path.exists(LOCK) else {}
    todo = [e for e in entries if lock.get(e["id"], {}).get("hash") != entry_hash(e)
            or not os.path.exists(os.path.join(ROOT, "data", e["path"]))]
    if args.only:
        todo = [e for e in todo if e["id"] in args.only]
    for e in todo:
        print(f"{'would generate' if args.dry_run else 'generating'} {e['id']} ({e['kind']}, {e['seconds']} s)")
    if args.dry_run or not todo:
        return
    key = os.environ.get("ELEVENLABS_API_KEY")
    if not key:
        raise SystemExit("set ELEVENLABS_API_KEY")
    for e in todo:
        data, suffix = generate(e, key)
        to_ogg(data, suffix, os.path.join(ROOT, "data", e["path"]), 1 if e["kind"] == "sfx" else 2,
               4 if e["kind"] == "sfx" else 3)
        lock[e["id"]] = {"hash": entry_hash(e), "date": datetime.date.today().isoformat()}
        with open(LOCK, "w") as f:  # after every file, so an interrupted run keeps what it made
            json.dump(lock, f, indent=1, sort_keys=True)
        print(f"  wrote data/{e['path']}")
    write_credits(entries, lock)


if __name__ == "__main__":
    sys.exit(main())
