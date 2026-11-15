-----------------------------------------------------------------------
-- F-15C SIT (WW): the IFF MODE 3/A window (centre panel, above the UHF-1
-- radio panel), on its own anchors IFF_C/_B/_R (its own depth): white number drums on the dark patches
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
	e.name = "iff_d" .. n
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
	e.name = "iff_t" .. n
	e.material = WHITE
	e.init_pos = {x, y, 0}
	e.alignment = "CenterCenter"
	e.stringdefs = defs
	e.value = s
	e.use_mipfilter = true
	e.additive_alpha = false
	Add(e)
end

-- IFF MODE 3/A: four wheels (v36: on ED's digit centres and at ED's size,
-- measured on a stock screenshot)
local M3 = cap_defs(0.0050)
local M3_X = {-0.1834, 0.0536, 0.3006, 0.5344}
for k = 1, 4 do digit(M3_X[k], 0.5816, "M" .. k, M3) end
