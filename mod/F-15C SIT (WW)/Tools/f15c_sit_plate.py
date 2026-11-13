# F-15C SIT (WW) - screen plate model, build + export script (v12)
# ============================================================
# For Blender 4.2 LTS with ED's official EDM exporter (io_scene_edm) enabled.
#
# HOW TO USE
#   1. File > New > General  (an empty file: this script DELETES everything
#      in the current scene, because the exporter exports the whole scene)
#   2. Scripting tab > New > paste this script > Run Script (the play button)
#   3. Window > Toggle System Console shows what it did.
#
# It builds, in DCS cockpit coordinates, on the stock lower-left display
# (position, size and 15 deg tilt read from ED's own cockpit model):
#   * SIT_PLATE   a dark plate with rounded corners, 3 mm in front of the
#                 stock glass and 1.1 cm bigger each side, to hide it
#   * SIT_C / SIT_T / SIT_B / SIT_R   our screen anchors (centre, top,
#                 bottom, right), 5 mm in front of the stock glass
#   * SIT_OSB_T1..T5, B1..B5, L1..L5, R1..R5   click points for the 20 buttons
#   * SIT_MODE_KNOB, SIT_BRT   v12: click points for the OFF / NIGHT / DAY knob
#                 and the BRT rocker below the display
#   * SIT_GLASS   v12 (test): a pane of ED's glass material just in front of
#                 our screen, for reflections like the other displays
# then saves the texture and exports straight into the mod folder.

import bpy
import bmesh
import math
import os
from mathutils import Vector, Matrix

# ---------------------------------------------------------------------------
# SETTINGS
# ---------------------------------------------------------------------------
MOD_DIR = r"C:\Users\YOU\Saved Games\DCS\Mods\tech\F-15C SIT (WW)"
EDM_NAME = "F15C_SIT"              # must match shape_name in mainpanel_init.lua

# Exact position of the stock lower-left display, read from ED's own
# Cockpit_F-15C.EDM: its screen anchors MFD-PLASHKA-CENTER / -UP / -RIGHT.
# DCS cockpit axes: X forward, Y up, Z right; origin = pilot's eye point.
GLASS_C = (0.7419, -0.5359, -0.2628)
GLASS_U = (0.7574, -0.4773, -0.2628)
GLASS_R = (0.7419, -0.5359, -0.2031)

SCREEN_GAP = 0.0045                # our screen this far in front of the stock glass
ANCHOR_TILT_DEG = 14.8             # v7: tilt of our screen (DCS takes it from the anchors'
                                   # rotation, not their positions). Should match the glass.
                                   # If the screen now leans the WRONG way, use -14.8
SIDE_SHIFT = -0.004                # v9: plate + screen moved this far right (- = left); the
                                   # glass opening sits a bit left of ED's screen anchors
UP_SHIFT = 0.0                     # same, up (+) / down (-)
PLATE_GAP = 0.0025                 # plate this far in front of the stock glass
SCREEN_MARGIN = 0.014              # v6: our screen this much bigger than the stock glass (each side)
PLATE_MARGIN = 0.017               # v6: plate this much bigger (covers the whole slot; edges hide in the bezel)
CORNER_R = 0.003                   # v10: nearly square, so no corner of the old glass shows
CORNER_SEGS = 6

BUTTON_ROW = 1.25                  # button rows: distance from centre, in half-sizes
BUTTON_ROW_L = 1.35                # v12: the left column, a bit further out (its clicks
                                   # only reached the inner half of the buttons)
BUTTON_POS = (-0.68, -0.34, 0.0, 0.34, 0.68)   # along each side, x half-size
BUTTON_BOX = 0.006                 # click box half-size (metres)

# v12: the controls below the display (positions in half-sizes: right, up;
# estimated from a screenshot - move them here if the click spot is off)
KNOB_POS = (0.15, -1.68)           # OFF / NIGHT / DAY knob
KNOB_BOX = 0.009
BRT_POS = (0.72, -1.73)            # BRT rocker
BRT_BOX = 0.008

