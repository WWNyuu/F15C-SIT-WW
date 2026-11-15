-----------------------------------------------
-- F-15C SIT (WW) - the add-on's cockpit devices (SIT, JHMCS) and displays
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

	-- JHMCS helmet display: its device (100 Hz) and the display, which moves
	-- with the view (world symbols are placed along the view by the device).
	-- Options > Special > F-15C SIT can switch it off completely.
	HMD = {}          -- (fresh: the option is read again for every new cockpit)
	pcall(dofile, LockOn_Options.script_path .. "HMD/hmd_options.lua")
	if HMD.ENABLED ~= false then
		creators[devices.HMD] = {"avLuaDevice", LockOn_Options.script_path .. "HMD/hmd_device.lua"}
		indicators[#indicators + 1] = {"ccIndicator", LockOn_Options.script_path .. "HMD/init_head.lua", nil}
	end
	-- its control panel on the left console: the plate's markings (the switch
	-- and the knob are part of the model)
	indicators[#indicators + 1] = {"ccIndicator", LockOn_Options.script_path .. "HMD/panel/init_panel.lua",
		nil, {{"HMDP_C", "HMDP_B", "HMDP_R"}, {}}}
	-- v1.1: the front UHF-1 radio panel and the IFF MODE 3/A window: our
	-- number drums over ED's (the model's patches and click points)
	indicators[#indicators + 1] = {"ccIndicator", LockOn_Options.script_path .. "RFP/init_rfp.lua",
		nil, {{"RFP_C", "RFP_B", "RFP_R"}, {}}}
	indicators[#indicators + 1] = {"ccIndicator", LockOn_Options.script_path .. "RFP/init_iff.lua",
		nil, {{"IFF_C", "IFF_B", "IFF_R"}, {}}}
end
