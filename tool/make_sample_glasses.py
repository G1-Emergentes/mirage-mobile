"""
Genera GLB de lentes de PRUEBA con el mismo contrato que virtual-try-on-service:
  - metros, glTF (Y arriba, el frente mira a +Z)
  - ancho total 14 cm en X
  - origen (0,0,0) en el centro del puente a la altura del centro de los cristales,
    en el plano frontal del marco (la app lo lleva al landmark 6 de MediaPipe)
  - patillas recortadas (en RA las tapa la cabeza)
Uso: python make_sample_glasses.py <carpeta_salida>
"""
import sys
from pathlib import Path

import numpy as np
import trimesh
from trimesh.visual.material import PBRMaterial

TUBE = 0.0025          # radio del perfil del marco
LENS_CX = 0.034        # centro de cada cristal
WIDTH = 0.14


def tube(points, radius, closed, segments=12):
    pts = np.asarray(points, float)
    n = len(pts)
    verts, faces = [], []
    for i in range(n):
        prev_p = pts[i - 1] if (closed or i > 0) else pts[i]
        next_p = pts[(i + 1) % n] if (closed or i < n - 1) else pts[i]
        t = next_p - prev_p
        t /= np.linalg.norm(t)
        ref = np.array([0, 0, 1.0]) if abs(t[2]) < 0.9 else np.array([0, 1.0, 0])
        u = np.cross(t, ref); u /= np.linalg.norm(u)
        v = np.cross(t, u)
        for k in range(segments):
            a = 2 * np.pi * k / segments
            verts.append(pts[i] + radius * (np.cos(a) * u + np.sin(a) * v))
    rings = n if closed else n - 1
    for i in range(rings):
        j = (i + 1) % n
        for k in range(segments):
            k2 = (k + 1) % segments
            a, b = i * segments + k, i * segments + k2
            c, d = j * segments + k2, j * segments + k
            faces += [[a, b, c], [a, c, d]]
    verts = np.array(verts)
    if not closed:  # tapas
        for idx, sign in ((0, -1), (n - 1, 1)):
            centre = len(verts)
            verts = np.vstack([verts, pts[idx]])
            for k in range(segments):
                a, b = idx * segments + k, idx * segments + (k + 1) % segments
                faces.append([centre, b, a] if sign < 0 else [centre, a, b])
    return trimesh.Trimesh(verts, np.array(faces), process=True)


def lens_outline(cx, half_w, half_h, exponent, n=72):
    """Superelipse: exponent 2 = redondo/ovalado, 4-6 = rectangular."""
    a = np.linspace(0, 2 * np.pi, n, endpoint=False)
    c, s = np.cos(a), np.sin(a)
    x = half_w * np.sign(c) * np.abs(c) ** (2 / exponent)
    y = half_h * np.sign(s) * np.abs(s) ** (2 / exponent)
    return np.column_stack([cx + x, y, np.zeros(n)])


def lens_disc(outline):
    centre = outline.mean(0)
    verts = np.vstack([centre, outline])
    n = len(outline)
    faces = [[0, 1 + i, 1 + (i + 1) % n] for i in range(n)]
    return trimesh.Trimesh(verts, faces, process=True)


def build(half_w, half_h, exponent, frame_rgba, metallic, roughness, lens_rgba):
    parts = []
    lenses = []
    for side in (-1, 1):
        outline = lens_outline(side * LENS_CX, half_w, half_h, exponent)
        parts.append(tube(outline, TUBE, closed=True))
        lenses.append(lens_disc(outline * [1, 1, 1] + [0, 0, -0.0005]))
    # puente: arco entre los bordes interiores, algo por encima del centro
    inner = LENS_CX - half_w
    bx = np.linspace(-inner - 0.0015, inner + 0.0015, 16)
    by = 0.010 + 0.0035 * np.cos(np.pi * bx / (2 * (inner + 0.0015)))
    parts.append(tube(np.column_stack([bx, by, np.zeros_like(bx)]), TUBE * 0.9, closed=False))
    # bisagras y patillas recortadas
    hinge_x = WIDTH / 2 - TUBE
    for side in (-1, 1):
        outer = side * (LENS_CX + half_w)
        y = half_h * 0.45
        parts.append(tube([[outer, y, 0], [side * hinge_x, y, 0]], TUBE, closed=False))
        parts.append(tube([[side * hinge_x, y, 0], [side * hinge_x, y - 0.001, -0.03]],
                          TUBE * 0.85, closed=False))
    frame = trimesh.util.concatenate(parts)
    lens = trimesh.util.concatenate(lenses)
    # anclaje: línea de los cristales (ya centrados en y = 0) en el plano frontal
    T = trimesh.transformations.translation_matrix([0, 0, -frame.bounds[1, 2]])
    frame.apply_transform(T)
    lens.apply_transform(T)
    frame.visual = trimesh.visual.TextureVisuals(material=PBRMaterial(
        name="frame", baseColorFactor=frame_rgba, metallicFactor=metallic,
        roughnessFactor=roughness, doubleSided=True))
    lens.visual = trimesh.visual.TextureVisuals(material=PBRMaterial(
        name="lens", baseColorFactor=lens_rgba, metallicFactor=0.0, roughnessFactor=0.05,
        alphaMode="BLEND", doubleSided=True))
    scene = trimesh.Scene()
    scene.add_geometry(frame, node_name="frame", geom_name="frame")
    scene.add_geometry(lens, node_name="lenses", geom_name="lenses")
    width = frame.extents[0]
    assert abs(width - WIDTH) < 0.002, width
    return scene


SAMPLES = {
    "classic_black": dict(half_w=0.025, half_h=0.019, exponent=5,
                          frame_rgba=[10, 10, 12, 255], metallic=0.0, roughness=0.3,
                          lens_rgba=[220, 230, 240, 50]),
    "round_gold_sun": dict(half_w=0.0245, half_h=0.0225, exponent=2,
                           frame_rgba=[212, 175, 95, 255], metallic=1.0, roughness=0.25,
                           lens_rgba=[40, 45, 50, 190]),
    "tortoise_rect": dict(half_w=0.026, half_h=0.0175, exponent=6,
                          frame_rgba=[110, 60, 25, 255], metallic=0.0, roughness=0.4,
                          lens_rgba=[200, 170, 120, 60]),
}

if __name__ == "__main__":
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    for name, params in SAMPLES.items():
        path = out / f"{name}.glb"
        build(**params).export(path)
        print(path, path.stat().st_size, "bytes")
