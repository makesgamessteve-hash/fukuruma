"""Generates the placeholder models in data/models/ (CC BY 4.0, see data/models/CREDITS.md).

usage: python3 tools/models/make_models.py   (from the repository root; needs numpy and Pillow)

- exosuit.glb: the Exosuit (3.6 m), a rigidly skinned mech with 15 joints (the antenna sways on a spring in the game) and the clips idle, walk and run
  (in place; the game moves the body). Painted panels, dark frame, glowing visor.
- ../textures/test_ground.jpg: the test range deck (1 m slabs, repeats every 4 m).
- showcase_materials.glb: five spheres for the materials showcase (plastic, gold, painted panels with a
  normal map, brushed metal with a normal map, an emissive core).
"""
import os

import numpy as np

from gltf import Gltf, box, jpeg, merge, png, quat_axis, quat_mul, quat_x, sphere

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "data", "models")
rng = np.random.default_rng(1983)


# --- textures: 256 x 256 painted panels (they repeat every 2 m) ---------------------------------------

def panel_textures(size=256, panel=64):
    y, x = np.mgrid[0:size, 0:size]
    seam = (x % panel < 2) | (y % panel < 2)
    sub = ((x % (panel // 2) < 1) & (y % panel > panel // 2)) | ((y % (panel // 2) < 1) & (x % panel < panel // 2))
    rivet = ((x % panel - 6) ** 2 + (y % panel - 6) ** 2 < 4) | ((x % panel - panel + 7) ** 2 + (y % panel - 6) ** 2 < 4)
    tone = rng.uniform(0.9, 1.0, (size // panel, size // panel))[y // panel, x // panel]
    grime = rng.normal(0, 0.03, (size, size))
    scratches = np.zeros((size, size))
    for _ in range(60):
        r, c, length = rng.integers(0, size), rng.integers(0, size), rng.integers(6, 30)
        scratches[r, c:c + length] = 1
    lum = tone + grime - 0.45 * seam - 0.15 * sub + 0.08 * scratches
    base = np.stack([lum * 235, lum * 232, lum * 225], -1)
    height = 1.0 - 0.8 * seam - 0.4 * sub + 0.6 * rivet
    gy, gx = np.gradient(height)
    normal = np.stack([-gx * 3, gy * 3, np.ones_like(gx)], -1)  # +v is down in the image: flip y
    normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
    rough = np.clip(0.55 + 0.25 * seam + 0.1 * grime / 0.03 * 0.3 - 0.25 * scratches, 0.2, 1.0)
    mr = np.stack([np.full_like(rough, 1.0), rough, 1.0 - 0.7 * seam], -1)  # R: unused, G: roughness, B: metal
    return png(base), png(mr * 255), png((normal * 0.5 + 0.5) * 255)


def ground_texture(size=256, tile=64):
    """A 4 m test-range deck: 1 m concrete slabs with joints, wear and a yellow line at one edge."""
    y, x = np.mgrid[0:size, 0:size]
    slab = rng.uniform(0.85, 1.0, (size // tile, size // tile))[y // tile, x // tile]
    noise = rng.normal(0, 0.05, (size, size)) + rng.normal(0, 0.03, (size // 8, size // 8)).repeat(8, 0).repeat(8, 1)
    joint = (x % tile < 2) | (y % tile < 2)
    lum = np.clip(slab + noise - 0.35 * joint, 0, 1)
    rgb = np.stack([lum * 150, lum * 146, lum * 138], -1)
    line = (x > 4) & (x < 14)
    rgb[line] = np.stack([lum[line] * 220, lum[line] * 170, lum[line] * 30], -1)
    return rgb


def brushed_textures(size=256):
    streaks = rng.normal(0, 1, (1, size)).repeat(size, 0) * 0.5 + rng.normal(0, 0.3, (size, size))
    rough = np.clip(0.35 + 0.08 * streaks, 0.15, 0.7)
    mr = np.stack([np.ones_like(rough), rough, np.ones_like(rough)], -1)
    gx = np.gradient(streaks, axis=1) * 0.15
    normal = np.stack([-gx, np.zeros_like(gx), np.ones_like(gx)], -1)
    normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
    return png(mr * 255), png((normal * 0.5 + 0.5) * 255)


# --- the Exosuit ------------------------------------------------------------------------------------------

JOINTS = [  # name, parent, position in model space (rest pose)
    ("hips", None, (0, 1.9, 0)), ("spine", "hips", (0, 2.15, 0)), ("chest", "spine", (0, 2.45, 0)),
    ("head", "chest", (0, 3.1, 0)), ("antenna", "head", (0.2, 3.5, -0.15)),
    ("upper_arm_l", "chest", (0.75, 3.0, 0)), ("forearm_l", "upper_arm_l", (0.75, 2.4, 0)),
    ("upper_arm_r", "chest", (-0.75, 3.0, 0)), ("forearm_r", "upper_arm_r", (-0.75, 2.4, 0)),
    ("thigh_l", "hips", (0.3, 1.85, 0)), ("shin_l", "thigh_l", (0.3, 1.0, 0)), ("foot_l", "shin_l", (0.3, 0.2, 0)),
    ("thigh_r", "hips", (-0.3, 1.85, 0)), ("shin_r", "thigh_r", (-0.3, 1.0, 0)), ("foot_r", "shin_r", (-0.3, 0.2, 0)),
]
JOINT = {name: i for i, (name, _, _) in enumerate(JOINTS)}


def parts(side_x):
    """(joint, material, size, centre) for one side; side_x is +1 (left) or -1 (right)."""
    s = side_x
    return [
        (f"upper_arm_{'l' if s > 0 else 'r'}", "accent", (0.5, 0.3, 0.55), (0.78 * s, 3.08, 0)),
        (f"upper_arm_{'l' if s > 0 else 'r'}", "frame", (0.24, 0.62, 0.26), (0.75 * s, 2.7, 0)),
        (f"forearm_{'l' if s > 0 else 'r'}", "hull", (0.32, 0.55, 0.34), (0.75 * s, 2.12, 0.02)),
        (f"forearm_{'l' if s > 0 else 'r'}", "frame", (0.24, 0.26, 0.26), (0.75 * s, 1.72, 0.04)),
        (f"forearm_{'l' if s > 0 else 'r'}", "lamp", (0.06, 0.18, 0.04), (0.75 * s, 2.15, 0.2)),
        (f"thigh_{'l' if s > 0 else 'r'}", "hull", (0.36, 0.8, 0.4), (0.3 * s, 1.45, 0)),
        (f"shin_{'l' if s > 0 else 'r'}", "hull", (0.32, 0.75, 0.36), (0.3 * s, 0.62, -0.02)),
        (f"shin_{'l' if s > 0 else 'r'}", "accent", (0.34, 0.26, 0.14), (0.3 * s, 0.98, 0.2)),
        (f"shin_{'l' if s > 0 else 'r'}", "frame", (0.2, 0.5, 0.12), (0.3 * s, 0.6, -0.24)),
        (f"foot_{'l' if s > 0 else 'r'}", "frame", (0.42, 0.2, 0.72), (0.3 * s, 0.1, 0.1)),
        (f"foot_{'l' if s > 0 else 'r'}", "accent", (0.36, 0.08, 0.2), (0.3 * s, 0.24, 0.32)),
    ]


BODY = [
    ("hips", "frame", (0.92, 0.38, 0.56), (0, 1.9, 0)),
    ("spine", "frame", (0.56, 0.42, 0.44), (0, 2.22, 0)),
    ("chest", "hull", (1.12, 0.72, 0.76), (0, 2.68, 0.02)),
    ("chest", "accent", (0.7, 0.2, 0.1), (0, 2.55, 0.42)),
    ("chest", "lamp", (0.5, 0.05, 0.03), (0, 2.82, 0.415)),
    ("chest", "frame", (0.82, 0.86, 0.36), (0, 2.72, -0.54)),
    ("chest", "accent", (0.2, 0.5, 0.1), (0.28, 2.85, -0.75)),
    ("chest", "accent", (0.2, 0.5, 0.1), (-0.28, 2.85, -0.75)),
    ("head", "hull", (0.52, 0.46, 0.56), (0, 3.33, 0.02)),
    ("head", "visor", (0.44, 0.13, 0.06), (0, 3.36, 0.3)),
    ("head", "frame", (0.12, 0.08, 0.12), (0.2, 3.54, -0.15)),
    ("antenna", "frame", (0.04, 0.62, 0.04), (0.2, 3.85, -0.15)),
    ("antenna", "lamp", (0.07, 0.07, 0.07), (0.2, 4.18, -0.15)),
]


def exosuit():
    g = Gltf()
    base_png, mr_png, normal_png = panel_textures()
    base_tex, mr_tex, normal_tex = g.image(base_png), g.image(mr_png), g.image(normal_png)
    mats = {
        "hull": g.material("hull", base=(0.78, 0.76, 0.7, 1), metal=0.15, rough=1.0, base_tex=base_tex, mr_tex=mr_tex,
                           normal_tex=normal_tex),
        "accent": g.material("accent", base=(0.9, 0.3, 0.04, 1), metal=0.1, rough=1.0, base_tex=base_tex, mr_tex=mr_tex,
                             normal_tex=normal_tex),
        "frame": g.material("frame", base=(0.09, 0.09, 0.1, 1), metal=0.9, rough=0.8, base_tex=base_tex, mr_tex=mr_tex,
                            normal_tex=normal_tex, normal_scale=0.6),
        "visor": g.material("visor", base=(0.02, 0.03, 0.04, 1), metal=0.0, rough=0.08, emission=(0.4, 2.2, 3.2)),
        "lamp": g.material("lamp", base=(0.05, 0.04, 0.03, 1), rough=0.3, emission=(3.0, 1.4, 0.4)),
    }
    by_material = {}
    for joint, mat, size, centre in BODY + parts(1) + parts(-1):
        p = box(size, centre, uv_scale=0.5)
        n = len(p["positions"])
        p["joints"] = np.tile([JOINT[joint], 0, 0, 0], (n, 1))
        p["weights"] = np.tile([1.0, 0, 0, 0], (n, 1))
        by_material.setdefault(mat, []).append(p)
    prims = []
    for mat, ps in by_material.items():
        prim = merge(ps)
        prim["material"] = mats[mat]
        prims.append(prim)
    mesh = g.mesh("exosuit", prims)

    root = g.node("Exosuit")
    nodes = {}
    for name, parent, pos in JOINTS:
        parent_pos = np.array(JOINTS[JOINT[parent]][2] if parent else (0, 0, 0), float)
        nodes[name] = g.node(name, parent=nodes[parent] if parent else root, translation=np.array(pos, float) - parent_pos)
    inverse_bind = []
    for _, _, pos in JOINTS:
        m = np.eye(4)
        m[:3, 3] = -np.array(pos, float)
        inverse_bind.append(m.T.flatten())  # column-major
    skin = g.skin([nodes[name] for name, _, _ in JOINTS], inverse_bind)
    g.node("body", parent=root, mesh=mesh, skin=skin)

    def clip(name, duration, pose, keys=24):
        times = np.linspace(0, duration, keys + 1)
        channels = {}
        for t in times:
            p = 2 * np.pi * t / duration
            for joint, path, value in pose(p):
                channels.setdefault((joint, path), []).append(value)
        g.animation(name, [(nodes[j], path, times, np.array(v), "LINEAR") for (j, path), v in channels.items()])

    rest = {name: np.array(pos, float) - np.array(JOINTS[JOINT[parent]][2] if parent else (0, 0, 0), float)
            for name, parent, pos in JOINTS}

    def legs(p, swing, knee, lift):
        out = []
        for side, phase in (("l", p), ("r", p + np.pi)):
            thigh = -swing * np.sin(phase)
            bend = lift + knee * max(0.0, np.cos(phase)) ** 2
            out += [(f"thigh_{side}", "rotation", quat_x(thigh)), (f"shin_{side}", "rotation", quat_x(bend)),
                    (f"foot_{side}", "rotation", quat_x(-0.7 * (thigh + bend)))]
        return out

    def arms(p, swing, elbow, raise_):
        out = []
        for side, sign in (("l", 1), ("r", -1)):
            a = swing * sign * np.sin(p) - raise_
            out += [(f"upper_arm_{side}", "rotation", quat_mul(quat_axis((0, 0, 1), sign * 0.08), quat_x(a))),
                    (f"forearm_{side}", "rotation", quat_x(-elbow - 0.2 * swing * max(0.0, -sign * np.sin(p))))]
        return out

    def walk(p):
        hips = rest["hips"] + (0, -0.05 * (1 - np.cos(2 * p)), 0)
        return ([("hips", "translation", hips), ("hips", "rotation", quat_axis((0, 1, 0), 0.08 * np.sin(p))),
                 ("chest", "rotation", quat_mul(quat_axis((0, 1, 0), -0.12 * np.sin(p)), quat_x(0.05))),
                 ("head", "rotation", quat_x(-0.03 * np.cos(2 * p)))] + legs(p, 0.45, 0.6, 0.08) + arms(p, 0.35, 0.3, 0.0))

    def run(p):
        hips = rest["hips"] + (0, -0.1 - 0.07 * (1 - np.cos(2 * p)), 0)
        return ([("hips", "translation", hips), ("hips", "rotation", quat_axis((0, 1, 0), 0.12 * np.sin(p))),
                 ("spine", "rotation", quat_x(0.15)),
                 ("chest", "rotation", quat_mul(quat_axis((0, 1, 0), -0.18 * np.sin(p)), quat_x(0.12))),
                 ("head", "rotation", quat_x(-0.2))] + legs(p, 0.75, 1.3, 0.25) + arms(p, 0.7, 0.9, 0.1))

    def idle(p):
        return ([("hips", "translation", rest["hips"] + (0, -0.015 * (1 - np.cos(p)), 0)),
                 ("chest", "rotation", quat_x(0.025 * np.sin(p))),
                 ("head", "rotation", quat_mul(quat_axis((0, 1, 0), 0.25 * np.sin(p)), quat_x(0.04 * np.sin(2 * p)))),
                 ("upper_arm_l", "rotation", quat_mul(quat_axis((0, 0, 1), 0.1), quat_x(0.03 * np.sin(p)))),
                 ("upper_arm_r", "rotation", quat_mul(quat_axis((0, 0, 1), -0.1), quat_x(-0.03 * np.sin(p)))),
                 ("forearm_l", "rotation", quat_x(-0.25)), ("forearm_r", "rotation", quat_x(-0.25))]
                + legs(0.0, 0.0, 0.0, 0.05))

    clip("idle", 4.0, idle, keys=32)
    clip("walk", 1.2, walk)
    clip("run", 0.75, run)
    return g.glb()


def materials_showcase():
    g = Gltf()
    base_png, mr_png, normal_png = panel_textures()
    brushed_mr, brushed_normal = brushed_textures()
    base_tex, mr_tex, normal_tex = g.image(base_png), g.image(mr_png), g.image(normal_png)
    bmr_tex, bn_tex = g.image(brushed_mr), g.image(brushed_normal)
    mats = [
        g.material("plastic", base=(0.75, 0.08, 0.05, 1), rough=0.65),
        g.material("gold", base=(1.0, 0.71, 0.29, 1), metal=1.0, rough=0.22),
        g.material("panels", base=(0.8, 0.78, 0.72, 1), metal=0.15, rough=1.0, base_tex=base_tex, mr_tex=mr_tex,
                   normal_tex=normal_tex),
        g.material("brushed", base=(0.55, 0.56, 0.58, 1), metal=1.0, rough=1.0, mr_tex=bmr_tex, normal_tex=bn_tex),
        g.material("core", base=(0.05, 0.05, 0.06, 1), rough=0.3, emission=(0.6, 2.0, 3.0)),
    ]
    root = g.node("Materials")
    for i, mat in enumerate(mats):
        prim = sphere(0.45, 32, 20)
        prim["material"] = mat
        g.node(f"sphere_{i + 1}", parent=root, translation=((i - 2) * 1.1, 0.45, 0), mesh=g.mesh(f"sphere_{i + 1}", [prim]))
    return g.glb()


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(os.path.join(OUT, "..", "textures"), exist_ok=True)
    with open(os.path.join(OUT, "..", "textures", "test_ground.jpg"), "wb") as f:
        f.write(jpeg(ground_texture(), quality=88))
    for name, data in (("exosuit.glb", exosuit()), ("showcase_materials.glb", materials_showcase())):
        with open(os.path.join(OUT, name), "wb") as f:
            f.write(data)
        print(f"data/models/{name}: {len(data) // 1024} KiB")
