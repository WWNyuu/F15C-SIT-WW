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
