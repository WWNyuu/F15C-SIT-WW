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
