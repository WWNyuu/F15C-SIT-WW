-----------------------------------------------------------------------
-- F-15C SIT (WW): JHMCS control panel, the plate's markings. Turned like the
-- COMMAND panel beside it: the text's top points forward. Page: x = inboard
-- (right), y = forward (up); 1 = 5 cm; the plate +-1.25 x +-0.86, screws in
-- the corners. Outboard half: the power switch (ON forward, OFF aft);
-- inboard half: the brightness knob (- lower left .. + lower right).
-----------------------------------------------------------------------
dofile(LockOn_Options.script_path .. "HMD/panel/panel_common.lua")

local rad, cos, sin = math.rad, math.cos, math.sin
local BIG, MID, SMALL = cap_defs(0.0042), cap_defs(0.0034), cap_defs(0.0026)

-- power switch (centre -0.66, 0)
local SX = -0.66
p_text(nil, SX, 0.68, "HMD", BIG)
p_text(nil, SX, 0.40, "ON", MID)
p_text(nil, SX, -0.40, "OFF", MID)
p_text(nil, SX, -0.68, "JHMCS", SMALL)
-- brightness knob (centre 0.6, 0)
local KX, KY = 0.6, 0.0
p_text(nil, KX, 0.68, "BRT", MID)
for k = 0, 10 do
	local a = rad(225 - 27 * k)
	local r0, r1 = 0.34, (k == 0 or k == 10) and 0.44 or 0.39
	p_stroke(nil, KX + r0 * cos(a), KY + r0 * sin(a), KX + r1 * cos(a), KY + r1 * sin(a), 0.018)
end
p_text(nil, KX + 0.56 * cos(rad(225)), KY + 0.56 * sin(rad(225)), "-", BIG)
p_text(nil, KX + 0.56 * cos(rad(-45)), KY + 0.56 * sin(rad(-45)), "+", BIG)