# v12 test: glass pane over the screen (False = no pane, the model as before).
# Tested: DCS draws the page over the pane (the indicator is drawn last), so
# no reflection shows - only the pane's default white around the page. Off.
GLASS = False
GLASS_GAP = 0.0065                 # this far in front of the stock glass (our screen: SCREEN_GAP)
GLASS_TINT = (0.04, 0.05, 0.06, 0.10)   # colour + alpha of the pane (alpha: how much it covers the page)

ORIGIN_MARKER = False
CALIBRATION = False

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
def to_bl(v):
    """DCS cockpit (x fwd, y up, z right) -> Blender for ED's exporter
    (X fwd, Y left, Z up). From ROOT_TRANSFORM_MATRIX in the exporter."""
    x, y, z = v
    return Vector((x, -z, y))

C = Vector(GLASS_C)
_u = Vector(GLASS_U) - C
_r = Vector(GLASS_R) - C
HALF_H = _u.length                               # 0.0606 m
HALF_W = _r.length                               # 0.0597 m
U = _u.normalized()                              # screen up (top leans forward ~15 deg)
R = _r.normalized()                              # screen right
N = R.cross(U).normalized()                      # screen normal, toward the pilot
if N.x > 0:
    N = -N

def on_screen(a, b, depth=0.0, shifted=True):
    """point a*half-width right, b*half-height up, depth metres toward the pilot (DCS).
    shifted: apply SIDE_SHIFT / UP_SHIFT (v11: buttons too - the real bezel sits around the real opening)"""
    base = C + R * SIDE_SHIFT + U * UP_SHIFT if shifted else C
    return base + R * (a * HALF_W) + U * (b * HALF_H) + N * depth

def bl_basis_matrix(pos_dcs, scale):
    """object matrix: X = screen right, Y = screen up, Z = normal (Blender)"""
    r, u, n = to_bl(R), to_bl(U), to_bl(N)
    m = Matrix((
        (r.x * scale, u.x * scale, n.x * scale, 0),
        (r.y * scale, u.y * scale, n.y * scale, 0),
        (r.z * scale, u.z * scale, n.z * scale, 0),
        (0, 0, 0, 1),
    ))
    m.translation = to_bl(pos_dcs)
    return m

def set_edm_type(obj, kind):
    p = getattr(obj, "EDMProps", None)
    if p is None or not hasattr(p, "SPECIAL_TYPE"):
        print("  !! EDMProps missing - is the EDM exporter enabled?")
        return False
    try:
        p.SPECIAL_TYPE = kind
        return True
    except Exception as e:
        print("  !! could not set", obj.name, "to", kind, ":", e)
        return False

# ---------------------------------------------------------------------------
# clear the scene
# ---------------------------------------------------------------------------
for o in list(bpy.context.scene.objects):
    bpy.data.objects.remove(o, do_unlink=True)
coll = bpy.context.scene.collection

# ---------------------------------------------------------------------------
# texture + material
# ---------------------------------------------------------------------------
tex_dir = os.path.join(MOD_DIR, "Textures")
os.makedirs(tex_dir, exist_ok=True)
img_path = os.path.join(tex_dir, "sit_plate_black.png")
img = bpy.data.images.get("sit_plate_black.png") or bpy.data.images.new("sit_plate_black.png", 8, 8)
img.pixels[:] = [0.02, 0.02, 0.02, 1.0] * 64
img.filepath_raw = img_path
img.file_format = "PNG"
img.save()
print("texture saved:", img_path)

old = bpy.data.materials.get("SIT_PLATE_MAT")
if old:
    bpy.data.materials.remove(old)
mat = bpy.data.materials.new("SIT_PLATE_MAT")
mat.use_nodes = True
nt = mat.node_tree
for nd in list(nt.nodes):
    if nd.type != "OUTPUT_MATERIAL":
        nt.nodes.remove(nd)

