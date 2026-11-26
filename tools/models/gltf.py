"""A small glTF 2.0 writer for generated models (meshes, PBR materials, images, nodes, skins, clips).

Used by make_models.py (game placeholders) and make_fixtures.py (test files). Positions in metres, Y up,
the model faces +Z.
"""
import base64
import io
import json
import struct

import numpy as np

FLOAT, UBYTE, USHORT, UINT = 5126, 5121, 5123, 5125
ARRAY_BUFFER, ELEMENT_ARRAY_BUFFER = 34962, 34963


class Gltf:
    def __init__(self):
        self.doc = {"asset": {"version": "2.0", "generator": "fukuruma tools/models"}, "scene": 0,
                    "scenes": [{"nodes": []}], "nodes": [], "meshes": [], "materials": [], "accessors": [],
                    "bufferViews": [], "buffers": [], "images": [], "textures": [], "samplers": [], "skins": [],
                    "animations": []}
        self.bin = bytearray()

    def _view(self, data, target=None):
        while len(self.bin) % 4:
            self.bin.append(0)
        view = {"buffer": 0, "byteOffset": len(self.bin), "byteLength": len(data)}
        if target:
            view["target"] = target
        self.bin += data
        self.doc["bufferViews"].append(view)
        return len(self.doc["bufferViews"]) - 1

    def accessor(self, array, kind, component=FLOAT, target=None, normalized=False, minmax=False):
        array = np.ascontiguousarray(array)
        dtype = {FLOAT: np.float32, UBYTE: np.uint8, USHORT: np.uint16, UINT: np.uint32}[component]
        data = array.astype(dtype)
        acc = {"bufferView": self._view(data.tobytes(), target), "componentType": component,
               "count": int(len(array)), "type": kind}
        if normalized:
            acc["normalized"] = True
        if minmax:
            flat = data.reshape(len(array), -1)
            acc["min"] = [float(v) for v in flat.min(axis=0)]
            acc["max"] = [float(v) for v in flat.max(axis=0)]
        self.doc["accessors"].append(acc)
        return len(self.doc["accessors"]) - 1

    def image(self, png_bytes, mime="image/png", uri=None):
        """An image stored in the buffer (or referred to by uri, written by the caller)."""
        img = {"uri": uri} if uri else {"bufferView": self._view(png_bytes), "mimeType": mime}
        self.doc["images"].append(img)
        if not self.doc["samplers"]:
            self.doc["samplers"].append({"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497})
        self.doc["textures"].append({"source": len(self.doc["images"]) - 1, "sampler": 0})
        return len(self.doc["textures"]) - 1

    def material(self, name, base=(1, 1, 1, 1), metal=0.0, rough=0.6, emission=(0, 0, 0), base_tex=None,
                 mr_tex=None, normal_tex=None, emission_tex=None, normal_scale=1.0):
        pbr = {"baseColorFactor": list(base), "metallicFactor": metal, "roughnessFactor": rough}
        if base_tex is not None:
            pbr["baseColorTexture"] = {"index": base_tex}
        if mr_tex is not None:
            pbr["metallicRoughnessTexture"] = {"index": mr_tex}
        mat = {"name": name, "pbrMetallicRoughness": pbr, "emissiveFactor": list(emission[:3])}
        if max(emission) > 1:  # KHR_materials_emissive_strength holds the part above 1
            strength = max(emission)
            mat["emissiveFactor"] = [e / strength for e in emission]
            mat["extensions"] = {"KHR_materials_emissive_strength": {"emissiveStrength": strength}}
            self.doc.setdefault("extensionsUsed", []).append("KHR_materials_emissive_strength")
        if normal_tex is not None:
            mat["normalTexture"] = {"index": normal_tex, "scale": normal_scale}
        if emission_tex is not None:
            mat["emissiveTexture"] = {"index": emission_tex}
        self.doc["materials"].append(mat)
        return len(self.doc["materials"]) - 1

    def mesh(self, name, primitives):
        """primitives: list of dicts with positions, normals, uvs, indices, material and optionally
        colors, joints, weights, tangents (numpy arrays)."""
        prims = []
        for p in primitives:
            attrs = {"POSITION": self.accessor(p["positions"], "VEC3", target=ARRAY_BUFFER, minmax=True)}
            if "normals" in p:
                attrs["NORMAL"] = self.accessor(p["normals"], "VEC3", target=ARRAY_BUFFER)
            if "uvs" in p:
                attrs["TEXCOORD_0"] = self.accessor(p["uvs"], "VEC2", target=ARRAY_BUFFER)
            if "tangents" in p:
                attrs["TANGENT"] = self.accessor(p["tangents"], "VEC4", target=ARRAY_BUFFER)
            if "colors" in p:
                attrs["COLOR_0"] = self.accessor(p["colors"], "VEC4", UBYTE, ARRAY_BUFFER, normalized=True)
            if "joints" in p:
                attrs["JOINTS_0"] = self.accessor(p["joints"], "VEC4", UBYTE, ARRAY_BUFFER)
                attrs["WEIGHTS_0"] = self.accessor(p["weights"], "VEC4", target=ARRAY_BUFFER)
            prim = {"attributes": attrs, "mode": p.get("mode", 4)}
            if "indices" in p:
                prim["indices"] = self.accessor(p["indices"], "SCALAR", USHORT if len(p["positions"]) < 65536 else UINT,
                                                ELEMENT_ARRAY_BUFFER)
            if p.get("material") is not None:
                prim["material"] = p["material"]
            prims.append(prim)
        self.doc["meshes"].append({"name": name, "primitives": prims})
        return len(self.doc["meshes"]) - 1

    def node(self, name, parent=None, translation=None, rotation=None, scale=None, matrix=None, mesh=None, skin=None):
        n = {"name": name}
        if translation is not None:
            n["translation"] = [float(v) for v in translation]
        if rotation is not None:
            n["rotation"] = [float(v) for v in rotation]
        if scale is not None:
            n["scale"] = [float(v) for v in scale]
        if matrix is not None:
            n["matrix"] = [float(v) for v in matrix]
        if mesh is not None:
            n["mesh"] = mesh
        if skin is not None:
            n["skin"] = skin
        self.doc["nodes"].append(n)
        index = len(self.doc["nodes"]) - 1
        if parent is None:
            self.doc["scenes"][0]["nodes"].append(index)
        else:
            self.doc["nodes"][parent].setdefault("children", []).append(index)
        return index

    def skin(self, joints, inverse_bind):
        self.doc["skins"].append({"joints": joints, "inverseBindMatrices": self.accessor(np.array(inverse_bind), "MAT4")})
        return len(self.doc["skins"]) - 1

    def animation(self, name, channels):
        """channels: list of (node, path, times, values, interpolation)."""
        anim = {"name": name, "channels": [], "samplers": []}
        for node, path, times, values, interp in channels:
            kind = "VEC4" if path == "rotation" else "VEC3"
            sampler = {"input": self.accessor(np.array(times), "SCALAR", minmax=True),
                       "output": self.accessor(np.array(values), kind), "interpolation": interp}
            anim["samplers"].append(sampler)
            anim["channels"].append({"sampler": len(anim["samplers"]) - 1, "target": {"node": node, "path": path}})
        self.doc["animations"].append(anim)

    def _finish(self):
        doc = {k: v for k, v in self.doc.items() if v != []}
        if self.bin:
            doc["buffers"] = [{"byteLength": len(self.bin)}]
        return doc

    def glb(self):
        doc = self._finish()
        js = json.dumps(doc, separators=(",", ":")).encode()
        js += b" " * (-len(js) % 4)
        binary = bytes(self.bin) + b"\0" * (-len(self.bin) % 4)
        total = 12 + 8 + len(js) + (8 + len(binary) if binary else 0)
        out = struct.pack("<4sII", b"glTF", 2, total) + struct.pack("<I4s", len(js), b"JSON") + js
        if binary:
            out += struct.pack("<I4s", len(binary), b"BIN\0") + binary
        return out

    def gltf(self, bin_uri=None):
        """A .gltf JSON document; the buffer goes to bin_uri (written by the caller) or into a data URI."""
        doc = self._finish()
        if self.bin:
            doc["buffers"][0]["uri"] = bin_uri or "data:application/octet-stream;base64," + base64.b64encode(bytes(self.bin)).decode()
        return json.dumps(doc, indent=1).encode()


def png(rgb_or_rgba):
    from PIL import Image
    arr = np.clip(np.asarray(rgb_or_rgba), 0, 255).astype(np.uint8)
    buf = io.BytesIO()
    Image.fromarray(arr).save(buf, format="PNG", optimize=True)
    return buf.getvalue()


def jpeg(rgb, quality=90):
    from PIL import Image
    buf = io.BytesIO()
    Image.fromarray(np.clip(np.asarray(rgb), 0, 255).astype(np.uint8)).save(buf, format="JPEG", quality=quality)
    return buf.getvalue()


def box(size, center=(0, 0, 0), uv_scale=1.0):
    """A box with flat faces: positions, normals, uvs (metres times uv_scale) and tangents, indices."""
    sx, sy, sz = [s / 2 for s in size]
    faces = [  # normal, tangent (u direction), bitangent (v direction); tangent x bitangent = normal (CCW faces)
        ((1, 0, 0), (0, 0, -1), (0, 1, 0)), ((-1, 0, 0), (0, 0, 1), (0, 1, 0)),
        ((0, 1, 0), (1, 0, 0), (0, 0, -1)), ((0, -1, 0), (1, 0, 0), (0, 0, 1)),
        ((0, 0, 1), (1, 0, 0), (0, 1, 0)), ((0, 0, -1), (-1, 0, 0), (0, 1, 0)),
    ]
    half = np.array([sx, sy, sz])
    pos, nor, uv, tan, idx = [], [], [], [], []
    for n, t, b in faces:
        n, t, b = np.array(n, float), np.array(t, float), np.array(b, float)
        base = len(pos)
        for su, sv in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            p = n * half + t * half * su + b * half * sv
            pos.append(p + np.asarray(center, float))
            nor.append(n)
            uv.append(((p @ t) * uv_scale, (p @ b) * uv_scale))
            tan.append((*t, 1.0))
        idx += [base, base + 1, base + 2, base, base + 2, base + 3]
    return {"positions": np.array(pos), "normals": np.array(nor), "uvs": np.array(uv), "tangents": np.array(tan),
            "indices": np.array(idx)}


def sphere(radius, segments=24, rings=16):
    pos, nor, uv, tan, idx = [], [], [], [], []
    for r in range(rings + 1):
        theta = np.pi * r / rings
        for s in range(segments + 1):
            phi = 2 * np.pi * s / segments
            n = np.array([np.sin(theta) * np.sin(phi), np.cos(theta), np.sin(theta) * np.cos(phi)])
            pos.append(n * radius)
            nor.append(n)
            uv.append((s / segments * 4, r / rings * 2))
            tan.append((np.cos(phi), 0, -np.sin(phi), -1.0))  # v grows downwards: the bitangent is -(n x t)
    for r in range(rings):
        for s in range(segments):
            a, b = r * (segments + 1) + s, (r + 1) * (segments + 1) + s
            idx += [a, b, a + 1, a + 1, b, b + 1]
    return {"positions": np.array(pos), "normals": np.array(nor), "uvs": np.array(uv), "tangents": np.array(tan),
            "indices": np.array(idx)}


def merge(parts):
    """Concatenates mesh parts (dicts of arrays); indices are offset."""
    out, offset = {}, 0
    for p in parts:
        for k, v in p.items():
            v = v + offset if k == "indices" else v
            out.setdefault(k, []).append(v)
        offset += len(p["positions"])
    return {k: np.concatenate(v) for k, v in out.items()}


def quat_x(angle):
    return (np.sin(angle / 2), 0.0, 0.0, np.cos(angle / 2))


def quat_mul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return (aw * bx + ax * bw + ay * bz - az * by, aw * by - ax * bz + ay * bw + az * bx,
            aw * bz + ax * by - ay * bx + az * bw, aw * bw - ax * bx - ay * by - az * bz)


def quat_axis(axis, angle):
    axis = np.asarray(axis, float) / np.linalg.norm(axis)
    s = np.sin(angle / 2)
    return (axis[0] * s, axis[1] * s, axis[2] * s, np.cos(angle / 2))
