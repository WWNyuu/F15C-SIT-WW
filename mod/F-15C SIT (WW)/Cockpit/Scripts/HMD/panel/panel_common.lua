-----------------------------------------------------------------------
-- F-15C SIT (WW): JHMCS control panel (left console), shared helpers for
-- its two displays: the plate's markings and the knob's pointer. Page
-- units: +-1 = the anchors (HMDP_*: 5 cm, HMDK_*: 2 cm); text sizes in
-- metres (stroke font, glyph cell height).
-----------------------------------------------------------------------
dofile(LockOn_Options.common_script_path .. "elements_defs.lua")
SetScale(FOV)

PANEL_WHITE = MakeMaterial(nil, {228, 228, 218, 255})
local FONT_DESC = {
	texture    = LockOn_Options.script_path .. "../Textures/IndicationTextures/f15sit_font.dds",
	size       = {16, 16},
	resolution = {2048, 2048},
	default    = {68, 128},
	chars      = {},
}
for code = 32, 126 do FONT_DESC.chars[#FONT_DESC.chars + 1] = {code, 68, 128} end
PANEL_FONT = MakeFont(FONT_DESC, {228, 228, 218, 255})
local CAP = 77 / 128
function cap_defs(cap_m) local h = cap_m / CAP; return {h, h, 0, 0} end

local n = 0
local function nm(p) n = n + 1; return "hmdp_" .. p .. n end

function p_group(parent, params, ctrls, pos)
	local e = CreateElement "ceSimple"
	e.name = nm("g")
	e.init_pos = pos or {0, 0, 0}
	if parent then e.parent_element = parent end
	if params then e.element_params = params; e.controllers = ctrls end
	Add(e)
	return e.name
end
-- a straight stroke of width w from (x1, y1) to (x2, y2), as two triangles
function p_stroke(parent, x1, y1, x2, y2, w, mat)
	local dx, dy = x2 - x1, y2 - y1
	local l = math.sqrt(dx * dx + dy * dy)
	local nx, ny = -dy / l * w / 2, dx / l * w / 2
	local e = CreateElement "ceMeshPoly"
	e.name = nm("s")
	e.primitivetype = "triangles"
	e.vertices = {{x1 + nx, y1 + ny}, {x2 + nx, y2 + ny}, {x2 - nx, y2 - ny}, {x1 - nx, y1 - ny}}
	e.indices = {0, 1, 2, 0, 2, 3}
	e.material = mat or PANEL_WHITE
	e.init_pos = {0, 0, 0}
	e.use_mipfilter = true
	e.additive_alpha = false
	if parent then e.parent_element = parent end
	Add(e)
end
function p_text(parent, x, y, s, defs, align)
	local e = CreateElement "ceStringPoly"
	e.name = nm("t")
	e.material = PANEL_FONT
	e.init_pos = {x, y, 0}
	e.alignment = align or "CenterCenter"
	e.stringdefs = defs
	e.value = s
	e.use_mipfilter = true
	e.additive_alpha = false
	if parent then e.parent_element = parent end
	Add(e)
end
