-----------------------------------------------------------------------
-- F-15C SIT (WW): JHMCS helmet display (HELMET type, moves with the view).
-- Layout and symbols after the F-15C JHMCS (unclassified flight manual,
-- figures A1-156 / A1-157 and the HMD window tables). Positions in layout
-- degrees (K) inside the 20 deg visor circle; world symbols (TD box,
-- datalink contacts) are placed by the device along the view (radians).
--
--   window 1   heading tape on the helmet heading (all modes), the aircraft
--              heading under its caret; NAV: command heading
--   window 2   airspeed (kt)                 window 3  altitude (thousands + small hundreds)
--   (windows 4 off-boresight angle and 5 helmet heading: left out)
--   window 6/7 launch envelope scale / closure, at the envelope (right of centre)
--   window 10  weapon (A4C, S2M, M4M, gun rounds)
--   window 11  Mach                          window 12 G
--   window 13-16  NAV / R range / MIN time to go / target aspect
--   window H1  helmet alignment (power-up)
--   aircraft attitude symbol; ASE circle, steering dot and aspect line;
--   TD box (shoot cue, target altitude, ID); locator line (TLL);
--   FDL symbols: flight members, PPLI friendlies, hostiles, unknowns, SAMs
-----------------------------------------------------------------------
dofile(LockOn_Options.script_path .. "HMD/hmd_common.lua")

local P = "F15SIT_HMD_"

-- ON: 1 the full helmet display, 2 looking through the HUD (HMD.HUD_CONTACTS):
-- only the datalink contacts and the acquisition mode, everything else is
-- the HUD's
local top  = hmd_show(nil, P .. "ON", 0.5, 2.5)
local root = hmd_show(top, P .. "ON", 0.5, 1.5)
local aa   = hmd_show(root, P .. "AA", 0.5, 1.5)      -- A/A master modes
local nav  = hmd_show(root, P .. "NAV", 0.5, 1.5)     -- NAV