edm_ok = False
try:
    # The same thing as Shift+A > EDM > Default in the Shader Editor
    # (the exporter's "node.ed_add_defaultnew"): the new EDM shader node.
    # v2 of this script: v1 used the old node group, which newer exporter
    # builds refuse ("old shader group node").
    from materials.material_default import DefaultMaterial
    from materials.materials import build_material_descriptions
    descs = build_material_descriptions()
    grp = nt.nodes.new(type=DefaultMaterial.node_group_name)
    grp.post_init(descs[DefaultMaterial.name])
    grp.location = (100, 100)
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.location = (-300, 100)
    nt.links.new(tex.outputs["Color"], grp.inputs["Base Color"])
    edm_ok = True
    print("EDM Default material created")
except Exception as e:
    print("  !! could not create the EDM material automatically:", repr(e))
    print("     Do it by hand: select SIT_PLATE, Shader Editor, Shift+A > EDM > Default,")
    print("     then connect an Image Texture node with sit_plate_black.png to 'Base Color',")
    print("     then File > Export > Eagle Dynamics Model (.edm).")

# ---------------------------------------------------------------------------
# the plate (rounded rectangle, triangle fan, with UVs)
# ---------------------------------------------------------------------------
def rounded_outline(hw, hh, r, segs):
    pts = []
    corners = [(hw - r, hh - r, 0), (-hw + r, hh - r, 90),
               (-hw + r, -hh + r, 180), (hw - r, -hh + r, 270)]
    for cx, cy, a0 in corners:
        for i in range(segs + 1):
            a = math.radians(a0 + 90.0 * i / segs)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts

def add_plate(name, hw, hh, depth):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    outline = rounded_outline(hw, hh, CORNER_R, CORNER_SEGS)
    centre = bm.verts.new(to_bl(on_screen(0, 0, depth)))
    base = C + R * SIDE_SHIFT + U * UP_SHIFT
    ring = [bm.verts.new(to_bl(base + R * x + U * y + N * depth)) for x, y in outline]
    for i in range(len(ring)):
        a, b = ring[i], ring[(i + 1) % len(ring)]
        f = bm.faces.new((centre, a, b))
        for loop in f.loops:
            loop[uv].uv = (0.5, 0.5)
    bm.normal_update()
    # the face must point toward the pilot
    nb = to_bl(N)
    for f in bm.faces:
        if f.normal.dot(nb) < 0:
            f.normal_flip()
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    coll.objects.link(ob)
    ob.data.materials.append(mat)
    return ob

plate = add_plate("SIT_PLATE", HALF_W + PLATE_MARGIN, HALF_H + PLATE_MARGIN, PLATE_GAP)
print("plate built:", plate.name)

# ---------------------------------------------------------------------------
# v12 test: the glass pane. ED's exporter has its own glass material; it is
# looked for among the exporter's materials (name with "glass" in it). If
# it is not found, no pane is built and the rest is exported as before.
# The console lists the material's inputs (for tuning).
# ---------------------------------------------------------------------------
def find_glass_material():
    import importlib, pkgutil
    try:
        import materials as edm_materials
    except Exception as e:
        print("  !! exporter materials not found:", repr(e))
        return None
    found = []
    for info in pkgutil.iter_modules(edm_materials.__path__):
        try:
            mod = importlib.import_module("materials." + info.name)
        except Exception:
            continue
        for v in vars(mod).values():
            if isinstance(v, type) and hasattr(v, "node_group_name") and hasattr(v, "name"):
                found.append(v)
    print("  exporter materials:", ", ".join(sorted(set(str(c.name) for c in found))))
    for c in found:
        if "glass" in str(c.name).lower():
            return c
    return None

