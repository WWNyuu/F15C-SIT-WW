-----------------------------------------------------------------------
-- F-15C SIT (WW): JHMCS, drawing helpers for the helmet display.
-- Units: milliradians (SetScale(MILLYRADIANS)); the move and rotate
-- controllers work in radians. JHMCS symbology is one colour: green.
-----------------------------------------------------------------------
dofile(LockOn_Options.common_script_path .. "elements_defs.lua")
dofile(LockOn_Options.script_path .. "HMD/hmd_config.lua")
dofile(LockOn_Options.script_path .. "HMD/hmd_options.lua")     -- (Options > Special: size)
SetScale(MILLYRADIANS)

DEG  = 17.4533                                  -- milliradians per degree
K    = DEG * (HMD.SCALE or 1)                   -- fixed layout: milliradians per layout degree
local COL = HMD.COLOR or {40, 255, 60, 255}
HMD_GREEN = MakeMaterial(nil, COL)
local ADD = HMD.ADDITIVE == true          -- see-through (washes out to pale on a bright sky) or solid

-- the add-on's thin stroke font (the SIT page's): monospaced, glyph in the
-- left 68 px of each 128 px cell, codes 32..126
local FONT_DESC = {
	texture    = LockOn_Options.script_path .. "../Textures/IndicationTextures/f15sit_font.dds",
	size       = {16, 16},
	resolution = {2048, 2048},
	default    = {68, 128},
	chars      = {},
}
for code = 32, 126 do FONT_DESC.chars[#FONT_DESC.chars + 1] = {code, 68, 128} end
HMD_FONT = MakeFont(FONT_DESC, COL)
local T = (HMD.TEXT or 0.016) * (HMD.SCALE or 1)
HMD_TXT   = {T, T, 0, 0}
HMD_TXT_S = {T * 0.78, T * 0.78, 0, 0}          -- small: altitude hundreds, ranges under symbols

local n = 0
local function nm(p) n = n + 1; return "hmd_" .. p .. n end

-- brightness (the HMD knob): every drawn symbol fades with F15SIT_HMD_BRT
local BRT = "F15SIT_HMD_BRT"
-- (a DCS element is not a plain table: a list given to it cannot be read
-- back, so each element's lists are built here and handed over once)
local function brightness(e, params, ctrls)
	params, ctrls = params or {}, ctrls or {}
	params[#params + 1] = BRT
	ctrls[#ctrls + 1] = {"opacity_using_parameter", #params - 1}
	e.element_params = params
	e.controllers = ctrls
end

-- an invisible parent that can be shown/hidden, moved, turned by parameters
function hmd_group(parent, params, ctrls, pos)
	local e = CreateElement "ceSimple"
	e.name = nm("g")
	e.init_pos = pos or {0, 0, 0}
	e.collimated = true
	if parent then e.parent_element = parent end
	if params then e.element_params = params; e.controllers = ctrls end
	Add(e)
	return e.name
end
-- shown while the parameter is between lo and hi
function hmd_show(parent, param, lo, hi, pos)
	return hmd_group(parent, {param}, {{"parameter_in_range", 0, lo, hi}}, pos)
end
-- shown while ON is 1, moved to X, Y (radians)
function hmd_moving(parent, on, x, y)
	return hmd_group(parent, {on, x, y},
		{{"parameter_in_range", 0, 0.5, 1.5},
		 {"move_left_right_using_parameter", 1, 1}, {"move_up_down_using_parameter", 2, 1}})
end

-- line segments: verts {{x,y},...}, inds pairs; in milliradians
function hmd_lines(parent, verts, inds, pos)
	local e = CreateElement "ceMeshPoly"
	e.name = nm("l")
	e.primitivetype = "lines"
	e.vertices = verts
	e.indices = inds
	e.material = HMD_GREEN
	e.init_pos = pos or {0, 0, 0}
	e.collimated = true
	e.additive_alpha = ADD
	if parent then e.parent_element = parent end
	brightness(e)
	Add(e)
	return e.name
end
function hmd_outline(parent, pts, pos)
	local ind = {}
	for k = 0, #pts - 1 do ind[#ind + 1] = k; ind[#ind + 1] = (k + 1) % #pts end
	return hmd_lines(parent, pts, ind, pos)
end
function hmd_rect(parent, w, h, pos)
	return hmd_outline(parent, {{-w / 2, -h / 2}, {w / 2, -h / 2}, {w / 2, h / 2}, {-w / 2, h / 2}}, pos)
end
-- circle (dash = true: dashed, every other segment)
function hmd_circle(parent, r, pos, dash, segs)
	segs = segs or 32
	local v, ind = {}, {}
	for k = 0, segs - 1 do
		local a = 2 * math.pi * k / segs
		v[#v + 1] = {r * math.cos(a), r * math.sin(a)}
	end
	for k = 0, segs - 1, (dash and 2 or 1) do ind[#ind + 1] = k; ind[#ind + 1] = (k + 1) % segs end
	return hmd_lines(parent, v, ind, pos)
end
-- a dashed square (corner brackets and side dashes), side s
function hmd_dash_rect(parent, s, pos)
	local h, q = s / 2, s / 6
	local v, ind = {}, {}
	local function seg(ax, ay, bx, by) v[#v + 1] = {ax, ay}; v[#v + 1] = {bx, by}; ind[#ind + 1] = #v - 2; ind[#ind + 1] = #v - 1 end
	for _, sx in ipairs({-1, 1}) do
		for _, sy in ipairs({-1, 1}) do
			seg(sx * h, sy * h, sx * (h - q), sy * h)
			seg(sx * h, sy * h, sx * h, sy * (h - q))
		end
		seg(sx * h, -q / 2, sx * h, q / 2)
		seg(-q / 2, sx * h, q / 2, sx * h)
	end
	return hmd_lines(parent, v, ind, pos)
end
-- a small filled-looking dot (a tiny cross of short lines)
function hmd_dot(parent, r, pos)
	return hmd_lines(parent, {{-r, 0}, {r, 0}, {0, -r}, {0, r}, {-r * 0.7, -r * 0.7}, {r * 0.7, r * 0.7},
		{-r * 0.7, r * 0.7}, {r * 0.7, -r * 0.7}}, {0, 1, 2, 3, 4, 5, 6, 7}, pos)
end

-- text: fixed (value) or from a parameter with a format ("%.0f", "%s")
function hmd_text(parent, pos, align, value, param, fmt, defs)
	local e = CreateElement "ceStringPoly"
	e.name = nm("t")
	e.material = HMD_FONT
	e.init_pos = pos
	e.alignment = align or "CenterCenter"
	e.stringdefs = defs or HMD_TXT
	e.collimated = true
	e.additive_alpha = ADD
	if parent then e.parent_element = parent end
	if param then
		e.formats = {fmt or "%s"}
		brightness(e, {param}, {{"text_using_parameter", 0, 0}})
	else
		e.value = value
		brightness(e)
	end
	Add(e)
	return e.name
end

