-- F-15C SIT (WW): device ids for this plugin's own devices
local count = 0
local function counter()
	count = count + 1
	return count
end

devices = {}
devices["SIT"] = counter()