if GLASS and edm_ok:
    try:
        from materials.materials import build_material_descriptions
        cls = find_glass_material()
        if cls is None:
            print("  !! no glass material in this exporter: no glass pane")
        else:
            gimg = bpy.data.images.get("sit_glass.png") or bpy.data.images.new("sit_glass.png", 8, 8, alpha=True)
            gimg.pixels[:] = list(GLASS_TINT) * 64
            gimg.filepath_raw = os.path.join(tex_dir, "sit_glass.png")
            gimg.file_format = "PNG"
            gimg.save()
            old = bpy.data.materials.get("SIT_GLASS_MAT")
            if old:
                bpy.data.materials.remove(old)
            gmat = bpy.data.materials.new("SIT_GLASS_MAT")
            gmat.use_nodes = True
            gnt = gmat.node_tree
            for nd in list(gnt.nodes):
                if nd.type != "OUTPUT_MATERIAL":
                    gnt.nodes.remove(nd)
            ggrp = gnt.nodes.new(type=cls.node_group_name)
            ggrp.post_init(build_material_descriptions()[cls.name])
            print("  glass material:", cls.name, "- inputs:", ", ".join(i.name for i in ggrp.inputs))
            gtex = gnt.nodes.new("ShaderNodeTexImage")
            gtex.image = gimg
            gtex.location = (-300, 100)
            for i in ggrp.inputs:
                if i.name in ("Base Color", "Diffuse", "Color"):
                    gnt.links.new(gtex.outputs["Color"], i)
                elif i.name in ("Alpha", "Opacity", "Transparency"):
                    gnt.links.new(gtex.outputs["Alpha"], i)
            mat_keep = mat
            mat = gmat                      # (add_plate uses the global "mat")
            glass = add_plate("SIT_GLASS", HALF_W + SCREEN_MARGIN, HALF_H + SCREEN_MARGIN, GLASS_GAP)
            mat = mat_keep
            print("glass pane built:", glass.name)
    except Exception as e:
        print("  !! glass pane failed (the rest is exported without it):", repr(e))
        for o in list(bpy.context.scene.objects):
            if o.name.startswith("SIT_GLASS"):
                bpy.data.objects.remove(o, do_unlink=True)

if ORIGIN_MARKER:
    me = bpy.data.meshes.new("ORIGIN_MARKER")
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=0.03)
    uvl = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        for loop in f.loops:
            loop[uvl].uv = (0.5, 0.5)
    bm.to_mesh(me)
    bm.free()
    mk = bpy.data.objects.new("ORIGIN_MARKER", me)
    coll.objects.link(mk)
    mk.data.materials.append(mat)
    print("origin marker built")


if CALIBRATION:
    # 40 cm from the model origin (the pilot's eye) along each Blender axis:
    #   1 cube  = Blender +X  (should be straight ahead)
    #   2 cubes = Blender +Y  (should be to the left)
    #   3 cubes = Blender +Z  (should be straight up)
    # Where they really appear tells us how DCS maps this model's axes.
    def cube_stack(name, base, count, step):
        me = bpy.data.meshes.new(name)
        bm = bmesh.new()
        for i in range(count):
            r = bmesh.ops.create_cube(bm, size=0.025)
            bmesh.ops.translate(bm, verts=r["verts"], vec=Vector(base) + Vector(step) * i)
        uvl = bm.loops.layers.uv.new("UVMap")
        for f in bm.faces:
            for loop in f.loops:
                loop[uvl].uv = (0.5, 0.5)
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new(name, me)
        coll.objects.link(ob)
        ob.data.materials.append(mat)
    cube_stack("CAL_1_X", (0.40, 0.0, 0.0), 1, (0, 0, 0.04))
    cube_stack("CAL_2_Y", (0.0, 0.40, 0.0), 2, (0, 0, 0.04))
    cube_stack("CAL_3_Z", (0.0, 0.0, 0.40), 3, (0.04, 0, 0))
    print("calibration cubes built")

