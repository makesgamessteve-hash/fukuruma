"""Generates the asset test files in tests/fixtures/assets/data/ (models, textures, sounds, broken files).

usage: python3 tools/models/make_fixtures.py   (from the repository root; needs numpy, Pillow and ffmpeg)
"""
import base64
import os
import struct
import subprocess
import wave

import numpy as np

from gltf import Gltf, box, jpeg, png, quat_x

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "tests", "fixtures", "assets", "data")


def write(rel, data):
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(data)


def checker(n=8):
    y, x = np.mgrid[0:n, 0:n]
    on = (x + y) % 2 == 0
    return np.stack([on * 255, on * 128 + 64, np.full_like(x, 32), np.full_like(x, 255)], -1)


def triangle(g, material=None, uvs=True, normals=True, colors=False):
    p = {"positions": np.array([[0, 0, 0], [1, 0, 0], [0, 1, 0]], float), "indices": np.array([0, 1, 2])}
    if normals:
        p["normals"] = np.array([[0, 0, 1]] * 3, float)
    if uvs:
        p["uvs"] = np.array([[0, 0], [1, 0], [0, 1]], float)
    if colors:
        p["colors"] = np.array([[255, 0, 0, 255], [0, 255, 0, 255], [0, 0, 255, 255]])
    p["material"] = material
    return p


def textures():
    write("textures/checker.png", png(checker()))
    write("textures/checker.jpg", jpeg(checker()[..., :3]))
    write("textures/broken.png", b"\x89PNG\r\n\x1a\nthis is not an image")
    write("textures/wide.png", png(np.zeros((1, 8193, 3))))  # more than 8192 pixels across


def models():
    # tri.gltf: separate .bin and image files, a matrix node under a TRS parent, every texture slot
    g = Gltf()
    tex = g.image(None, uri="tri_base.png")
    mat = g.material("textured", base=(1, 0.5, 0.25, 1), metal=0.5, rough=0.25, emission=(1, 2, 4), base_tex=tex,
                     mr_tex=tex, normal_tex=tex, emission_tex=tex, normal_scale=0.5)
    mesh = g.mesh("tri", [triangle(g, mat, normals=False, colors=True)])
    parent = g.node("parent", translation=(0, 1, 0), rotation=quat_x(np.pi / 2), scale=(2, 2, 2))
    g.node("child", parent=parent, matrix=[1, 0, 0, 0, 0, 0, 1, 0, 0, -1, 0, 0, 3, 0, 0, 1], mesh=mesh)
    for name, diag in (("flip_x", (1, -1, -1)), ("flip_y", (-1, 1, -1)), ("flip_z", (-1, -1, 1))):  # 180 degree turns
        m = np.diag((*diag, 1.0))
        g.node(name, matrix=m.T.flatten())
    write("models/tri.gltf", g.gltf(bin_uri="tri.bin"))
    write("models/tri.bin", bytes(g.bin))
    write("models/tri_base.png", png(checker()))

    # embedded.gltf: buffer and image as data URIs; a primitive without material, indices or normals
    g = Gltf()
    tex = g.image(None, uri="data:image/png;base64," + base64.b64encode(png(checker())).decode())
    mat = g.material("embedded", normal_tex=tex)
    p = triangle(g, mat, normals=False)
    del p["indices"]
    plain = triangle(g)
    del plain["material"]
    g.node("tri", mesh=g.mesh("tri", [p, plain]))
    write("models/embedded.gltf", g.gltf())

    # clip.glb: two joints, a skinned box and clips with step, cubic and linear keys
    g = Gltf()
    prim = box((1, 2, 1), (0, 1, 0))
    prim["joints"] = np.tile([0, 1, 0, 0], (len(prim["positions"]), 1))
    prim["weights"] = np.tile([0.5, 0.5, 0, 0], (len(prim["positions"]), 1))
    mesh = g.mesh("box", [prim])
    root = g.node("root")
    a = g.node("a", parent=root, translation=(0, 0, 0))
    b = g.node("b", parent=a, translation=(0, 1, 0))
    skin = g.skin([a, b], [np.eye(4).flatten(), np.array([[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, -1, 0, 1]], float).flatten()])
    g.node("mesh", parent=root, mesh=mesh, skin=skin)
    g.animation("step", [(b, "translation", [0, 1], [[0, 1, 0], [0, 2, 0]], "STEP")])
    g.animation("cubic", [(b, "rotation", [0, 2], [[0, 0, 0, 0], quat_x(0), [0, 0, 0, 0], [0, 0, 0, 0], quat_x(np.pi / 2), [0, 0, 0, 0]],
                           "CUBICSPLINE")])
    g.animation("linear", [(a, "scale", [0, 0.5, 1], [[1, 1, 1], [2, 2, 2], [1, 1, 1]], "LINEAR")])
    g.animation(None, [(b, "translation", [0, 1], [[0, 1, 0], [0, 1, 0]], "LINEAR")])
    g.doc["animations"][-1].pop("name")
    data = g.glb()
    write("models/clip.glb", data)
    write("models/truncated.glb", data[:100])

    # failures
    g = Gltf()
    line = triangle(g)
    line["mode"] = 1
    g.node("line", mesh=g.mesh("line", [line]))
    write("models/line.gltf", g.gltf())
    g = Gltf()
    g.node("tri", mesh=g.mesh("tri", [triangle(g)]))
    write("models/missing.gltf", g.gltf(bin_uri="missing.bin"))
    write("models/escape.gltf", g.gltf(bin_uri="../../secret.bin"))
    g = Gltf()
    bad = triangle(g)
    bad["indices"] = np.array([0, 1, 7])
    g.node("bad", mesh=g.mesh("bad", [bad]))
    write("models/bad_index.gltf", g.gltf())
    g = Gltf()
    tex = g.image(None, uri="no_such_image.png")
    g.node("tri", mesh=g.mesh("tri", [triangle(g, g.material("m", base_tex=tex))]))
    write("models/missing_image.gltf", g.gltf())
    write("models/not_gltf.glb", b"this is not a model")