-- optional aiming cross (not in the manual's figures; HMD.CROSS)
if HMD.CROSS then
	local A, G = 0.9 * K, 0.3 * K
	hmd_lines(hmd_show(root, P .. "CROSS", 0.5, 1.5), {{-A, 0}, {-G, 0}, {G, 0}, {A, 0}, {0, -A}, {0, -G}, {0, G}, {0, A}},
		{0, 1, 2, 3, 4, 5, 6, 7})
end

---------------------------------------------------------------------------
-- fixed windows
---------------------------------------------------------------------------
-- 1: heading tape at the top, in every mode (below)
-- 2: airspeed
hmd_text(root, {-7.9 * K, 2.9 * K, 0}, "CenterCenter", nil, P .. "IAS", "%.0f")
-- 3: altitude: thousands, then the hundreds smaller
local altk = hmd_show(root, P .. "ALT_HI", 0.5, 1e6)
hmd_text(altk, {6.4 * K, 2.9 * K, 0}, "RightCenter", nil, P .. "ALT_HI", "%.0f")
hmd_text(root, {6.45 * K, 2.84 * K, 0}, "LeftCenter", nil, P .. "ALT_LO", "%03.0f", HMD_TXT_S)
-- (4 off-boresight angle and 5 helmet heading: left out, the heading tape
-- at the top already shows where the helmet looks)
-- H1: helmet alignment
hmd_text(hmd_show(root, P .. "ALIGN_ON", 0.5, 1.5), {0, -6.2 * K, 0}, "CenterCenter", nil, P .. "ALIGN", "%s")

-- left column: 10 weapon, 11 Mach, 12 G
local LX = -6.1 * K
local w_aam = hmd_show(aa, P .. "WPN_K", 0.5, 2.5)
hmd_text(w_aam, {LX, -0.9 * K, 0}, "LeftCenter", nil, P .. "WPN_T", "%s")
local w_gun = hmd_show(aa, P .. "WPN_K", 2.5, 3.5)
hmd_text(w_gun, {LX, -0.9 * K, 0}, "LeftCenter", nil, P .. "WPN_N", "%.0f")
hmd_text(root, {LX, -1.7 * K, 0}, "LeftCenter", nil, P .. "M", "%.2f")
hmd_text(root, {LX, -2.5 * K, 0}, "LeftCenter", nil, P .. "G", "%.1f")

-- right column: 13-16
local RX = 2.6 * K           -- (right of the attitude bar)
local lk = hmd_show(aa, P .. "LK", 0.5, 1.5)          -- A/A with a radar lock
hmd_text(lk, {RX, -1.7 * K, 0}, "LeftCenter", nil, P .. "RNG", "R %.1f")
hmd_text(lk, {RX, -3.3 * K, 0}, "LeftCenter", nil, P .. "ASP", "%s")
local nwp = hmd_show(nav, P .. "WP_ON", 0.5, 1.5)    -- NAV with a steerpoint
hmd_text(nwp, {RX, -0.9 * K, 0}, "LeftCenter", "NAV")
hmd_text(nwp, {RX, -1.7 * K, 0}, "LeftCenter", nil, P .. "WP_R", "N %.1f")
hmd_text(hmd_show(nwp, P .. "WP_TTG", 0, 999), {RX, -2.5 * K, 0}, "LeftCenter", nil, P .. "WP_TTG", "%.0f MIN")

-- aircraft attitude: a horizon bar with drooping ends and a centre caret,
-- turning with the bank (hidden while the ASE circle is up)
do
	local g = hmd_group(hmd_show(root, P .. "ATT_ON", 0.5, 1.5), {P .. "ROLL"}, {{"rotate_using_parameter", 0, 1}},
		{0, -0.9 * K, 0})
	local W, I, D, C = 2.2 * K, 0.55 * K, 0.35 * K, 0.3 * K
	hmd_lines(g, {{-W, -D}, {-W, 0}, {-W, 0}, {-I, 0}, {I, 0}, {W, 0}, {W, 0}, {W, -D},
		{-I, 0}, {-C * 0.5, 0}, {-C * 0.5, 0}, {0, C}, {0, C}, {C * 0.5, 0}, {C * 0.5, 0}, {I, 0}},
		{0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15})
end

---------------------------------------------------------------------------
-- heading tape at the top (all modes), on the helmet heading (ticks every 2 deg,
-- numbers every 10 deg, +-20 deg shown), the aircraft heading under it,
-- command heading tick (NAV)
---------------------------------------------------------------------------
do
	local Y = 7.0 * K
	for k = 1, 21 do
		local t = hmd_moving(root, P .. "TK" .. k .. "_ON", P .. "TK" .. k .. "_X", P .. "ZERO")
		hmd_lines(hmd_show(t, P .. "TK" .. k .. "_L", -0.5, 0.5), {{0, Y}, {0, Y + 0.25 * K}}, {0, 1})
		hmd_lines(hmd_show(t, P .. "TK" .. k .. "_L", 0.5, 1.5), {{0, Y}, {0, Y + 0.5 * K}}, {0, 1})
	end
	for k = 1, 5 do
		local t = hmd_moving(root, P .. "TL" .. k .. "_ON", P .. "TL" .. k .. "_X", P .. "ZERO")
		hmd_text(t, {0, Y + 1.0 * K, 0}, "CenterCenter", nil, P .. "TL" .. k .. "_V", "%02.0f", HMD_TXT_S)
	end
	hmd_lines(root, {{-4.6 * K, Y}, {4.6 * K, Y}}, {0, 1})
	-- where the helmet looks: caret under the tape; the aircraft's heading under it
	hmd_lines(root, {{-0.25 * K, Y - 0.4 * K}, {0, Y - 0.05 * K}, {0, Y - 0.05 * K}, {0.25 * K, Y - 0.4 * K}}, {0, 1, 2, 3})
	hmd_text(root, {0, Y - 1.0 * K, 0}, "CenterCenter", nil, P .. "ACHDG", "%03.0f", HMD_TXT_S)
	-- command heading (to the steerpoint): a tall tick, pinned at the tape's end when off it
	local c = hmd_moving(nav, P .. "CMD_ON", P .. "CMD_X", P .. "ZERO")
	hmd_lines(c, {{0, Y - 0.35 * K}, {0, Y + 0.35 * K}, {-0.15 * K, Y - 0.35 * K}, {0.15 * K, Y - 0.35 * K}}, {0, 1, 2, 3})
end

---------------------------------------------------------------------------
-- missile launch envelope (A/A with a lock): scale at the top (window 6),
-- Rmax tick, Rpi triangle, no-escape box (Rtr .. Rmin), Rmin tick, target
-- range caret with closure (window 7)
---------------------------------------------------------------------------
do
	local env = hmd_show(lk, P .. "DLZ_ON", 0.5, 1.5)
	local X, Y0, L = 3.6 * K, 0.3 * K, 5.1 * K   -- (clear of the ASE circle)
	hmd_lines(env, {{X, Y0}, {X, Y0 + L}, {X, Y0 + L}, {X + 0.4 * K, Y0 + L}, {X, Y0}, {X + 0.4 * K, Y0}}, {0, 1, 2, 3, 4, 5})
	hmd_text(env, {X, Y0 + L + 0.6 * K, 0}, "CenterCenter", nil, P .. "DLZ_SC", "%.0f", HMD_TXT_S)
	local function mark(name)
		return hmd_group(env, {P .. name .. "_ON", P .. name},
			{{"parameter_in_range", 0, 0.5, 1.5}, {"move_up_down_using_parameter", 1, 1}}, {X, Y0, 0})
	end
	-- Rmax: tick to the right
	hmd_lines(mark("DLZ_RA"), {{0, 0}, {0.5 * K, 0}}, {0, 1})
	-- Rpi: small triangle on the line
	local tr = 0.22 * K
	hmd_outline(mark("DLZ_RP"), {{-tr, -tr * 0.8}, {tr, -tr * 0.8}, {0, tr}})
	-- no-escape box: top (Rtr) and bottom (Rmin) edges, right side in pieces
	hmd_lines(mark("DLZ_RT"), {{0, 0}, {0.35 * K, 0}}, {0, 1})
	hmd_lines(mark("DLZ_RM"), {{0, 0}, {0.35 * K, 0}}, {0, 1})
	local N = 30
	for k = 1, N do
		local f0, f1 = (k - 1) / N, k / N
		local fm = (f0 + f1) / 2
		local g = hmd_group(env, {P .. "DLZ_RMF", P .. "DLZ_RTF"},
			{{"parameter_in_range", 0, -1, fm}, {"parameter_in_range", 1, fm, 2}})
		hmd_lines(g, {{X + 0.35 * K, Y0 + f0 * L}, {X + 0.35 * K, Y0 + f1 * L}}, {0, 1})
	end
	-- target: caret pointing at the line, closure to its left
	local tg = mark("DLZ_TG")
	hmd_lines(tg, {{-0.45 * K, 0.22 * K}, {-0.1 * K, 0}, {-0.1 * K, 0}, {-0.45 * K, -0.22 * K}}, {0, 1, 2, 3})
	hmd_text(tg, {-0.6 * K, 0, 0}, "RightCenter", nil, P .. "VC", "%.0f", HMD_TXT_S)
end

---------------------------------------------------------------------------
-- ASE circle (dashed: AIM-120 / AIM-7, solid: AIM-9) with the steering dot
-- and the target aspect line (tail at the bottom, head-on at the top)
---------------------------------------------------------------------------
do
	local R = 2.4 * K
	local ase = hmd_show(lk, P .. "ASE_K", 0.5, 2.5)
	hmd_circle(hmd_show(ase, P .. "ASE_K", 0.5, 1.5), R, nil, true, 36)
	hmd_circle(hmd_show(ase, P .. "ASE_K", 1.5, 2.5), R, nil, false, 36)
	hmd_dot(hmd_moving(ase, P .. "ONE", P .. "ASE_DX", P .. "ASE_DY"), 0.12 * K)
	local a = hmd_group(hmd_show(ase, P .. "ASP_ON", 0.5, 1.5), {P .. "ASP_A"}, {{"rotate_using_parameter", 0, 1}})
	hmd_lines(a, {{0, -R}, {0, -R - 0.8 * K}}, {0, 1})
end

---------------------------------------------------------------------------
-- identity symbols (TD box, locator line): hostile = triangle point down,
-- friendly = circle (as the FDL symbols)
---------------------------------------------------------------------------
local function id_symbols(parent, param, pos, s)
	local h = hmd_show(parent, param, 1.5, 2.5)
	hmd_outline(h, {{pos[1] - s, pos[2] + s * 0.8}, {pos[1] + s, pos[2] + s * 0.8}, {pos[1], pos[2] - s}})
	hmd_circle(hmd_show(parent, param, 0.5, 1.5), s * 0.85, pos, false, 16)
end

---------------------------------------------------------------------------
-- TD box on the radar lock (inside the visor's field), shoot cue circle
-- inside, target altitude (thousands, hundreds) right, ID below
---------------------------------------------------------------------------
do
	local td = hmd_moving(root, P .. "TD_ON", P .. "TD_X", P .. "TD_Y")
	local S = 1.3 * K
	hmd_rect(td, S, S)
	hmd_circle(hmd_show(td, P .. "SHOOT", 0.5, 1.5), 0.42 * K, nil, false, 24)
	hmd_text(td, {S / 2 + 0.25 * K, 0.1 * K, 0}, "LeftCenter", nil, P .. "TD_A", "%s", HMD_TXT_S)
	id_symbols(td, P .. "TD_ID", {0, -S / 2 - 0.45 * K}, 0.25 * K)
end

---------------------------------------------------------------------------
-- target locator line (lock outside the visor's field): from the centre
-- toward the target, ID symbol and degrees before breaklock at its end
---------------------------------------------------------------------------
do
	local tl = hmd_show(root, P .. "TLL_ON", 0.5, 1.5)
	local a = hmd_group(tl, {P .. "TLL_A"}, {{"rotate_using_parameter", 0, 1}})
	hmd_lines(a, {{0.6 * K, 0}, {5.2 * K, 0}}, {0, 1})
	local e = hmd_moving(tl, P .. "ONE", P .. "TLE_X", P .. "TLE_Y")
	id_symbols(e, P .. "TD_ID", {0, 0}, 0.22 * K)
	hmd_text(e, {0.45 * K, 0.35 * K, 0}, "LeftCenter", nil, P .. "TLL_D", "%.0f", HMD_TXT_S)
end

---------------------------------------------------------------------------
-- datalink (FDL) contacts, in the visor's field. Kind: 1 PPLI friendly
-- (circle, name), 2 flight member (circle, name; never beyond the
-- HMD.EDGE_DEG circle, kept on it when farther out), 3 hostile (triangle point down), 4 unknown (dashed
-- square), 5 / 6 surveillance SAM (dashed circle, number or name inside). Range in NM
-- under the name.
---------------------------------------------------------------------------
for n = 1, (HMD.MAX_CONTACTS or 16) do
	local p = P .. "C" .. n .. "_"
	local c = hmd_moving(top, p .. "ON", p .. "X", p .. "Y")
	local s = 0.55 * K
	local fr = hmd_show(c, p .. "K", 0.5, 2.5)
	hmd_circle(fr, s, nil, false, 20)
	hmd_text(fr, {s + 0.25 * K, 0.3 * K, 0}, "LeftCenter", nil, p .. "L", "%s", HMD_TXT_S)
	hmd_outline(hmd_show(c, p .. "K", 2.5, 3.5), {{-s, s * 0.8}, {s, s * 0.8}, {0, -s}})
	hmd_dash_rect(hmd_show(c, p .. "K", 3.5, 4.5), s * 1.3)
	local sam = hmd_show(c, p .. "K", 4.5, 6.5)       -- 5: SAM with a number ("10"), 6: with a name ("HAWK")
	hmd_circle(sam, s * 1.2, nil, true, 20)
	hmd_text(hmd_show(sam, p .. "K", 4.5, 5.5), {0, 0, 0}, "CenterCenter", nil, p .. "N", "%.0f", HMD_TXT_S)
	hmd_text(hmd_show(sam, p .. "K", 5.5, 6.5), {0, 0, 0}, "CenterCenter", nil, p .. "L", "%s", HMD_TXT_S)
	hmd_text(c, {s + 0.25 * K, -0.45 * K, 0}, "LeftCenter", nil, p .. "R", "%.1f", HMD_TXT_S)
end

---------------------------------------------------------------------------
-- auto acquisition (v1.1, from the SIT device: F15SIT_HACQ 1 Supersearch,
-- 2 Long Range Boresight, 3 helmet acquisition). Helmet acquisition: its
-- circle around where the pilot looks, true size (12 deg across, as the
-- export's acquisition circle - not scaled with the HMD size), the mode
-- under it.
---------------------------------------------------------------------------
do
	local A = "F15SIT_HACQ"
	local R = math.tan(math.rad(6)) * 1000
	local acq = hmd_show(top, A, 0.5, 3.5)
	hmd_circle(hmd_show(acq, A, 2.5, 3.5), R, nil, true, 48)
	-- LRBST: its 4 deg circle on the line of sight (the export cues it there)
	hmd_circle(hmd_show(acq, A, 1.5, 2.5), math.tan(math.rad(2)) * 1000, nil, false, 32)
	local y = -(R + 0.8 * K)
	hmd_text(hmd_show(acq, A, 0.5, 1.5), {0, y, 0}, "CenterCenter", "SS")
	hmd_text(hmd_show(acq, A, 1.5, 2.5), {0, y, 0}, "CenterCenter", "LRBST")
	hmd_text(hmd_show(acq, A, 2.5, 3.5), {0, y, 0}, "CenterCenter", "HACQ")
end