# ---------------------------------------------------------------------------
# connectors
# ---------------------------------------------------------------------------
# Orientation of ED's own MFD-PLASHKA connectors (as stored in the EDM),
# converted back through the exporter (root transform + its 90 deg X turn
# on connectors). v3/v4 used a tilted orientation and the screen came out
# flipped; copying ED's should make it draw the right way up.
ED_ANCHOR_ROT = Matrix(((0, 0, 1), (-1, 0, 0), (0, -1, 0)))
# v7: tilted about the cockpit's sideways axis (Blender Y) so the screen
# leans back like the glass. v6 stood upright: top stuck out, bottom sank in.
ANCHOR_ROT = Matrix.Rotation(math.radians(ANCHOR_TILT_DEG), 3, "Y") @ ED_ANCHOR_ROT

def add_connector(name, pos_dcs, half_size, rot=None):
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = "CUBE"
    e.empty_display_size = 1.0
    coll.objects.link(e)
    if rot is None:
        e.matrix_world = bl_basis_matrix(pos_dcs, half_size)
    else:
        m = (rot @ Matrix.Diagonal((half_size, half_size, half_size))).to_4x4()
        m.translation = to_bl(pos_dcs)
        e.matrix_world = m
    set_edm_type(e, "CONNECTOR")
    return e

# screen anchors: centre, middle of the top edge, middle of the right edge,
# SCREEN_GAP in front of the stock glass, SCREEN_MARGIN bigger than it.
# v6: SIT_B (middle of the bottom edge) added. With C/T/R the page came out
# mirrored top-to-bottom, so device_init.lua now uses C/B/R instead.
sv = 1 + SCREEN_MARGIN / HALF_H
sh_ = 1 + SCREEN_MARGIN / HALF_W
add_connector("SIT_C", on_screen(0, 0, SCREEN_GAP), 0.004, ANCHOR_ROT)
add_connector("SIT_T", on_screen(0, sv, SCREEN_GAP), 0.004, ANCHOR_ROT)
add_connector("SIT_B", on_screen(0, -sv, SCREEN_GAP), 0.004, ANCHOR_ROT)
add_connector("SIT_R", on_screen(sh_, 0, SCREEN_GAP), 0.004, ANCHOR_ROT)

# 20 buttons, on the bezel around the glass (positions in half-sizes)
for i, p in enumerate(BUTTON_POS, start=1):
    add_connector(f"SIT_OSB_T{i}", on_screen(p, BUTTON_ROW, SCREEN_GAP), BUTTON_BOX)    # top, left to right
    add_connector(f"SIT_OSB_B{i}", on_screen(p, -BUTTON_ROW, SCREEN_GAP), BUTTON_BOX)   # bottom, left to right
    add_connector(f"SIT_OSB_L{i}", on_screen(-BUTTON_ROW_L, -p, SCREEN_GAP), BUTTON_BOX)  # left, top to bottom
    add_connector(f"SIT_OSB_R{i}", on_screen(BUTTON_ROW, -p, SCREEN_GAP), BUTTON_BOX)   # right, top to bottom
add_connector("SIT_MODE_KNOB", on_screen(KNOB_POS[0], KNOB_POS[1], SCREEN_GAP), KNOB_BOX)
add_connector("SIT_BRT", on_screen(BRT_POS[0], BRT_POS[1], SCREEN_GAP), BRT_BOX)
print("26 connectors built")

# ---------------------------------------------------------------------------
# export
# ---------------------------------------------------------------------------
shapes = os.path.join(MOD_DIR, "Shapes")
os.makedirs(shapes, exist_ok=True)
out = os.path.join(shapes, EDM_NAME + ".edm")
if edm_ok:
    try:
        bpy.ops.edm.export(filepath=out)
        print("EXPORTED:", out)
    except Exception as e:
        print("  !! export failed:", e)
        print("     Try File > Export > Eagle Dynamics Model (.edm) to", out)
else:
    print("Fix the material (see above), then File > Export > Eagle Dynamics Model (.edm) to", out)

# frame the view on the plate
for area in bpy.context.screen.areas:
    if area.type == "VIEW_3D":
        for o in bpy.context.scene.objects:
            o.select_set(o.name == "SIT_PLATE")
        break
print("done")
