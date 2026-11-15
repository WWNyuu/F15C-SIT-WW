-- F-15C SIT (WW): commands of the 20 display buttons (device SIT)
SIT_CMD = {}
local n = 3000
for _, side in ipairs({"T", "B", "L", "R"}) do
	for i = 1, 5 do
		n = n + 1
		SIT_CMD[side .. i] = n
	end
end

-- HOTAS (bindable in the F-15C's controls, category "F-15C SIT"):
-- castle switch and the add-on's own functions. Global commands, as the
-- display buttons above are when bound.
SIT_HOTAS = {
	CASTLE_UP = 3101, CASTLE_DOWN = 3102, CASTLE_LEFT = 3103, CASTLE_RIGHT = 3104,
	CMD_DISPENSE = 3105, CMD_NEXT = 3106, CBT_JETT = 3107, DCLT = 3108, RNG_UP = 3109, RNG_DN = 3120, MARK = 3141, MARK_DEL = 3142,
	UHF1_UP = 3116, UHF1_DN = 3117, UHF2_UP = 3118, UHF2_DN = 3119,
}

-- the MPCD's own controls below the display (clickable): OFF / NIGHT / DAY
-- knob and the BRT rocker
SIT_PANEL = {MODE_CW = 3031, MODE_CCW = 3032, BRT_UP = 3033, BRT_DN = 3034}

-- JHMCS (helmet): its panel on the left console (clickable: power switch
-- 3035, brightness knob 3036; model arguments 131 / 130) and the binds
-- (category "F-15C SIT"): power, brightness, symbology on/off
HMD_PANEL = {PWR = 3035, BRT = 3036}
HMD_ARG = {PWR = 131, BRT = 130}
HMD_BIND = {BRT_UP = 6150, BRT_DN = 6151, SYM_TOGGLE = 6152, PWR = 6156}

-- auto acq switch (stick) and helmet acquisition (binds, category "F-15C SIT"):
-- each sends 1 when pressed and 0 when released (the add-on times the press)
ACQ_BIND = {FWD = 6160, AFT = 6161, DEP = 6162, HACQ = 6163, SSB = 6170, BST = 6171}
-- weapon select switch (throttle): gun / SRM / MRM; missile reject switch
WPN_BIND = {GUN = 6164, SRM = 6165, MRM = 6166, REJ = 6167}
-- target step (TWS: next tracked target), unlock (STT: search, TWS: drop the primary track)
TGT_BIND = {STEP = 6168, UNLOCK = 6169}
-- front UHF-1 radio panel and IFF MODE 3/A (v1.1, clickable): channel,
-- the three frequency knobs, volume, mode (CHAN / MAN / GUARD), the four
-- code wheels (up / down) and I/P
RFP_CMD = {CHAN_UP = 3050, CHAN_DN = 3051, F1_UP = 3052, F1_DN = 3053, F2_UP = 3054, F2_DN = 3055,
	F3_UP = 3056, F3_DN = 3057, VOL_UP = 3058, VOL_DN = 3059, MODE_CW = 3060, MODE_CCW = 3061,
	W1_UP = 3062, W1_DN = 3063, W2_UP = 3064, W2_DN = 3065, W3_UP = 3066, W3_DN = 3067, W4_UP = 3068, W4_DN = 3069,
	IP = 3070}
-- exterior lights panel (left console, v1.1, clickable): FORMATION knob =
-- anti-collision lights, POSITION knob = navigation (position) lights
EXTLT_CMD = {FORM = 3071, POS = 3072}
-- SRS volume (v1.1): UHF-1 / UHF-2 up / down, SIT.SRS_VOL_STEP per press
RAD_BIND = {V1_UP = 6172, V1_DN = 6173, V2_UP = 6174, V2_DN = 6175}