def sounds():
    t = np.arange(int(22050 * 0.2)) / 22050
    tone = (np.sin(2 * np.pi * 440 * t) * 12000).astype("<i2")
    with wave.open(os.path.join(OUT, "sounds", "tone.wav"), "wb") as w:
        w.setnchannels(1), w.setsampwidth(2), w.setframerate(22050)
        w.writeframes(tone.tobytes())
    quad = np.repeat(tone[:, None], 4, 1)
    with wave.open(os.path.join(OUT, "sounds", "quad.wav"), "wb") as w:
        w.setnchannels(4), w.setsampwidth(2), w.setframerate(48000)
        w.writeframes(quad.tobytes())
    sounds_dir = os.path.join(OUT, "sounds")
    ff = ["ffmpeg", "-loglevel", "error", "-y", "-f", "lavfi"]
    subprocess.run(ff + ["-i", "sine=frequency=330:sample_rate=44100:duration=0.25", "-ac", "2", "-c:a", "libvorbis",
                         os.path.join(sounds_dir, "tone.ogg")], check=True)
    subprocess.run(ff + ["-i", "anullsrc=r=8000:cl=mono", "-t", "61", "-c:a", "libvorbis", "-q:a", "-1",
                         os.path.join(sounds_dir, "long.ogg")], check=True)
    subprocess.run(ff + ["-i", "sine=frequency=220:sample_rate=48000:duration=0.2", "-ac", "2", "-c:a", "libvorbis",
                         os.path.join(sounds_dir, "music48.ogg")], check=True)
    write("sounds/broken.ogg", b"OggS" + bytes(64))
    write("sounds/broken.wav", b"RIFF" + struct.pack("<I", 4) + b"WAVEjunk")
    write("sounds/notes.txt", b"not a sound")


if __name__ == "__main__":
    os.makedirs(os.path.join(OUT, "sounds"), exist_ok=True)
    textures()
    models()
    sounds()
    for root, _, files in os.walk(OUT):
        for f in sorted(files):
            print(os.path.relpath(os.path.join(root, f), OUT), os.path.getsize(os.path.join(root, f)))
