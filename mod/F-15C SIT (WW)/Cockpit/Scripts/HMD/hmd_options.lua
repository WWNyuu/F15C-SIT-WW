-----------------------------------------------------------------------
-- F-15C SIT (WW): the JHMCS settings from Options > Special > F-15C SIT
--   f15c_sit_hmd       helmet display on/off (off: no helmet display at all)
--   f15c_sit_hmd_size  its size, percent (50..200, 100 = real size)
-- Read from Saved Games\DCS\Config\options.lua (as the export script does),
-- else through DCS's plugin option function; defaults: on, 100 %.
-- Sets HMD.ENABLED and multiplies HMD.SCALE (hmd_config.lua) by the size.
-----------------------------------------------------------------------
HMD = HMD or {}
local function read()
	local p = nil
	pcall(function()
		local l = lfs or require("lfs")
		local f = loadfile(l.writedir() .. "Config/options.lua")
		if not f then return end
		local env = {}
		setfenv(f, env)
		f()
		p = env.options and env.options.plugins and env.options.plugins["f15c_sit"]
	end)
	local function opt(key)
		if type(p) == "table" and p[key] ~= nil then return p[key] end
		local ok, v = pcall(function() return get_plugin_option_value and get_plugin_option_value("f15c_sit", key, "local") end)
		if ok then return v end
		return nil
	end
	local on = opt("f15c_sit_hmd")
	HMD.ENABLED = on ~= false
	local size = tonumber(opt("f15c_sit_hmd_size"))
	if size and size >= 20 and size <= 400 then
		HMD.SCALE = (HMD.SCALE or 1) * size / 100
		HMD.SIZE_PCT = size
	end
end
if not HMD.OPTIONS_READ then
	HMD.OPTIONS_READ = true
	read()
end
