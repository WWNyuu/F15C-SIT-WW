-----------------------------------------------------------------------
-- F-15C SIT (WW): MPCD pages (v0.5.0): SIT (layout after the real SIT
-- page), MENU and DTM. One page shown at a time (F15SIT_PAGE).
-- Real F-15C SIT colours (v0.6, after redflagsim.com's F-15C MPCD docs):
-- cyan ownship / own flight, green friendlies, red hostiles, white
-- unknowns, yellow route and bullseye. Solid symbol = own radar
-- holds it, dotted = datalink only (same codes as the MiG-29 add-on).
-- All values come from SIT/sit_device.lua as cockpit parameters F15SIT_*.
-----------------------------------------------------------------------
dofile(LockOn_Options.common_script_path .. "elements_defs.lua")
dofile(LockOn_Options.script_path .. "SIT/sit_config.lua")
SetScale(FOV)

local G   = SIT.G
local BOX = SIT.BOX
local LW  = 0.006            -- line width of rings and symbols
local S   = 0.035            -- contact symbol size

---------------------------------------------------------------------------
-- colours and fonts
---------------------------------------------------------------------------
local function col(r, g, b, a) return MakeMaterial(nil, {r, g, b, a or 255}) end
-- page font: the add-on's stroke font (a texture: monospaced, glyph in the
-- left FONT_CELL_W px of each 128 px cell, codes 32..126 row-major), or
-- DCS's Arial (SIT.FONT_STYLE = "arial")
local TEXF = SIT.FONT_STYLE ~= "arial"
local FONT_DESC = nil
if TEXF then
	local cw = SIT.FONT_CELL_W
	FONT_DESC = {
		texture    = LockOn_Options.script_path .. "../Textures/IndicationTextures/f15sit_font.dds",
		size       = {16, 16},
		resolution = {2048, 2048},
		default    = {cw, 128},
		chars      = {},
	}
	for code = 32, 126 do FONT_DESC.chars[#FONT_DESC.chars + 1] = {code, cw, 128} end
end
local function fnt(r, g, b)
	if TEXF then return MakeFont(FONT_DESC, {r, g, b, 255}) end
	return MakeFont({used_DXUnicodeFontData = "font_arial_13"}, {r, g, b, 255})
end
local M = {
	black   = col(0, 0, 0),
	ring    = col(170, 185, 175),
	own     = col(90, 215, 255),
	friend  = col(40, 230, 90),
	hostile = col(245, 60, 60),
	unknown = col(235, 235, 235),        -- unknown identity: white
	wing    = col(0, 220, 255),          -- own flight: cyan
	pdt     = col(80, 130, 255),         -- line to the primary designated target
	planf   = col(150, 160, 155),        -- aircraft outline (A/A, CBT JETT pages)
	sel     = col(40, 200, 80),          -- selected station fill
	route   = col(240, 200, 50),
	cyan    = col(0, 220, 255),
	bull    = col(240, 220, 60),
	white   = col(235, 235, 235),
	label   = col(120, 230, 150),
	-- threat rings: a background layer, dimmer and see-through, so the
	-- contacts on top of them stay readable
	thr_o   = col(200, 60, 60, 140),     -- MEZ ring, we are outside
	thr_i   = col(250, 60, 60, 230),     -- MEZ ring, we are inside
}
local F = {
	green  = fnt(120, 230, 150),
	white  = fnt(235, 235, 235),
	grey   = fnt(170, 185, 175),
	red    = fnt(245, 60, 60),
	yellow = fnt(240, 230, 60),
	blue   = fnt(80, 160, 255),
	orange = fnt(255, 150, 40),
	cfriend = fnt(40, 230, 90),
	thr_o  = fnt(200, 70, 70),
	thr_i  = fnt(250, 60, 60),
	cyan   = fnt(0, 220, 255),
	magenta = fnt(230, 70, 230),
	route  = fnt(240, 200, 50),
}
-- text sizes, given as capital height in page units (the screen is -1..1).
-- Texture font: DCS makes a glyph cell defs[1] metres tall and
-- defs[2] x (cell width / height) wide, so defs[2] = defs[1] keeps the
-- letters' own proportions; metres -> page units: / G.
-- Arial (v0.4): ~15 x defs[1] tall, ~19 x defs[1] per character at width 0.5.
local FK, FW = SIT.FONT_SCALE or 1, SIT.FONT_WIDTH or 1
local ASPECT = (SIT.FONT_CELL_W or 68) / 128
local function tsize(cap)
	cap = cap * FK
	if TEXF then
		local h = cap * G / SIT.FONT_CAP
		return {h, h * FW, 0, 0}
	end
	local h = cap / 15.3
	return {h, h * 0.5 * FW, 0, 0}
end
-- advance of one character / capital height, in page units
local function char_w(d) if TEXF then return d[2] * ASPECT / G end return d[2] * 38.7 end
local function char_h(d) if TEXF then return d[1] * SIT.FONT_CAP / G end return d[1] * 15.3 end
local TXT_BIG   = tsize(0.064)   -- range scale
local TXT       = tsize(0.050)   -- time, cyan readout
local TXT_SMALL = tsize(0.040)   -- data blocks, compass rose
local TXT_BTN   = tsize(0.040)   -- button labels
local TXT_TINY  = tsize(0.031)   -- steerpoint numbers, status
local TXT_DATA  = tsize(0.033)   -- SIT corner data blocks (v0.8.1: smaller, less clutter)
local TXT_ROSE  = tsize(0.026)   -- compass rose numbers

---------------------------------------------------------------------------
-- element helpers
---------------------------------------------------------------------------
local function prm(e, params, ctrls)
	if params then e.element_params = params end
	if ctrls then e.controllers = ctrls end
end
local function simple(name, parent, pos, params, ctrls)
	local e = CreateElement "ceSimple"
	e.name = name
	e.init_pos = pos or {0, 0, 0}
	if parent then e.parent_element = parent end
	prm(e, params, ctrls)
	Add(e)
	return e
end
local function mesh(name, parent, prim, v, idx, mat, pos, params, ctrls)
	local e = CreateElement "ceMeshPoly"
	e.name = name
	e.primitivetype = prim
	e.vertices = v
	e.indices = idx
	e.material = mat
	e.init_pos = pos or {0, 0, 0}
	if parent then e.parent_element = parent end
	e.use_mipfilter = true
	e.additive_alpha = false
	prm(e, params, ctrls)
	Add(e)
	return e
end
-- fmt: a number format ("%.0f") for a parameter that holds a NUMBER. Text
-- parameters use "%s" and must never hold something number-like: DCS
-- stores "40" as the number 40, and "%s" with a number crashes DCS
-- (access violation in ceStringPoly, v0.3.0 - v0.3.2)
local function text(name, parent, pos, font, defs, align, value, param, vis, fmt)
	local e = CreateElement "ceStringPoly"
	e.name = name
	e.material = font
	e.init_pos = pos
	e.alignment = align or "CenterCenter"
	e.stringdefs = defs or TXT
	if parent then e.parent_element = parent end
	local params, ctrls = {}, {}
	if param then
		e.formats = {fmt or "%s"}
		params[#params + 1] = param
	else
		e.value = value
	end
	-- (the visibility check first: a hidden text is not formatted)
	if vis then
		params[#params + 1] = vis[1]
		ctrls[#ctrls + 1] = {"parameter_in_range", #params - 1, vis[2], vis[3]}
	end
	if param then ctrls[#ctrls + 1] = {"text_using_parameter", 0, 0} end
	if #params > 0 then prm(e, params, ctrls) end
	Add(e)
	return e
end
local function line_obj(name, parent, mat, width, params, ctrls)
	local e = CreateElement "ceSimpleLineObject"
	e.name = name
	e.material = mat
	e.width = width
	e.vertices = {{0, 0}, {0, 0}}
	e.init_pos = {0, 0, 0}
	e.parent_element = parent
	e.use_mipfilter = true
	e.additive_alpha = false
	prm(e, params, ctrls)
	Add(e)
	return e
end
local function vis(param, lo, hi) return {"parameter_in_range", 0, lo, hi} end
local function at(param_x, param_y, extra)
	local p = {param_x, param_y}
	local c = {}
	-- (the visibility checks first: a hidden group is not moved)
	if extra then
		for _, x in ipairs(extra) do
			p[#p + 1] = x[1]
			c[#c + 1] = {"parameter_in_range", #p - 1, x[2], x[3]}
		end
	end
	c[#c + 1] = {"move_left_right_using_parameter", 0, G}
	c[#c + 1] = {"move_up_down_using_parameter", 1, G}
	return p, c
end

---------------------------------------------------------------------------
-- geometry helpers
---------------------------------------------------------------------------
local function circle_pts(r, n)
	local v = {}
	for k = 0, n - 1 do
		local a = 2 * math.pi * k / n
		v[#v + 1] = {r * math.cos(a), r * math.sin(a)}
	end
	return v
end
local function band(outer, inner)
	local v, idx, n = {}, {}, #outer
	for k = 1, n do v[k] = outer[k]; v[n + k] = inner[k] end
	for k = 0, n - 1 do
		local a, b = k, (k + 1) % n
		idx[#idx + 1] = a; idx[#idx + 1] = b; idx[#idx + 1] = n + b
		idx[#idx + 1] = a; idx[#idx + 1] = n + b; idx[#idx + 1] = n + a
	end
	return v, idx
end
local function dashed(outer, inner, sub)
	local v, idx, n = {}, {}, #outer
	local O, I = {}, {}
	for k = 1, n do
		local a, b = outer[k], outer[k % n + 1]
		local c, d = inner[k], inner[k % n + 1]
		for j = 0, sub - 1 do
			local t = j / sub
			O[#O + 1] = {a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t}
			I[#I + 1] = {c[1] + (d[1] - c[1]) * t, c[2] + (d[2] - c[2]) * t}
		end
	end
	local m = #O
	for k = 1, m do v[k] = O[k]; v[m + k] = I[k] end
	for k = 0, m - 1, 2 do
		local a, b = k, (k + 1) % m
		idx[#idx + 1] = a; idx[#idx + 1] = b; idx[#idx + 1] = m + b
		idx[#idx + 1] = a; idx[#idx + 1] = m + b; idx[#idx + 1] = m + a
	end
	return v, idx
end
local function scaled(pts, f)
	local v = {}
	for k, p in ipairs(pts) do v[k] = {p[1] * f, p[2] * f} end
	return v
end
local function inradius(pts)
	local best = 1e9
	for k = 1, #pts do
		local a, b = pts[k], pts[k % #pts + 1]
		local ex, ey = b[1] - a[1], b[2] - a[2]
		local d = math.abs(a[1] * ey - a[2] * ex) / math.sqrt(ex * ex + ey * ey)
		if d < best then best = d end
	end
	return best
end
local function outline(pts, w, dash, sub)
	local inner = scaled(pts, 1 - w / inradius(pts))
	if dash then return dashed(pts, inner, sub) end
	return band(pts, inner)
end
local function circle_fill(r, n)
	local v, idx = {{0, 0}}, {}
	for i = 0, n - 1 do
		local a = 2 * math.pi * i / n
		v[#v + 1] = {r * math.cos(a), r * math.sin(a)}
	end
	for i = 1, n do idx[#idx + 1] = 0; idx[#idx + 1] = i; idx[#idx + 1] = (i % n) + 1 end
	return v, idx
end
local function poly_lines(pts, closed)
	local idx = {}
	local last = closed and #pts or #pts - 1
	for i = 0, last - 1 do idx[#idx + 1] = i; idx[#idx + 1] = (i + 1) % #pts end
	return pts, idx
end
-- a thick arc of radius r around (0, 0), only the parts inside the box
-- (the box is in page coordinates; oy = where the ownship sits)
local function clipped_ring(r, w, oy, n, dash, cy)
	cy = cy or 0     -- centre of the ring above the frame origin
	local v, idx = {}, {}
	local function ok(x, y) return math.abs(x) <= BOX and math.abs(y + oy) <= BOX end
	for k = 0, n - 1, (dash and 2 or 1) do
		local a0, a1 = 2 * math.pi * k / n, 2 * math.pi * (k + 1) / n
		local p0 = {r * math.cos(a0), cy + r * math.sin(a0)}
		local p1 = {r * math.cos(a1), cy + r * math.sin(a1)}
		if ok(p0[1], p0[2]) and ok(p1[1], p1[2]) then
			local q0 = {(r - w) * math.cos(a0), cy + (r - w) * math.sin(a0)}
			local q1 = {(r - w) * math.cos(a1), cy + (r - w) * math.sin(a1)}
			local b = #v
			v[b + 1] = p0; v[b + 2] = p1; v[b + 3] = q1; v[b + 4] = q0
			idx[#idx + 1] = b; idx[#idx + 1] = b + 1; idx[#idx + 1] = b + 2
			idx[#idx + 1] = b; idx[#idx + 1] = b + 2; idx[#idx + 1] = b + 3
		end
	end
	return v, idx
end
local function ticks(r, len, w, oy)
	local v, idx = {}, {}
	for deg = 0, 330, 30 do
		if deg % 90 ~= 0 then
			local a = math.rad(90 - deg)
			local ca, sa = math.cos(a), math.sin(a)
			local px, py = -sa * w / 2, ca * w / 2
			local r0, r1 = r - len, r
			local x1, y1 = r1 * ca, r1 * sa
			if oy == nil or (math.abs(x1) <= BOX and math.abs(y1 + oy) <= BOX) then
				local k = #v
				v[k + 1] = {r0 * ca + px, r0 * sa + py}; v[k + 2] = {r1 * ca + px, r1 * sa + py}
				v[k + 3] = {r1 * ca - px, r1 * sa - py}; v[k + 4] = {r0 * ca - px, r0 * sa - py}
				idx[#idx + 1] = k; idx[#idx + 1] = k + 1; idx[#idx + 1] = k + 2
				idx[#idx + 1] = k; idx[#idx + 1] = k + 2; idx[#idx + 1] = k + 3
			end
		end
	end
	return v, idx
end

---------------------------------------------------------------------------
-- page
---------------------------------------------------------------------------
-- v0.3.2: hidden until the device has given every text parameter a string
simple("sit_root", nil, {0, 0, 0}, {"F15SIT_READY"}, {{"parameter_in_range", 0, 0.5, 1.5}})
mesh("sit_bg", "sit_root", "triangles", {{-1, 1}, {1, 1}, {1, -1}, {-1, -1}}, {0, 1, 2, 0, 2, 3}, M.black)

-- pages: 1 SIT, 2 MENU, 3 DTM
simple("sit_pg", "sit_root", {0, 0, 0}, {"F15SIT_PAGE"}, {{"parameter_in_range", 0, 0.5, 1.5}})

-- ownship frame (moves down in the decentred view)
simple("sit_own", "sit_pg", {0, 0, 0}, {"F15SIT_OWN_Y", "F15SIT_OWN_X"},
	{{"move_up_down_using_parameter", 0, G}, {"move_left_right_using_parameter", 1, G}})

-- range references (as the real SIT page):
--   centred:   the compass rose IS the range ring (ownship to the top of the
--              compass = selected range), plus a thin solid ring at half range
--   decentred: ownship low; a large solid circle in the middle of the
--              display, its top = the range shown; small compass rose
--              around the ownship, no half-range ring
simple("sit_sc_c", "sit_own", {0, 0, 0}, {"F15SIT_CENTER"}, {vis(0, 0.5, 1.5)})
simple("sit_sc_d", "sit_own", {0, 0, 0}, {"F15SIT_CENTER"}, {vis(0, -0.5, 0.5)})
-- the large circle sits in the middle of the display (the ownship below its
-- centre); its top is the range shown top right
local v, i = clipped_ring(SIT.BOX - 0.005, LW * 0.6, SIT.DECENTER_Y, 160, false, -SIT.DECENTER_Y)
mesh("sit_ring_d", "sit_sc_d", "triangles", v, i, M.white)
if SIT.HALF_RING then
	v, i = clipped_ring(SIT.CENTER_R / 2, LW * 0.5, SIT.CENTER_Y, 72)
	mesh("sit_half_c", "sit_sc_c", "triangles", v, i, M.white)
end
-- course line to the active steerpoint (MENU: CRS STR), line to the
-- primary designated target (blue)
local function seg_line(name, prefix, mat, w)
	line_obj(name, "sit_own", mat, w,
		{prefix .. "AX", prefix .. "AY", prefix .. "BX", prefix .. "BY", prefix .. "VIS"},
		{{"parameter_in_range", 4, 0.5, 1.5},
		 {"line_object_set_point_using_parameters", 0, 0, 1, G, G},
		 {"line_object_set_point_using_parameters", 1, 2, 3, G, G}})
end
seg_line("sit_crs", "F15SIT_CRS_", M.white, 0.003)
seg_line("sit_pdt", "F15SIT_PDT_", M.pdt, 0.003)

-- compass rose around the ownship: ticks every 10 deg, 3 6 E 12 ... every
-- 30 deg. Turns with the heading (heading-up); the numbers stay upright.
local function rose(name, parent, R, len, numr)
	simple(name, parent, {0, 0, 0}, {"F15SIT_ROT"}, {{"rotate_using_parameter", 0, 1}})
	local tv, ti = {}, {}
	local w = LW * 0.6
	for deg = 10, 350, 10 do
		if deg % 30 ~= 0 then
			local a = math.rad(90 - deg)
			local ca, sa = math.cos(a), math.sin(a)
			local px, py = -sa * w / 2, ca * w / 2
			local r0, r1 = R - len / 2, R + len / 2
			local k = #tv
			tv[k + 1] = {r0 * ca + px, r0 * sa + py}; tv[k + 2] = {r1 * ca + px, r1 * sa + py}
			tv[k + 3] = {r1 * ca - px, r1 * sa - py}; tv[k + 4] = {r0 * ca - px, r0 * sa - py}
			ti[#ti + 1] = k; ti[#ti + 1] = k + 1; ti[#ti + 1] = k + 2
			ti[#ti + 1] = k; ti[#ti + 1] = k + 2; ti[#ti + 1] = k + 3
		end
	end
	mesh(name .. "_t", name, "triangles", tv, ti, M.white)
	local names = {[0] = "N", [30] = "3", [60] = "6", [90] = "E", [120] = "12", [150] = "15",
	               [180] = "S", [210] = "21", [240] = "24", [270] = "W", [300] = "30", [330] = "33"}
	for deg = 0, 330, 30 do
		local a = math.rad(deg)
		local nm = name .. "_" .. deg
		simple(nm, name, {numr * math.sin(a), numr * math.cos(a), 0})
		simple(nm .. "_u", nm, {0, 0, 0}, {"F15SIT_ROT"}, {{"rotate_using_parameter", 0, -1}})
		text(nm .. "_t", nm .. "_u", {0, 0, 0}, F.white, TXT_ROSE, "CenterCenter", names[deg])
	end
end
-- centred: the compass on the range ring; decentred: a small one
rose("sit_rose", "sit_sc_c", SIT.CENTER_R, 0.022, SIT.CENTER_R)
rose("sit_rose_d", "sit_sc_d", SIT.ROSE_R, 0.016, SIT.ROSE_R)

-- radar coverage: two cyan lines from the ownship along the edges of the
-- radar's scan, as long as the radar's range scale (end points from the
-- device, clipped to the box)
for k = 1, 2 do
	local p = "F15SIT_AZ" .. k .. "_"
	line_obj("sit_az" .. k, "sit_own", M.cyan, 0.004,
		{p .. "AX", p .. "AY", p .. "BX", p .. "BY", p .. "VIS"},
		{{"parameter_in_range", 4, 0.5, 1.5},
		 {"line_object_set_point_using_parameters", 0, 0, 1, G, G},
		 {"line_object_set_point_using_parameters", 1, 2, 3, G, G}})
end

-- drawings (cartridge / mission: lines, areas, rings), MENU: LINES ----------
do
	local gm = {M.cyan, M.thr_i, col(242, 160, 160, 200)}
	local gf = {F.cyan, F.thr_i, F.red}
	-- (v0.9 perf: in blocks of 16 pieces; a block is shown only while one of
	-- its pieces is used)
	for b = 1, math.ceil(SIT.GEO_SEGS / 16) do
		simple("sit_gb" .. b, "sit_own", {0, 0, 0}, {"F15SIT_GB" .. b}, {vis(0, 0.5, 1.5)})
	end
	for j = 1, SIT.GEO_SEGS do
		local s = "F15SIT_GS" .. j .. "_"
		for ci, cm in ipairs(gm) do
			line_obj("sit_gs" .. j .. "_" .. ci, "sit_gb" .. math.ceil(j / 16), cm, 0.003,
				{s .. "AX", s .. "AY", s .. "BX", s .. "BY", s .. "VIS"},
				{{"parameter_in_range", 4, ci - 0.5, ci + 0.5},
				 {"line_object_set_point_using_parameters", 0, 0, 1, G, G},
				 {"line_object_set_point_using_parameters", 1, 2, 3, G, G}})
		end
	end
	for k = 1, SIT.GEO_LABELS do
		local s = "F15SIT_GL" .. k .. "_"
		local pp, cc = at(s .. "X", s .. "Y", {{s .. "VIS", 0.5, 3.5}})
		simple("sit_gl" .. k, "sit_own", {0, 0, 0}, pp, cc)
		for ci, cf in ipairs(gf) do
			text("sit_gl" .. k .. "_" .. ci, "sit_gl" .. k, {0, 0.035, 0}, cf, TXT_TINY, "CenterCenter", nil, s .. "TXT",
				{s .. "VIS", ci - 0.5, ci + 0.5})
		end
	end
end

-- ground threats: MEZ rings, a background layer (dim red outside the ring,
-- bright red inside it) ---------------------------------------------------
-- (v0.9 perf: each ring's pieces in a group of their own, shown only while
-- the ring is drawn: hidden groups cost nothing per frame)
for g = 1, SIT.MAX_THREATS do
	local p = "F15SIT_G" .. g .. "_"
	for ci, cm in ipairs({M.thr_o, M.thr_i}) do
		local grp = "sit_gr" .. g .. "_" .. ci
		simple(grp, "sit_own", {0, 0, 0}, {p .. "RV"}, {vis(0, ci - 0.5, ci + 0.5)})
		for j = 1, SIT.RING_SEGS do
			local s = p .. "S" .. j .. "_"
			line_obj("sit_g" .. g .. "_" .. j .. "_" .. ci, grp, cm, 0.003,
				{s .. "AX", s .. "AY", s .. "BX", s .. "BY", s .. "VIS"},
				{{"parameter_in_range", 4, 0.5, 1.5},
				 {"line_object_set_point_using_parameters", 0, 0, 1, G, G},
				 {"line_object_set_point_using_parameters", 1, 2, 3, G, G}})
		end
	end
	local pp, cc = at(p .. "X", p .. "Y", {{p .. "VIS", 0.5, 1.5}})
	simple("sit_g" .. g, "sit_own", {0, 0, 0}, pp, cc)
	-- site: small cross, label just below it (not on top of a contact there)
	for ci, cm in ipairs({M.thr_o, M.thr_i}) do
		local lo, hi = (ci == 1) and -0.5 or 1.5, (ci == 1) and 1.5 or 2.5
		v, i = poly_lines({{-0.012, 0}, {0.012, 0}}, false)
		mesh("sit_g" .. g .. "_x1_" .. ci, "sit_g" .. g, "lines", v, i, cm, nil, {p .. "RING"}, {vis(0, lo, hi)})
		v, i = poly_lines({{0, -0.012}, {0, 0.012}}, false)
		mesh("sit_g" .. g .. "_x2_" .. ci, "sit_g" .. g, "lines", v, i, cm, nil, {p .. "RING"}, {vis(0, lo, hi)})
		text("sit_g" .. g .. "_t" .. ci, "sit_g" .. g, {0, -0.04, 0}, (ci == 1) and F.thr_o or F.thr_i, TXT_TINY,
			"CenterCenter", nil, p .. "TXT", {p .. "RING", lo, hi})
	end
end

-- route: yellow line, steerpoints = triangles with the number inside;
-- the active one gets a second, larger triangle ------------------------------
local TRI = {{0, 0.065}, {0.056, -0.035}, {-0.056, -0.035}}
for n = 1, SIT.MAX_WPTS do
	local p = "F15SIT_W" .. n .. "_"
	line_obj("sit_leg" .. n, "sit_own", M.route, 0.004,
		{p .. "AX", p .. "AY", p .. "BX", p .. "BY", p .. "SEG"},
		{{"parameter_in_range", 4, 0.5, 1.5},
		 {"line_object_set_point_using_parameters", 0, 0, 1, G, G},
		 {"line_object_set_point_using_parameters", 1, 2, 3, G, G}})
	local pp, cc = at(p .. "X", p .. "Y", {{p .. "VIS", 0.5, 2.5}})
	simple("sit_w" .. n, "sit_own", {0, 0, 0}, pp, cc)
	v, i = outline(TRI, LW * 0.8, false)
	mesh("sit_w" .. n .. "_t", "sit_w" .. n, "triangles", v, i, M.route)
	v, i = outline(scaled(TRI, 1.35), LW * 0.8, false)
	mesh("sit_w" .. n .. "_a", "sit_w" .. n, "triangles", v, i, M.route, nil, {p .. "VIS"}, {vis(0, 1.5, 2.5)})
	text("sit_w" .. n .. "_n", "sit_w" .. n, {0, -0.006, 0}, F.route, TXT_TINY, "CenterCenter", nil, p .. "NUM", nil, "%.0f")
end

-- bullseye: yellow double circle ---------------------------------------------
do
	local pp, cc = at("F15SIT_BE_X", "F15SIT_BE_Y", {{"F15SIT_BE_VIS", 0.5, 1.5}})
	simple("sit_be", "sit_own", {0, 0, 0}, pp, cc)
	v, i = band(circle_pts(0.032, 28), circle_pts(0.032 - LW * 0.8, 28))
	mesh("sit_be_o", "sit_be", "triangles", v, i, M.bull)
	v, i = band(circle_pts(0.015, 16), circle_pts(0.015 - LW * 0.8, 16))
	mesh("sit_be_i", "sit_be", "triangles", v, i, M.bull)
end

-- contacts (foreground) -------------------------------------------------------
local tri  = {{0, S * 1.1}, {S * 0.85, -S * 0.7}, {-S * 0.85, -S * 0.7}}
local sqr  = {{-S * 0.7, S * 0.7}, {S * 0.7, S * 0.7}, {S * 0.7, -S * 0.7}, {-S * 0.7, -S * 0.7}}
local circ = circle_pts(S * 0.8, 24)
local circa = circle_pts(S * 1.0, 28)
-- [code] = {points, dotted, turns with course}
local shapes = {
	[1]  = {circ, true, false},  [11] = {circ, false, false},
	[2]  = {tri, true, true},    [12] = {tri, false, true},
	[3]  = {sqr, true, false},   [13] = {sqr, false, false},
	[4]  = {circa, true, false}, [14] = {circa, false, false},
	[5]  = {circ, false, false}, [15] = {circ, false, false},
	[6]  = {circ, true, false},  [16] = {circ, false, false},
}
local mats = {[1] = M.friend, [2] = M.hostile, [3] = M.unknown, [4] = M.friend, [5] = M.wing, [6] = M.friend}
local dot_v, dot_i = circle_fill(S * 0.22, 10)
local lv = {{-LW / 2, S * 0.85}, {LW / 2, S * 0.85}, {LW / 2, S * 0.85 + 0.05}, {-LW / 2, S * 0.85 + 0.05}}
local cmats = {M.friend, M.hostile, M.unknown, M.wing}
local cfonts = {F.cfriend, F.red, F.white, F.cyan}
-- (v0.9.x: grouped by colour - COL is set together with TYPE - so a shown
-- contact costs DCS ~11-19 elements a frame instead of 27; same picture)
local col_of = {[1] = 1, [2] = 2, [3] = 3, [4] = 1, [5] = 4, [6] = 1}    -- code % 10 -> colour group (= device CONTACT_COL)
for n = 1, SIT.MAX_CONTACTS do
	local p = "F15SIT_C" .. n .. "_"
	local base = "sit_c" .. n
	local pp, cc = at(p .. "X", p .. "Y", {{p .. "TYPE", 0.5, 99}})
	simple(base, "sit_own", {0, 0, 0}, pp, cc)
	for ci, cm in ipairs(cmats) do
		local grp, rot = base .. "_k" .. ci, base .. "_r" .. ci
		simple(grp, base, {0, 0, 0}, {p .. "COL"}, {vis(0, ci - 0.1, ci + 0.1)})
		simple(rot, grp, {0, 0, 0}, {p .. "HDG"}, {{"rotate_using_parameter", 0, 1}})
		for code = 1, 16 do
			local sh = shapes[code]
			if sh and col_of[code % 10] == ci then
				local sv, si = outline(sh[1], LW, sh[2], (#sh[1] > 8) and 1 or 3)
				mesh(base .. "_s" .. code, sh[3] and rot or grp, "triangles", sv, si, mats[code % 10], nil,
					{p .. "TYPE"}, {vis(0, code - 0.1, code + 0.1)})
			end
		end
		for _, code in ipairs({4, 14, 6, 16}) do
			if col_of[code % 10] == ci then
				mesh(base .. "_dot" .. code, grp, "triangles", dot_v, dot_i, M.friend, nil, {p .. "TYPE"}, {vis(0, code - 0.1, code + 0.1)})
			end
		end
		mesh(base .. "_crs" .. ci, rot, "triangles", lv, {0, 1, 2, 0, 2, 3}, cm, nil,
			{p .. "MOV"}, {vis(0, 0.5, 1.5)})
		text(base .. "_alt" .. ci, grp, {0, -S * 1.25, 0}, cfonts[ci], TXT_TINY, "CenterCenter", nil, p .. "ALT", nil, "%.0f")
	end
	text(base .. "_num", base, {S * 1.15, S * 1.15, 0}, F.cyan, TXT_TINY, "LeftCenter", nil, p .. "NUM",
		{p .. "NUM", 0.5, 99}, "%.0f")
end

-- locked target: white brackets either side (the "hooked" mark) ------------
do
	local pp, cc = at("F15SIT_LK_X", "F15SIT_LK_Y", {{"F15SIT_LK_VIS", 0.5, 1.5}})
	simple("sit_lk", "sit_own", {0, 0, 0}, pp, cc)
	local b = S * 1.6
	for k, sx in ipairs({-1, 1}) do
		v, i = poly_lines({{sx * b * 0.6, b}, {sx * b, b}, {sx * b, -b}, {sx * b * 0.6, -b}}, false)
		mesh("sit_lk_b" .. k, "sit_lk", "lines", v, i, M.white)
	end
end

-- cursor / capture window: two cyan strokes, dashed while it follows the
-- VSD cursor --------------------------------------------------------------
do
	local pp, cc = at("F15SIT_CUR_X", "F15SIT_CUR_Y", {{"F15SIT_CUR_VIS", 0.5, 1.5}})
	simple("sit_cur", "sit_own", {0, 0, 0}, pp, cc)
	local cv, ci = {}, {}
	for _, sx in ipairs({-0.022, 0.022}) do
		for k = 0, 2 do
			local y0 = -0.036 + k * 0.027
			local b = #cv
			cv[b + 1] = {sx - 0.0025, y0}; cv[b + 2] = {sx + 0.0025, y0}
			cv[b + 3] = {sx + 0.0025, y0 + 0.018}; cv[b + 4] = {sx - 0.0025, y0 + 0.018}
			ci[#ci + 1] = b; ci[#ci + 1] = b + 1; ci[#ci + 1] = b + 2
			ci[#ci + 1] = b; ci[#ci + 1] = b + 2; ci[#ci + 1] = b + 3
		end
	end
	mesh("sit_cur_s", "sit_cur", "triangles", cv, ci, M.cyan, nil, {"F15SIT_CUR_SIT"}, {vis(0, -0.5, 0.5)})
	-- solid while the SIT page has the cursor (castle up)
	local sv, si = {}, {}
	for _, sx in ipairs({-0.022, 0.022}) do
		local b = #sv
		sv[b + 1] = {sx - 0.0025, -0.036}; sv[b + 2] = {sx + 0.0025, -0.036}
		sv[b + 3] = {sx + 0.0025, 0.036}; sv[b + 4] = {sx - 0.0025, 0.036}
		si[#si + 1] = b; si[#si + 1] = b + 1; si[#si + 1] = b + 2
		si[#si + 1] = b; si[#si + 1] = b + 2; si[#si + 1] = b + 3
	end
	mesh("sit_cur_sol", "sit_cur", "triangles", sv, si, M.cyan, nil, {"F15SIT_CUR_SIT"}, {vis(0, 0.5, 1.5)})
end
-- hooked contact: white corners around it (v0.8.2: were cyan, read as own flight)
do
	local pp, cc = at("F15SIT_HKM_X", "F15SIT_HKM_Y", {{"F15SIT_HKM_VIS", 0.5, 1.5}})
	simple("sit_hkm", "sit_own", {0, 0, 0}, pp, cc)
	local b, q = S * 1.5, S * 0.6
	for k, c in ipairs({{-1, 1}, {1, 1}, {1, -1}, {-1, -1}}) do
		v, i = poly_lines({{c[1] * b, c[2] * (b - q)}, {c[1] * b, c[2] * b}, {c[1] * (b - q), c[2] * b}}, false)
		mesh("sit_hkm_" .. k, "sit_hkm", "lines", v, i, M.white)
	end
end

-- own missiles in flight (v0.9): missile (small diamond), a thin line to
-- its target and the target's time to impact ("A 23"); up to 4
for k = 1, SIT.MAX_MSL do
	local p = "F15SIT_MSL" .. k .. "_"
	seg_line("sit_msll" .. k, p .. "L", M.white, 0.002)
	local pp, cc = at(p .. "X", p .. "Y", {{p .. "VIS", 0.5, 1.5}})
	simple("sit_msl" .. k, "sit_own", {0, 0, 0}, pp, cc)
	local d = S * 0.45
	v, i = poly_lines({{0, d}, {d, 0}, {0, -d}, {-d, 0}}, true)
	mesh("sit_msl" .. k .. "_d", "sit_msl" .. k, "lines", v, i, M.white)
	pp, cc = at(p .. "TX", p .. "TY", {{p .. "TVIS", 0.5, 1.5}})
	simple("sit_mtg" .. k, "sit_own", {0, 0, 0}, pp, cc)
	text("sit_mtg" .. k .. "_t", "sit_mtg" .. k, {S * 1.2, S * 1.6, 0}, F.white, TXT_SMALL, "LeftCenter", nil, p .. "TXT")
end
-- mark points (keybind): an x and its number, bearing / range from us
for k = 1, SIT.MAX_MARKS do
	local p = "F15SIT_MK" .. k .. "_"
	local pp, cc = at(p .. "X", p .. "Y", {{p .. "VIS", 0.5, 1.5}})
	simple("sit_mk" .. k, "sit_own", {0, 0, 0}, pp, cc)
	local d = S * 0.6
	v, i = poly_lines({{-d, -d}, {d, d}}, false)
	mesh("sit_mk" .. k .. "_a", "sit_mk" .. k, "lines", v, i, M.bull)
	v, i = poly_lines({{-d, d}, {d, -d}}, false)
	mesh("sit_mk" .. k .. "_b", "sit_mk" .. k, "lines", v, i, M.bull)
	text("sit_mk" .. k .. "_t", "sit_mk" .. k, {d * 1.4, -d * 1.6, 0}, F.route, TXT_TINY, "LeftCenter", nil, p .. "TXT")
end

-- ownship, on top --------------------------------------------------------------
simple("sit_own_r", "sit_own", {0, 0, 0}, {"F15SIT_OWN_ROT"}, {{"rotate_using_parameter", 0, 1}})
v, i = poly_lines(scaled({{0, 0.06}, {0.010, 0.026}, {0.048, 0.0}, {0.048, -0.010}, {0.009, 0.0},
	{0.007, -0.034}, {0.022, -0.047}, {0, -0.043}, {-0.022, -0.047}, {-0.007, -0.034},
	{-0.009, 0.0}, {-0.048, -0.010}, {-0.048, 0.0}, {-0.010, 0.026}}, 0.8), true)
mesh("sit_ownship", "sit_own_r", "lines", v, i, M.own)

---------------------------------------------------------------------------
-- fixed texts (corners, as on the real page)
---------------------------------------------------------------------------
-- top left: time, datalink status (small)
text("sit_time", "sit_pg", {-0.82, 0.84, 0}, F.white, TXT_SMALL, "LeftCenter", nil, "F15SIT_TIME")
-- (the datalink status line is on the SIT SETTINGS page, top left)
-- top right: range scale (big), cyan bearing-range to the active steerpoint
text("sit_rng", "sit_pg", {0.82, 0.84, 0}, F.white, TXT, "RightCenter", nil, "F15SIT_RNG", {"F15SIT_RNG_MODE", -0.5, 0.5}, "%.0f")
text("sit_rngt", "sit_pg", {0.82, 0.84, 0}, F.white, TXT, "RightCenter", nil, "F15SIT_RNG_TXT", {"F15SIT_RNG_MODE", 0.5, 1.5})
text("sit_stpt", "sit_pg", {0.82, 0.78, 0}, F.cyan, TXT_SMALL, "RightCenter", nil, "F15SIT_STPT_TXT")
-- locked target data block (top left, below the status)
simple("sit_lkb", "sit_pg", {0, 0, 0}, {"F15SIT_LK_BLK"}, {vis(0, 0.5, 1.5)})
text("sit_lk1", "sit_lkb", {-0.773, 0.641, 0}, F.white, TXT_DATA, "LeftCenter", nil, "F15SIT_LK_T1")
text("sit_lk2", "sit_lkb", {-0.773, 0.591, 0}, F.white, TXT_DATA, "LeftCenter", nil, "F15SIT_LK_T2")
text("sit_lk3", "sit_lkb", {-0.773, 0.541, 0}, F.white, TXT_DATA, "LeftCenter", nil, "F15SIT_LK_T3")
-- hooked contact data (top left, below the lock block)
simple("sit_hkb", "sit_pg", {0, 0, 0}, {"F15SIT_HK_VIS", "F15SIT_DCLT"}, {vis(0, 0.5, 1.5), {"parameter_in_range", 1, -0.5, 0.5}})
for k = 1, 4 do
	-- in the hooked contact's colour (HK_COL: 1 green, 2 red, 3 white, 4 cyan)
	for ci, cf in ipairs({F.cfriend, F.red, F.white, F.cyan}) do
		text("sit_hk" .. k .. "_" .. ci, "sit_hkb", {-0.773, 0.452 - (k - 1) * 0.050, 0}, cf, TXT_DATA, "LeftCenter", nil,
			"F15SIT_HK" .. k .. "_TXT", {"F15SIT_HK_COL", ci - 0.5, ci + 0.5})
	end
end
-- bottom left: missiles and gun (A = AIM-120, M = AIM-9, S = AIM-7, G = gun)
simple("sit_sto", "sit_pg", {0, 0, 0}, {"F15SIT_ST_VIS", "F15SIT_DCLT"}, {vis(0, 0.5, 1.5), {"parameter_in_range", 1, -0.5, 0.5}})
text("sit_st_a", "sit_sto", {-0.751, -0.497, 0}, F.white, TXT_DATA, "LeftCenter", nil, "F15SIT_ST_A", nil, "A%.0f")
text("sit_st_m", "sit_sto", {-0.751, -0.552, 0}, F.white, TXT_DATA, "LeftCenter", nil, "F15SIT_ST_M", nil, "M%.0f")
text("sit_st_s", "sit_sto", {-0.751, -0.607, 0}, F.white, TXT_DATA, "LeftCenter", nil, "F15SIT_ST_S", nil, "S%.0f")
text("sit_st_g", "sit_sto", {-0.751, -0.662, 0}, F.white, TXT_DATA, "LeftCenter", nil, "F15SIT_ST_G", nil, "G%.0f")
-- bottom right: chaff / flares, bullseye readout, master mode
text("sit_cm_c", "sit_sto", {0.773, -0.331, 0}, F.cfriend, TXT_DATA, "RightCenter", nil, "F15SIT_CHAFF", nil, "C %.0f")
text("sit_cm_f", "sit_sto", {0.773, -0.386, 0}, F.cfriend, TXT_DATA, "RightCenter", nil, "F15SIT_FLARE", nil, "F %.0f")
text("sit_cmd", "sit_sto", {0.773, -0.442, 0}, F.white, TXT_DATA, "RightCenter", nil, "F15SIT_CMD_TXT")
text("sit_pfm", "sit_sto", {0.773, -0.497, 0}, F.white, TXT_DATA, "RightCenter", nil, "F15SIT_PF_TXT")
-- ICS bands B1 B2 B3: green = working, magenta = not working
text("sit_ics_ok", "sit_sto", {0.773, -0.552, 0}, F.cfriend, TXT_DATA, "RightCenter", "B1 B2 B3", nil, {"F15SIT_ICS_FAIL", -0.5, 0.5})
text("sit_ics_bad", "sit_sto", {0.773, -0.552, 0}, F.magenta, TXT_DATA, "RightCenter", "B1 B2 B3", nil, {"F15SIT_ICS_FAIL", 0.5, 1.5})
simple("sit_bet", "sit_pg", {0, 0, 0}, {"F15SIT_BE_ON", "F15SIT_DCLT"}, {vis(0, 0.5, 1.5), {"parameter_in_range", 1, -0.5, 0.5}})
text("sit_be_t", "sit_bet", {0.773, -0.607, 0}, F.route, TXT_DATA, "RightCenter", nil, "F15SIT_BE_TXT")
text("sit_master", "sit_pg", {0.773, -0.684, 0}, F.white, TXT_DATA, "RightCenter", nil, "F15SIT_MASTER_TXT")

---------------------------------------------------------------------------
-- button labels: side labels as stacked letters, bottom row across, as on
-- the real page. Boxed = option on.
---------------------------------------------------------------------------
local SIDE_X = 0.85
local BOT_Y = -0.80
local Y5 = {0.55, 0.275, 0, -0.275, -0.55}      -- L1..L5 / R1..R5, top to bottom
local X5 = {-0.55, -0.275, 0, 0.275, 0.55}      -- B1..B5, left to right
local CW, CH = char_w(TXT_BTN), char_h(TXT_BTN) -- one character in page units
local CWT, CHT = char_w(TXT_TINY), char_h(TXT_TINY)
local LH = CH * 1.45                            -- line step of multi-line labels
local LHV = CH * 1.25                           -- line step of stacked letters (SIT side labels)
local PAD = 0.012
local function box_mesh(name, x0, y0, x1, y1, param)
	local bv, bi = poly_lines({{x0, y1}, {x1, y1}, {x1, y0}, {x0, y0}}, true)
	mesh(name, "sit_pg", "lines", bv, bi, M.white, nil, {param}, {vis(0, 0.5, 1.5)})
end
-- a word next to a side button, one letter under the other.
-- vis = {param, lo, hi}: shown only while param is in that range
local function side_label(side, k, word, onparam, visp)
	local x = (side == "L") and -SIDE_X or SIDE_X
	local name = "sit_lbl_" .. side .. k .. "_" .. word:gsub("%W", "_")
	if visp then
		simple(name, "sit_pg", {x, Y5[k], 0}, {visp[1]}, {vis(0, visp[2], visp[3])})
	else
		simple(name, "sit_pg", {x, Y5[k], 0})
	end
	local n = #word
	for j = 1, n do
		text(name .. "_" .. j, name, {0, (n - 1) / 2 * LHV - (j - 1) * LHV, 0}, F.white, TXT_BTN, "CenterCenter", word:sub(j, j))
	end
	if onparam then
		local h = (n - 1) * LHV + CH
		box_mesh("sit_box_" .. side .. k, x - CW / 2 - PAD, Y5[k] - h / 2 - PAD, x + CW / 2 + PAD, Y5[k] + h / 2 + PAD, onparam)
	end
end
local function bottom_label(k, value, onparam)
	text("sit_lbl_B" .. k, "sit_pg", {X5[k], BOT_Y, 0}, F.white, TXT_BTN, "CenterCenter", value)
	if onparam then
		local w = #value * CW
		box_mesh("sit_box_B" .. k, X5[k] - w / 2 - PAD, BOT_Y - CH / 2 - PAD, X5[k] + w / 2 + PAD, BOT_Y + CH / 2 + PAD, onparam)
	end
end
-- right 3: range AUTO (follows the radar range) or MAN; right 5: MENU. The
-- rest is on the castle switch (keybinds) and the SIT SETTINGS page
side_label("R", 3, "AUTO", nil, {"F15SIT_AUTOR", 0.5, 1.5})
side_label("R", 3, "MAN", nil, {"F15SIT_AUTOR", -0.5, 0.5})
side_label("R", 5, "MENU")
side_label("L", 5, "SET")                -- left 5: SIT SETTINGS (left 5 there comes back)
-- declutter step: shown for a moment after it changes
simple("sit_dclp", "sit_pg", {0, 0, 0}, {"F15SIT_DCL_POP"}, {vis(0, 0.5, 1.5)})
text("sit_dclp_t", "sit_dclp", {0, 0.70, 0}, F.cfriend, TXT_SMALL, "CenterCenter", nil, "F15SIT_DCL_TXT")

---------------------------------------------------------------------------
-- MENU and DTM pages (after the real MPCD menu): labels across, as there
---------------------------------------------------------------------------
local TOP_Y, BOT_Y1 = 0.84, -0.80
local function page_group(name, n)
	simple(name, "sit_root", {0, 0, 0}, {"F15SIT_PAGE"}, {vis(0, n - 0.5, n + 0.5)})
end
-- param: a parameter (box while it is 1) or {parameter, lo, hi}
local function box_in(parent, name, x0, y0, x1, y1, param, mat)
	local bv, bi = poly_lines({{x0, y1}, {x1, y1}, {x1, y0}, {x0, y0}}, true)
	local pn, lo, hi = param, 0.5, 1.5
	if type(param) == "table" then pn, lo, hi = param[1], param[2], param[3] end
	mesh(name, parent, "lines", bv, bi, mat or M.white, nil, {pn}, {vis(0, lo, hi)})
end
-- a label of one or more lines; (x, y) = its anchor at the middle line
local function lbl(parent, name, x, y, lines, align, onparam, font)
	local n, wmax = #lines, 0
	for j, s in ipairs(lines) do
		text(name .. "_" .. j, parent, {x, y + (n - 1) / 2 * LH - (j - 1) * LH, 0}, font or F.white, TXT_BTN, align, s)
		if #s > wmax then wmax = #s end
	end
	if onparam then
		local w, h = wmax * CW, (n - 1) * LH + CH
		local x0, x1 = x - w / 2, x + w / 2
		if align == "LeftCenter" then x0, x1 = x, x + w elseif align == "RightCenter" then x0, x1 = x - w, x end
		box_in(parent, name .. "_box", x0 - PAD, y - h / 2 - PAD, x1 + PAD, y + h / 2 + PAD, onparam)
	end
end
local SX = 0.86
local function L(parent, k, lines, on) lbl(parent, parent .. "_L" .. k, -SX, Y5[k], lines, "LeftCenter", on) end
local function R(parent, k, lines, on) lbl(parent, parent .. "_R" .. k, SX, Y5[k], lines, "RightCenter", on) end
local function T(parent, k, lines, on) lbl(parent, parent .. "_T" .. k, X5[k], TOP_Y - (#lines - 1) / 2 * LH, lines, "CenterCenter", on) end
local function B(parent, k, lines, on) lbl(parent, parent .. "_B" .. k, X5[k], BOT_Y1 + (#lines - 1) / 2 * LH, lines, "CenterCenter", on) end
local function cursor_x(parent, name, x, y)
	local c = 0.022
	v, i = poly_lines({{x - c, y - c}, {x + c, y + c}}, false)
	mesh(name .. "_a", parent, "lines", v, i, M.bull)
	v, i = poly_lines({{x - c, y + c}, {x + c, y - c}}, false)
	mesh(name .. "_b", parent, "lines", v, i, M.bull)
end

-- MENU ---------------------------------------------------------------------
page_group("mnu", 2)
T("mnu", 1, {"CRS", "STR"})
T("mnu", 2, {"RADIO"})
T("mnu", 4, {"ENTER", "NET"})
T("mnu", 5, {"RESET", "IPF"})
L("mnu", 1, {"ARMT"})
L("mnu", 2, {"BIT"})
L("mnu", 3, {"SIT"})
L("mnu", 4, {"WPN"})
L("mnu", 5, {"DTM"})
R("mnu", 1, {"TIME", "DATE"})
R("mnu", 2, {"OWN", "DATA"})
R("mnu", 3, {"FLIGHT", "DATA"})
R("mnu", 4, {"SIT", "SET"})
B("mnu", 1, {"VOICE", "CHANNEL"})
B("mnu", 2, {"UP"})
B("mnu", 3, {"ENTER"})
B("mnu", 4, {"DN"})
B("mnu", 5, {"AUTO", "RANGE"}, "F15SIT_AUTOR")
-- fighter channel: name, then the number in a bracket over UP / ENTER / DN
do
	local yn = -0.64
	text("mnu_fc1", "mnu", {0, yn + 2 * LH, 0}, F.white, TXT_BTN, "CenterCenter", "FIGHTER")
	text("mnu_fc2", "mnu", {0, yn + LH, 0}, F.white, TXT_BTN, "CenterCenter", "CHANNEL")
	text("mnu_fcn", "mnu", {0, yn, 0}, F.white, TXT_BTN, "CenterCenter", nil, "F15SIT_FCH", nil, "%03.0f")
	local gap = 2.2 * CW
	local xa, xb = X5[2], X5[4]
	v, i = poly_lines({{xa, yn - 0.05}, {xa, yn}, {-gap, yn}}, false)
	mesh("mnu_fcl", "mnu", "lines", v, i, M.white)
	v, i = poly_lines({{gap, yn}, {xb, yn}, {xb, yn - 0.05}}, false)
	mesh("mnu_fcr", "mnu", "lines", v, i, M.white)
end
text("mnu_tl1", "mnu", {0, 0.36, 0}, F.white, TXT_BTN, "CenterCenter", "TERMINAL LOAD:")
text("mnu_tl2", "mnu", {0, 0.36 - LH, 0}, F.white, TXT_BTN, "CenterCenter", "GO")
text("mnu_time", "mnu", {0, 0.36 - 2 * LH, 0}, F.white, TXT_BTN, "CenterCenter", nil, "F15SIT_TIME")
cursor_x("mnu", "mnu_cur", -0.20, 0.02)
text("mnu_net", "mnu", {0, -0.20, 0}, F.white, TXT_BTN, "CenterCenter", nil, "F15SIT_NET_TXT")

-- DTM ----------------------------------------------------------------------
page_group("dtm", 3)
L("dtm", 1, {"READ"})
L("dtm", 2, {"READ", "STATUS"})
L("dtm", 3, {"DTM", "DR"})
R("dtm", 2, {"WRITE"})
R("dtm", 3, {"WRITE", "STATUS"})
R("dtm", 5, {"M"})
B("dtm", 5, {"CC BUF", "CLEAR"})
do
	local items = {"A/A OPS", "A/G OPS", "HUD DATA", "NAV DATA", "OWS DATA", "CBIT", "RDR CBIT",
	               "IBIT", "RDR IBIT", "TEWS BIT", "ICS LOG", "RWR LOG", "OFP ID"}
	local y0, step = 0.40, LH * 0.95
	for k, s in ipairs(items) do
		text("dtm_it" .. k, "dtm", {-0.20, y0 - (k - 1) * step, 0}, F.white, TXT_BTN, "LeftCenter", s)
	end
end
text("dtm_st", "dtm", {0, 0.58, 0}, F.white, TXT_BTN, "CenterCenter", nil, "F15SIT_DTM_TXT")
-- cartridge choice (CART) and the one in use
text("dtm_cart", "dtm", {0, -0.50, 0}, F.cyan, TXT_SMALL, "CenterCenter", nil, "F15SIT_DTM_CART_TXT")
text("dtm_ld", "dtm", {0, -0.58, 0}, F.cfriend, TXT_SMALL, "CenterCenter", nil, "F15SIT_DTM_LOADED_TXT")
B("dtm", 3, {"CART"})
cursor_x("dtm", "dtm_cur", 0.36, -0.30)

---------------------------------------------------------------------------
-- pages behind the MENU (v0.6). Layouts after the real F-15C MPCD where it
-- is known (redflagsim.com F-15C MPCD docs, BMS TO 1F-15C-34-1-1): A/A
-- page = stores around the aircraft outline, selected station green with a
-- white frame ("AMRM / 120B"), gun count, CHF / FLR.
---------------------------------------------------------------------------
local CWS = char_w(TXT_SMALL)
local function title(parent, s, y)
	text(parent .. "_title", parent, {0, y or 0.64, 0}, F.white, TXT_BTN, "CenterCenter", s)
end
local function rows(parent, prefix, n, x, y0, step, defs, font, align)
	for k = 1, n do
		text(parent .. "_r" .. k, parent, {x, y0 - (k - 1) * step, 0}, font or F.white, defs or TXT_SMALL, align or "LeftCenter",
			nil, "F15SIT_" .. prefix .. k .. "_TXT")
	end
end

-- aircraft outline: F-15C top view from its real proportions (19.4 m long,
-- 13 m span, 45 deg wing sweep), metres: x out from the centreline, y aft
-- from the nose; drawn at K page units per metre, nose up
local K, Y0 = 0.060, 9.6
local PLAN_M = {{0, 0}, {0.18, 0.5}, {0.38, 1.3}, {0.55, 2.3}, {0.68, 3.4}, {0.80, 4.4}, {0.92, 5.2},
	{1.15, 5.35}, {1.85, 5.55}, {1.90, 6.4}, {1.92, 7.9},
	{6.55, 12.55}, {6.60, 12.7}, {6.60, 13.65}, {6.45, 13.8},
	{2.35, 14.55},
	{2.30, 15.4}, {4.45, 17.35}, {4.55, 17.55}, {4.50, 18.45}, {4.35, 18.6}, {2.25, 18.35},
	{2.05, 18.55}, {1.65, 19.25}, {1.25, 19.35}, {0.95, 19.0}, {0.55, 18.85}, {0, 18.7}}
local function pm(x, y) return {x * K, (Y0 - y) * K} end
local PLAN = {}
for _, q in ipairs(PLAN_M) do PLAN[#PLAN + 1] = pm(q[1], q[2]) end
for k = #PLAN_M - 1, 2, -1 do PLAN[#PLAN + 1] = pm(-PLAN_M[k][1], PLAN_M[k][2]) end
local FINS = {{pm(1.95, 14.0), pm(2.05, 18.9)}, {pm(-1.95, 14.0), pm(-2.05, 18.9)}}
-- stations 1..11 = 2A 2 2B 3 4 5 6 7 8B 8 8A: position (m), label offset (page), alignment
local function sta(x, y, lx, ly, al) local q = pm(x, y); return {q[1], q[2], lx, ly, al} end
local STA_POS = {
	sta(-3.85, 11.4, -0.03, 0, "RightCenter"), sta(-3.30, 11.2, 0, 0.06, "CenterCenter"),
	sta(-2.75, 11.4, 0, -0.06, "CenterCenter"),
	sta(-1.35, 9.3, 0, 0.05, "CenterCenter"), sta(-1.35, 13.2, 0, -0.05, "CenterCenter"),
	sta(0, 11.0, 0, -0.045, "CenterCenter"),
	sta(1.35, 13.2, 0, -0.05, "CenterCenter"), sta(1.35, 9.3, 0, 0.05, "CenterCenter"),
	sta(2.75, 11.4, 0, -0.06, "CenterCenter"), sta(3.30, 11.2, 0, 0.06, "CenterCenter"),
	sta(3.85, 11.4, 0.03, 0, "LeftCenter"),
}
local function planform(parent, oy)
	simple(parent .. "_pf", parent, {0, oy, 0})
	v, i = poly_lines(PLAN, true)
	mesh(parent .. "_pf_l", parent .. "_pf", "lines", v, i, M.planf)
	for k, f in ipairs(FINS) do
		v, i = poly_lines(f, false)
		mesh(parent .. "_pf_f" .. k, parent .. "_pf", "lines", v, i, M.planf)
	end
	local sq = {{-0.008, 0.008}, {0.008, 0.008}, {0.008, -0.008}, {-0.008, -0.008}}
	for n, sp in ipairs(STA_POS) do
		local pfx = "F15SIT_STA" .. n .. "_"
		local nm = parent .. "_s" .. n
		simple(nm, parent .. "_pf", {sp[1], sp[2], 0})
		v, i = poly_lines(sq, true)
		mesh(nm .. "_m", nm, "lines", v, i, M.white, nil, {pfx .. "VIS"}, {vis(0, 0.5, 1.5)})
		mesh(nm .. "_ms", nm, "triangles", sq, {0, 1, 2, 0, 2, 3}, M.sel, nil, {pfx .. "VIS"}, {vis(0, 1.5, 2.5)})
		local lp, al = {sp[3], sp[4], 0}, sp[5]
		text(nm .. "_tw", nm, lp, F.white, TXT_TINY, al, nil, pfx .. "TXT", {pfx .. "VIS", 0.5, 1.5})
		text(nm .. "_tg", nm, lp, F.cfriend, TXT_TINY, al, nil, pfx .. "TXT", {pfx .. "VIS", 1.5, 2.5})
	end
end
local ALWAYS = "F15SIT_READY"

-- A/A (ARMT) ---------------------------------------------------------------
page_group("aa", SIT.PG.ARMT)
L("aa", 1, {"A/A"}, ALWAYS)
L("aa", 2, {"A/G"})
L("aa", 3, {"CBT", "JETT"})
L("aa", 4, {"WPN", "LOAD"})
L("aa", 5, {"TRNG"}, "F15SIT_TRNG")
R("aa", 1, {"SIT"})
R("aa", 2, {"ICS", "DCLT"}, "F15SIT_ICSD")
text("aa_R3", "aa", {SX, Y5[3], 0}, F.white, TXT_BTN, "RightCenter", nil, "F15SIT_CMD_TXT")
text("aa_R4", "aa", {SX, Y5[4], 0}, F.white, TXT_BTN, "RightCenter", nil, "F15SIT_PF_TXT")
R("aa", 5, {"M"})
planform("aa", -0.02)
-- selected station, green in a white frame
text("aa_sel", "aa", {0, 0.67, 0}, F.cfriend, TXT_SMALL, "CenterCenter", nil, "F15SIT_AA_SEL_TXT")
box_in("aa", "aa_sel_box", -6.5 * CWS - PAD, 0.67 - char_h(TXT_SMALL) / 2 - PAD, 6.5 * CWS + PAD,
	0.67 + char_h(TXT_SMALL) / 2 + PAD, "F15SIT_AA_SEL_VIS")
text("aa_gun", "aa", {0, -0.68, 0}, F.white, TXT_SMALL, "CenterCenter", nil, "F15SIT_AA_GUN", nil, "GUN %.0f")
text("aa_chf", "aa", {-0.36, -0.68, 0}, F.cfriend, TXT_SMALL, "CenterCenter", nil, "F15SIT_AA_CHF", nil, "CHF %.0f")
text("aa_flr", "aa", {0.36, -0.68, 0}, F.cfriend, TXT_SMALL, "CenterCenter", nil, "F15SIT_AA_FLR", nil, "FLR %.0f")
text("aa_ics", "aa", {0, -0.76, 0}, F.white, TXT_TINY, "CenterCenter", nil, "F15SIT_AA_ICS_TXT")
-- ICS bands
for k = 1, 3 do
	text("aa_b" .. k, "aa", {0.36, -0.36 - (k - 1) * 0.055, 0}, F.white, TXT_TINY, "LeftCenter", nil, "F15SIT_AA_B" .. k .. "_TXT")
end

-- CBT JETT -----------------------------------------------------------------
page_group("cj", SIT.PG.JETT)
for g, s in ipairs({"L", "LC", "C", "RC", "R"}) do T("cj", g, {s}, "F15SIT_JG" .. g) end
L("cj", 1, {"PROG", "1"}, {"F15SIT_JPROG", 0.5, 1.5})
L("cj", 2, {"PROG", "2"}, {"F15SIT_JPROG", 1.5, 2.5})
L("cj", 5, {"ARMT"})
R("cj", 5, {"M"})
title("cj", "COMBAT JETTISON", 0.66)
planform("cj", -0.04)
-- station groups chosen for this program: green frames
-- (around the station squares of each group, outline drawn at -0.04)
local JG_STA = {{1, 2, 3}, {4, 5}, {6}, {7, 8}, {9, 10, 11}}
for g, list in ipairs(JG_STA) do
	local x0, y0, x1, y1 = 9, 9, -9, -9
	for _, n in ipairs(list) do
		local sp = STA_POS[n]
		x0, x1 = math.min(x0, sp[1]), math.max(x1, sp[1])
		y0, y1 = math.min(y0, sp[2] - 0.04), math.max(y1, sp[2] - 0.04)
	end
	local m = 0.022
	box_in("cj", "cj_g" .. g, x0 - m, y0 - m, x1 + m, y1 + m, "F15SIT_JG" .. g, M.sel)
end
text("cj_txt", "cj", {0, -0.68, 0}, F.white, TXT_SMALL, "CenterCenter", nil, "F15SIT_JETT_TXT")

-- WPN LOAD -----------------------------------------------------------------
page_group("wl", SIT.PG.LOAD)
title("wl", "WEAPON LOAD")
rows("wl", "LOAD", #SIT.STATIONS + 2, -0.62, 0.52, 0.075, TXT_TINY)
L("wl", 5, {"ARMT"})
R("wl", 5, {"M"})

-- BIT ----------------------------------------------------------------------
page_group("bt", SIT.PG.BIT)
text("bt_hdr", "bt", {0, 0.64, 0}, F.white, TXT_BTN, "CenterCenter", nil, "F15SIT_BIT_TXT")
for n, row in ipairs(SIT.BIT_ROWS) do
	local y = 0.52 - (n - 1) * 0.074
	local pn = "F15SIT_BIT" .. n
	text("bt_n" .. n, "bt", {-0.45, y, 0}, F.white, TXT_SMALL, "LeftCenter", row[1])
	text("bt_go" .. n, "bt", {0.45, y, 0}, F.cfriend, TXT_SMALL, "RightCenter", "GO", nil, {pn, 0.5, 1.5})
	text("bt_ng" .. n, "bt", {0.45, y, 0}, F.red, TXT_SMALL, "RightCenter", "NO GO", nil, {pn, 1.5, 2.5})
	text("bt_ts" .. n, "bt", {0.45, y, 0}, F.white, TXT_SMALL, "RightCenter", "TEST", nil, {pn, -0.5, 0.5})
end
L("bt", 1, {"CBIT"}, {"F15SIT_BIT_MODE", 0.5, 1.5})
L("bt", 2, {"IBIT"}, {"F15SIT_BIT_MODE", 1.5, 2.5})
R("bt", 5, {"M"})

-- TIME / DATE --------------------------------------------------------------
page_group("td", SIT.PG.TIME)
title("td", "TIME / DATE")
rows("td", "TD", 6, -0.45, 0.42, 0.10)
R("td", 1, {"ZULU"}, {"F15SIT_ZULU", 0.5, 1.5})
R("td", 2, {"LOCAL"}, {"F15SIT_ZULU", -0.5, 0.5})
R("td", 5, {"M"})

-- OWN DATA -----------------------------------------------------------------
page_group("od", SIT.PG.OWN)
title("od", "OWN DATA")
rows("od", "OWN", 11, -0.58, 0.50, 0.085)
R("od", 5, {"M"})

-- FLIGHT DATA: L1..L5 = friendly aircraft to pick as flight members (boxed
-- = member, * = player), UP / DN = more of them; right: the members
page_group("fd", SIT.PG.FLT)
title("fd", "FLIGHT DATA")
for k = 1, 5 do
	local nm = "fd_c" .. k
	text(nm, "fd", {-SX, Y5[k], 0}, F.white, TXT_TINY, "LeftCenter", nil, "F15SIT_FC" .. k .. "_TXT")
	box_in("fd", nm .. "_box", -SX - PAD, Y5[k] - CHT / 2 - PAD, -SX + 15 * CWT + PAD, Y5[k] + CHT / 2 + PAD,
		"F15SIT_FC" .. k .. "_ON")
end
rows("fd", "FLT", 7, 0.0, 0.46, 0.085, TXT_TINY, F.cyan)
B("fd", 2, {"UP"})
B("fd", 4, {"DN"})
text("fd_pg", "fd", {0, -0.775, 0}, F.white, TXT_TINY, "CenterCenter", nil, "F15SIT_FC_PG_TXT")
R("fd", 5, {"M"})

-- WPN (A/G weapon video) ---------------------------------------------------
-- SIT SETTINGS (MENU, right 4): what the SIT page shows. Boxed = shown.
page_group("ss", SIT.PG.SETS)
title("ss", "SIT SETTINGS", 0.60)
text("ss_status", "ss", {-0.80, 0.80, 0}, F.white, TXT_SMALL, "LeftCenter", nil, "F15SIT_STATUS")
L("ss", 1, {"DL"}, "F15SIT_DL")
L("ss", 2, {"ROUTE"}, "F15SIT_RTE")
L("ss", 3, {"THREAT", "RINGS"}, "F15SIT_THR")
L("ss", 4, {"LINES"}, "F15SIT_LINES")
L("ss", 5, {"SIT"})
R("ss", 1, {"CRS", "STR"}, "F15SIT_CRS")
R("ss", 2, {"DECLUTTER"})
text("ss_dcl", "ss", {SX - 10.5 * CW, Y5[2], 0}, F.cfriend, TXT_BTN, "RightCenter", nil, "F15SIT_DCL_TXT")
R("ss", 3, {"AUTO", "RANGE"}, "F15SIT_AUTOR")
R("ss", 5, {"M"})
text("ss_n1", "ss", {0, 0.10, 0}, F.white, TXT_SMALL, "CenterCenter", "CASTLE UP     SIT CURSOR")
text("ss_n2", "ss", {0, 0.02, 0}, F.white, TXT_SMALL, "CenterCenter", "CASTLE RIGHT  CNTR / DCNT")
text("ss_n3", "ss", {0, -0.06, 0}, F.white, TXT_SMALL, "CenterCenter", "CASTLE LEFT   EXP")
text("ss_n4", "ss", {0, -0.14, 0}, F.white, TXT_SMALL, "CenterCenter", "CASTLE DOWN   FORM")
text("ss_n5", "ss", {0, -0.24, 0}, F.white, TXT_TINY, "CenterCenter", "RANGE: SLEW THE CURSOR TO THE TOP / BOTTOM EDGE")

-- RADIO (MENU, top 2): UHF-1 (mission) left, UHF-2 (flight) right; UP / DN
-- on each side pick the channel (tunes SRS); EDIT 1 / EDIT 2 change the
-- frequency of that radio's channel with the bottom row
page_group("rd", SIT.PG.RADIO)
L("rd", 1, {"UP"}); L("rd", 2, {"DN"})
R("rd", 1, {"UP"}); R("rd", 2, {"DN"})
R("rd", 5, {"M"})
T("rd", 1, {"EDIT", "1"}, {"F15SIT_RAD_EDIT", 0.5, 1.5})
T("rd", 5, {"EDIT", "2"}, {"F15SIT_RAD_EDIT", 1.5, 2.5})
simple("rd_ed", "rd", {0, 0, 0}, {"F15SIT_RAD_EDIT"}, {vis(0, 0.5, 2.5)})
B("rd_ed", 1, {"<"}); B("rd_ed", 2, {"-"}); B("rd_ed", 3, {"ENTR"}); B("rd_ed", 4, {"+"}); B("rd_ed", 5, {">"})
do
	local CWD, CHD = char_w(TXT_DATA), char_h(TXT_DATA)
	local XC = {-0.62, 0.06}
	for r = 1, 2 do
		local x = XC[r]
		text("rd_h" .. r, "rd", {x, 0.60, 0}, F.white, TXT_SMALL, "LeftCenter", (r == 1) and "UHF-1 MSN" or "UHF-2 FLT")
		text("rd_c" .. r, "rd", {x, 0.53, 0}, F.cyan, TXT_SMALL, "LeftCenter", nil, "F15SIT_RAD" .. r .. "_CUR_TXT")
		for k = 1, 20 do
			local y = 0.44 - (k - 1) * 0.052
			text("rd_r" .. r .. "_" .. k, "rd", {x, y, 0}, F.white, TXT_DATA, "LeftCenter", nil, "F15SIT_RAD" .. r .. "_" .. k .. "_TXT")
			box_in("rd", "rd_b" .. r .. "_" .. k, x - PAD, y - CHD / 2 - PAD, x + 10 * CWD + PAD, y + CHD / 2 + PAD,
				{"F15SIT_RAD" .. r .. "_ACT", k - 0.5, k + 0.5})
		end
	end
	text("rd_src", "rd", {0, 0.70, 0}, F.white, TXT_TINY, "CenterCenter", nil, "F15SIT_RAD_SRC_TXT")
	text("rd_et", "rd_ed", {-0.32, -0.62, 0}, F.cfriend, TXT_SMALL, "LeftCenter", nil, "F15SIT_RAD_E_TXT")
	text("rd_ec", "rd_ed", {-0.32, -0.665, 0}, F.cfriend, TXT_SMALL, "LeftCenter", nil, "F15SIT_RAD_EC_TXT")
	text("rd_em", "rd_ed", {0, -0.71, 0}, F.red, TXT_TINY, "CenterCenter", nil, "F15SIT_RAD_EM_TXT")
end

-- CMDS programs (A/A page, right 3): view and change the six programs
page_group("cm", SIT.PG.CMDS)
title("cm", "CMD PROGRAMS", 0.60)
T("cm", 1, {"CHF"}, {"F15SIT_CM_FLD", 0.5, 1.5})
T("cm", 2, {"FLR"}, {"F15SIT_CM_FLD", 1.5, 2.5})
T("cm", 3, {"INT"}, {"F15SIT_CM_FLD", 2.5, 3.5})
T("cm", 4, {"CYC"}, {"F15SIT_CM_FLD", 3.5, 4.5})
L("cm", 1, {"UP"})
L("cm", 2, {"DN"})
L("cm", 3, {"SET", "ACT"})
L("cm", 4, {"DFLT"})
L("cm", 5, {"ARMT"})
R("cm", 5, {"M"})
B("cm", 2, {"-"})
B("cm", 4, {"+"})
do
	local x0, y0, step, n = -0.40, 0.34, 0.085, 24
	text("cm_hdr", "cm", {x0, y0 + step, 0}, F.white, TXT_SMALL, "LeftCenter", " PRG   CHF FLR   INT CYC")
	rows("cm", "CM", 6, x0, y0, step)
	local hh = char_h(TXT_SMALL)
	for k = 1, 6 do
		local y = y0 - (k - 1) * step
		box_in("cm", "cm_box" .. k, x0 - PAD, y - hh / 2 - PAD, x0 + n * CWS + PAD, y + hh / 2 + PAD, {"F15SIT_CM_ROW", k - 0.5, k + 0.5})
	end
	text("cm_note", "cm", {0, -0.40, 0}, F.white, TXT_TINY, "CenterCenter", "> ACTIVE   CHANGES KEPT UNTIL A CARTRIDGE IS LOADED")
	text("cm_sel", "cm", {0, -0.52, 0}, F.cfriend, TXT_SMALL, "CenterCenter", nil, "F15SIT_CM_SEL_TXT")
end

page_group("wv", SIT.PG.WPN)
text("wv_t1", "wv", {0, 0.10, 0}, F.white, TXT_BTN, "CenterCenter", "A/G WEAPON VIDEO")
text("wv_t2", "wv", {0, -0.02, 0}, F.white, TXT_BTN, "CenterCenter", "NO VIDEO")
L("wv", 1, {"ARMT"})
R("wv", 5, {"M"})

---------------------------------------------------------------------------
-- start-up screen (power on, or the knob out of OFF): F15SIT_BOOT 2 = test
-- pattern, 3 = GO, then the page. Outside sit_root: it shows while the page
-- is still hidden.
---------------------------------------------------------------------------
simple("sit_boot", nil, {0, 0, 0}, {"F15SIT_BOOT"}, {{"parameter_in_range", 0, 1.5, 3.5}})
mesh("sit_boot_bg", "sit_boot", "triangles", {{-1, 1}, {1, 1}, {1, -1}, {-1, -1}}, {0, 1, 2, 0, 2, 3}, M.black)
do
	local b = 0.80
	local v, i = poly_lines({{-b, b}, {b, b}, {b, -b}, {-b, -b}}, true)
	mesh("sit_boot_frame", "sit_boot", "lines", v, i, M.label)
	v, i = poly_lines({{-0.06, 0}, {0.06, 0}}, false)
	mesh("sit_boot_x1", "sit_boot", "lines", v, i, M.label)
	v, i = poly_lines({{0, -0.06}, {0, 0.06}}, false)
	mesh("sit_boot_x2", "sit_boot", "lines", v, i, M.label)
	-- colour bar: the page's colours, a test pattern
	local cols = {M.friend, M.hostile, M.unknown, M.cyan, M.route, M.pdt}
	for k, m in ipairs(cols) do
		local x0 = -0.36 + (k - 1) * 0.12
		mesh("sit_boot_c" .. k, "sit_boot", "triangles", {{x0, -0.42}, {x0 + 0.10, -0.42}, {x0 + 0.10, -0.50}, {x0, -0.50}},
			{0, 1, 2, 0, 2, 3}, m)
	end
	text("sit_boot_t1", "sit_boot", {0, 0.30, 0}, F.green, TXT_BTN, "CenterCenter", "MPCD")
	simple("sit_boot_p2", "sit_boot", {0, 0, 0}, {"F15SIT_BOOT"}, {{"parameter_in_range", 0, 1.5, 2.5}})
	text("sit_boot_t2", "sit_boot_p2", {0, 0.18, 0}, F.green, TXT_SMALL, "CenterCenter", "SELF TEST")
	simple("sit_boot_p3", "sit_boot", {0, 0, 0}, {"F15SIT_BOOT"}, {{"parameter_in_range", 0, 2.5, 3.5}})
	text("sit_boot_t3", "sit_boot_p3", {0, 0.18, 0}, F.green, TXT_SMALL, "CenterCenter", "SELF TEST  GO")
end

---------------------------------------------------------------------------
-- brightness (the MPCD's knob NIGHT / DAY and its BRT rocker): a black
-- see-through cover over everything, F15SIT_DIM 1..19 = 5..95 % dark.
-- Last in the list, so it is drawn over the page.
---------------------------------------------------------------------------
simple("sit_dim", nil, {0, 0, 0}, {"F15SIT_DIM"}, {{"parameter_in_range", 0, 0.5, 19.5}})
for k = 1, 19 do
	mesh("sit_dim" .. k, "sit_dim", "triangles", {{-1, 1}, {1, 1}, {1, -1}, {-1, -1}}, {0, 1, 2, 0, 2, 3},
		col(0, 0, 0, math.floor(k * 255 / 20 + 0.5)), nil, {"F15SIT_DIM"}, {vis(0, k - 0.5, k + 0.5)})
end
