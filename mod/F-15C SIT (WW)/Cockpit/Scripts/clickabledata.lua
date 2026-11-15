-----------------------------------------------------------------------
-- F-15C SIT (WW): the 20 display buttons, the OFF / NIGHT / DAY knob and
-- the BRT rocker below the display.
-- The click boxes are the SIT_OSB_*, SIT_MODE_KNOB and SIT_BRT connectors
-- of Shapes\F15C_SIT.edm.
-----------------------------------------------------------------------
dofile(LockOn_Options.script_path .. "command_defs.lua")
dofile(LockOn_Options.script_path .. "devices.lua")

local gettext = require("i_18n")
_ = gettext.translate

-- (the Flaming Cliffs F-15C may not load ED's clickable definitions)
class_type = class_type or {NULL = 0, BTN = 1, TUMB = 2, SNGBTN = 3, LEV = 4, MOVABLE_LEV = 5}

cursor_mode = {
	CUMODE_CLICKABLE = 0,
	CUMODE_CLICKABLE_AND_CAMERA = 1,
	CUMODE_CAMERA = 2,
}
clickable_mode_initial_status = cursor_mode.CUMODE_CLICKABLE
use_pointer_name = true

local function button(hint, command, arg)
	return {
		class               = {class_type.BTN},
		hint                = hint,
		device              = devices.SIT,
		action              = {command},
		stop_action         = {command},
		arg                 = {arg},
		arg_value           = {1},
		arg_lim             = {{0, 1}},
		updatable           = true,
		use_release_message = {true},
	}
end

elements = {}
local arg = 100
for _, side in ipairs({"T", "B", "L", "R"}) do
	for i = 1, 5 do
		arg = arg + 1
		local name = side .. i
		elements["SIT_OSB_" .. name] = button("SIT " .. name, SIT_CMD[name], arg)
	end
end

-- the controls below the display: left / right click
local function two_way(hint, left, right, arg)
	return {
		class               = {class_type.BTN, class_type.BTN},
		hint                = hint,
		device              = devices.SIT,
		action              = {left, right},
		stop_action         = {left, right},
		arg                 = {arg, arg},
		arg_value           = {1, 1},
		arg_lim             = {{0, 1}, {0, 1}},
		updatable           = true,
		use_release_message = {true, true},
	}
end
elements["SIT_MODE_KNOB"] = two_way("MPCD OFF / NIGHT / DAY (left click: toward OFF, right click: toward DAY)",
	SIT_PANEL.MODE_CCW, SIT_PANEL.MODE_CW, 121)
elements["SIT_BRT"] = two_way("MPCD brightness (left click: brighter, right click: dimmer)",
	SIT_PANEL.BRT_UP, SIT_PANEL.BRT_DN, 122)
-- JHMCS panel (left console): power switch (connector HMD_PWR_CLICK, model
-- argument 131) and brightness knob (HMD_BRT_CLICK, argument 130: turn it
-- with the mouse wheel or by dragging)
elements["HMD_PWR_CLICK"] = {
	class               = {class_type.TUMB, class_type.TUMB},
	hint                = _("HMD Power ON / OFF"),
	device              = devices.SIT,
	action              = {HMD_PANEL.PWR, HMD_PANEL.PWR},
	arg                 = {HMD_ARG.PWR, HMD_ARG.PWR},
	arg_value           = {1, -1},
	arg_lim             = {{0, 1}, {0, 1}},
	updatable           = true,
	use_OBB             = true,
}
elements["HMD_BRT_CLICK"] = {
	class               = {class_type.LEV},
	hint                = _("HMD Brightness"),
	device              = devices.SIT,
	action              = {HMD_PANEL.BRT},
	arg                 = {HMD_ARG.BRT},
	arg_value           = {1},
	gain                = {0.0425},        -- (its speed: ED's default is 0.1)
	arg_lim             = {{0, 1}},
	updatable           = true,
	use_OBB             = true,
	cycle               = false,
	relative            = {false},
}

-- v1.1: front UHF-1 radio panel and IFF MODE 3/A (centre panel, under the
-- HUD). ED's knobs and drums can not be moved from a mod: the clicks work,
-- our digits show the result. Connectors RFP_* / IFF_* of Shapes\F15C_SIT.edm;
-- arguments 900+ belong to nothing (the click needs one).
local RC = RFP_CMD
elements["RFP_CHAN_KNOB"] = two_way("UHF-1 channel (left click: up, right click: down)", RC.CHAN_UP, RC.CHAN_DN, 901)
elements["RFP_FREQ_KNOB1"] = two_way("UHF-1 frequency, 10 MHz (left click: up, right click: down)", RC.F1_UP, RC.F1_DN, 902)
elements["RFP_FREQ_KNOB2"] = two_way("UHF-1 frequency, 1 MHz (left click: up, right click: down)", RC.F2_UP, RC.F2_DN, 903)
elements["RFP_FREQ_KNOB3"] = two_way("UHF-1 frequency, 25 kHz (left click: up, right click: down)", RC.F3_UP, RC.F3_DN, 904)
elements["RFP_VOL_KNOB"] = two_way("UHF-1 volume (SRS; left click: louder, right click: quieter)", RC.VOL_UP, RC.VOL_DN, 905)
elements["RFP_MODE_KNOB"] = two_way("UHF-1 mode: CHAN / MAN / GUARD (left click: toward CHAN, right click: toward GUARD)", RC.MODE_CCW, RC.MODE_CW, 906)
for k = 1, 4 do
	elements["IFF_M3_W" .. k] = two_way("IFF mode 3/A, digit " .. k .. " (SRS; left click: down, right click: up)", RC["W" .. k .. "_DN"], RC["W" .. k .. "_UP"], 906 + k)
end
elements["IFF_IP"] = button("IFF I/P (identify, SRS)", RC.IP, 911)

-- v1.1: exterior lights panel (left console): the FORMATION and POSITION
-- knobs as two buttons for the jet's lights (FC3: anti-collision and
-- navigation lights, each on / off). Connectors EXTLT_* of Shapes\F15C_SIT.edm.
elements["EXTLT_FORM_CLICK"] = button("Anti-collision lights ON / OFF", EXTLT_CMD.FORM, 912)
elements["EXTLT_POS_CLICK"] = button("Navigation (position) lights ON / OFF", EXTLT_CMD.POS, 913)
