-----------------------------------------------
-- F-15C SIT (WW) 1.0 - the add-on's cockpit device and its display
-----------------------------------------------

dofile(LockOn_Options.script_path .. "devices.lua")

-- the screen is anchored on the connectors of the add-on's own model
-- (Shapes/F15C_SIT.edm, loaded through mainpanel_init.lua): its centre,
-- bottom and right edge in front of the stock lower-left display
local ANCHOR_OWN = {"SIT_C", "SIT_B", "SIT_R"}

if get_aircraft_type() == "F-15C" then
	MainPanel = {"ccMainPanel", LockOn_Options.script_path .. "mainpanel_init.lua", {}}

	creators = {}
	creators[devices.SIT] = {"avLuaDevice", LockOn_Options.script_path .. "SIT/sit_device.lua"}

	indicators = {}
	indicators[#indicators + 1] = {"ccIndicator", LockOn_Options.script_path .. "SIT/indicator/init_SIT.lua",
		nil, { ANCHOR_OWN, {} }}
end
