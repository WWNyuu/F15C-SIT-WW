-----------------------------------------------------------------------
-- F-15C SIT (WW): front UHF-1 radio panel (centre panel, under the HUD) and
-- the IFF MODE 3/A window above it: white number drums on the dark patches
-- of Shapes\F15C_SIT.edm. Page: x right, y up along the panel face, 1 = 5 cm,
-- (0, 0) = the MAIN FREQ window's height on the panel's centreline.
-- Every digit is a NUMBER parameter (F15SIT_RFP_*: 0..9, -1 = blank).
-- Positions from ED's model (its drums), the MODE 3/A wheels estimated.
-----------------------------------------------------------------------
dofile(LockOn_Options.common_script_path .. "elements_defs.lua")
SetScale(FOV)

local FONT_DESC = {
	texture    = LockOn_Options.script_path .. "../Textures/IndicationTextures/f15sit_drum.dds",   -- (v1.1: drum digits, a bold sans as ED's)
	size       = {16, 16},
	resolution = {2048, 2048},
	default    = {68, 128},
	chars      = {},
}
for code = 32, 126 do FONT_DESC.chars[#FONT_DESC.chars + 1] = {code, 68, 128} end
local WHITE = MakeFont(FONT_DESC, {232, 232, 222, 255})
local CAP = 77 / 128
local function cap_defs(cap_m) local h = cap_m / CAP; return {h, h * 0.9, 0, 0} end

local n = 0
-- a digit: number parameter, shown while it is 0..9
local function digit(x, y, param, defs)
	n = n + 1
	local e = CreateElement "ceStringPoly"
	e.name = "rfp_d" .. n
	e.material = WHITE
	e.init_pos = {x, y, 0}
	e.alignment = "CenterCenter"
	e.stringdefs = defs
	e.formats = {"%.0f"}
	e.element_params = {"F15SIT_RFP_" .. param, "F15SIT_RFP_" .. param}
	e.controllers = {{"parameter_in_range", 1, -0.5, 9.5}, {"text_using_parameter", 0, 0}}
	e.use_mipfilter = true
	e.additive_alpha = false
	Add(e)
end
local function fixed(x, y, s, defs)
	n = n + 1
	local e = CreateElement "ceStringPoly"
	e.name = "rfp_t" .. n
	e.material = WHITE
	e.init_pos = {x, y, 0}
	e.alignment = "CenterCenter"
	e.stringdefs = defs
	e.value = s
	e.use_mipfilter = true
	e.additive_alpha = false
	Add(e)
end

-- CHAN: two drums (v29: centred in the opening as seen from the seat)
local CH = cap_defs(0.0072)
digit(-1.046, -0.161, "CH1", CH)
digit(-0.840, -0.161, "CH2", CH)
-- MAIN FREQ: 2 7 6 . 3 7 5 (v29: 3 mm left, a little closer together)
local FQ = cap_defs(0.0064)
local FQ_X = {-0.365, -0.172, 0.023, 0.228, 0.380, 0.505}
for k = 1, 6 do digit(FQ_X[k], -0.037, "F" .. k, FQ) end
fixed(0.125, -0.075, ".", FQ)
-- (IFF MODE 3/A: iff_page.lua, on its own anchors)
