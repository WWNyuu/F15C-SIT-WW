-----------------------------------------------------------------------
-- F-15C SIT (WW): data cartridges (DTM page)
--
-- Choices on the DTM page (CART steps through them, READ loads one):
--   MSN          the mission: the jet's route from the mission, the
--                mission's bullseye and the mission drawings of your side
--                (lines, areas, circles: sent by Scripts\Hooks\F15SIT_hook.lua)
--   <name>.dtc   each F-15C cartridge in Saved Games\DCS\DTC\F-15C made for
--                the map you are flying (F-15C DTC Planner, or by hand)
--
-- Cartridge (JSON):
--   { "type": "F-15C SIT DTC", "version": 1, "name": "...", "terrain": "Caucasus",
--     "route":    [ {"lat": 42.1, "lon": 41.6, "name": "IP", "alt": 25000}, ... ],
--     "bullseye": {"lat": 42.0, "lon": 42.3, "name": "BULLS"},
--     "jtids":    {"fighter_channel": 19, "voice_channel": 1, "own_tn": "04217",
--                  "flight": ["Enfield 1-2", "Enfield 1-3"]},
--     "pacs":     {"cmd": "PFM", "pf": "GLOBAL", "jett1": ["L", "C", "R"], "jett2": ["L", "LC", "C", "RC", "R"]},
--     "sit":      {"range": 40, "center": true, "nup": false, "zulu": true} }
-- Every block is optional. Drawings: <name>.geo.txt next to it, the same
-- format as the MiG-29 add-on (RING, RING?, FLOT, BORDER, AREA).
-- Coordinates in the files: decimal degrees; in the jet: DCS map metres
-- (x = north, z = east).
-----------------------------------------------------------------------
SIT_DTM = {}

local function lfs_mod()
	local ok, l = pcall(require, "lfs")
	return (ok and type(l) == "table") and l or nil
end
local function dir()
	local l = lfs_mod()
	return l and (l.writedir() .. "DTC/F-15C/") or nil
end
SIT_DTM.dir = dir

-- DCS's Scripts\JSON.lua (as the MiG-29 add-on loads it)
local JSON = nil
local function json()
	if JSON then return JSON end
	local roots = {"", "./"}
	local l = lfs_mod()
	if l and l.currentdir then
		local r = l.currentdir()
		if r:sub(-1) ~= "/" and r:sub(-1) ~= "\\" then r = r .. "/" end
		roots[#roots + 1] = r
		roots[#roots + 1] = r .. "../"
	end
	for _, r in ipairs(roots) do
		local f = loadfile(r .. "Scripts/JSON.lua")
		if f then
			local ok, j = pcall(f)
			if ok and j then JSON = j; return JSON end
		end
	end
	return nil
end

-- lat / lon -> DCS map metres
local TERR = nil
function SIT_DTM.to_world(lat, lon)
	if TERR == nil then
		local ok, t = pcall(require, "terrain")
		TERR = (ok and type(t) == "table" and t.convertLatLonToMeters) and t or false
	end
	if not TERR then return nil end
	local ok, x, z = pcall(TERR.convertLatLonToMeters, lat, lon)
	if ok and type(x) == "number" and x == x and type(z) == "number" and z == z then return x, z end
	return nil
end

-- map names: DCS ids and terrain folder names that mean the same map
local SAME = {germanycoldwar = "germanycw", sinai = "sinaimap", marianaswwii = "marianaislandswwii"}
local function map_id(n)
	n = tostring(n or ""):lower()
	return SAME[n] or n
end
function SIT_DTM.same_map(a, b) return map_id(a) == map_id(b) end

local BOM = "\239\187\191"
local CACHE = {}
local function read(l, path)
	local key
	if l.attributes then
		local ok, a = pcall(l.attributes, path)
		if ok and type(a) == "table" then key = tostring(a.size) .. ":" .. tostring(a.modification) end
	end
	local c = CACHE[path]
	if c and key and c.key == key then return c end
	c = {key = key}
	CACHE[path] = c
	local fh = io.open(path, "r")
	if not fh then c.err = "cannot be opened"; return c end
	local txt = fh:read("*a") or ""
	fh:close()
	if not txt:find("F-15C", 1, true) then c.err = "not an F-15C cartridge"; return c end
	if txt:sub(1, 3) == BOM then txt = txt:sub(4) end
	local J = json()
	if not J then c.err = "no JSON.lua"; return c end
	local ok, d = pcall(function() return J:decode(txt) end)
	if not ok or type(d) ~= "table" then c.err = "not readable as JSON"; return c end
	if not tostring(d.type or ""):find("F%-15C") then c.err = "not an F-15C cartridge"; return c end
	c.data = d
	return c
end

-- F-15C cartridges for this map (theatre nil / "" = all), sorted by name
function SIT_DTM.list(theatre)
	local files = {}
	local l, d = lfs_mod(), dir()
	if not l or not d then return files end
	pcall(function()
		for name in l.dir(d) do
			if type(name) == "string" and name:lower():match("%.dtc$") then
				local ok, c = pcall(read, l, d .. name)
				if ok and c.data then
					local terr = c.data.terrain
					if not theatre or theatre == "" or not terr or terr == "" or SIT_DTM.same_map(terr, theatre) then
						files[#files + 1] = {name = name:gsub("%.[dD][tT][cC]$", ""), data = c.data}
					end
				end
			end
		end
	end)
	table.sort(files, function(a, b) return a.name:lower() < b.name:lower() end)
	return files
end

-- drawings: the MiG-29 add-on's .geo.txt rules (one number rule, lat / lon
-- in degrees, radius in km). Returns shapes {kw, name, r (m), x = {}, z = {}}
local KW = {["RING"] = "ring", ["RING?"] = "ring", ["FLOT"] = "line", ["BORDER"] = "line", ["AREA"] = "area"}
local function num(s)
	s = s:gsub("/", "")
	if not s:find("^[-+]?%d*%.?%d+$") then return nil end
	return tonumber(s)
end
local function ll_ok(la, lo) return la >= -90 and la <= 90 and lo >= -180 and lo <= 180 end
function SIT_DTM.parse_geo(txt)
	local out = {}
	txt = txt:gsub("^" .. BOM, "")
	for raw in (txt .. "\n"):gmatch("([^\n]*)\n") do
		local line = raw:gsub("\r", ""):gsub("#.*$", "")
		local tok = {}
		for w in line:gmatch("%S+") do if w ~= "/" then tok[#tok + 1] = w end end
		local kw = tok[1] and tok[1]:upper()
		if kw and KW[kw] then
			local k, name = 2, {}
			while tok[k] and not num(tok[k]) do name[#name + 1] = tok[k]; k = k + 1 end
			local nums, okn = {}, true
			for j = k, #tok do
				local v = num(tok[j])
				if v then nums[#nums + 1] = v elseif tok[j]:gsub("/", "") ~= "" then okn = false end
			end
			local s = {kw = KW[kw], name = table.concat(name, " "), x = {}, z = {}, dashed = (kw == "RING?")}
			if okn and s.kw == "ring" and #nums == 3 and nums[1] > 0 and nums[1] <= 10000 and ll_ok(nums[2], nums[3]) then
				local x, z = SIT_DTM.to_world(nums[2], nums[3])
				if x then s.r = nums[1] * 1000; s.x[1], s.z[1] = x, z; out[#out + 1] = s end
			elseif okn and s.kw ~= "ring" and #nums >= 4 and #nums % 2 == 0 then
				local good = true
				for j = 1, #nums - 1, 2 do
					local x, z = nil, nil
					if ll_ok(nums[j], nums[j + 1]) then x, z = SIT_DTM.to_world(nums[j], nums[j + 1]) end
					if x then s.x[#s.x + 1], s.z[#s.z + 1] = x, z else good = false end
				end
				if good then out[#out + 1] = s end
			end
		end
	end
	return out
end

function SIT_DTM.read_geo(name)
	local d = dir()
	local fh = d and io.open(d .. name .. ".geo.txt", "r")
	if not fh then return {} end
	local txt = fh:read("*a") or ""
	fh:close()
	local ok, s = pcall(SIT_DTM.parse_geo, txt)
	return ok and s or {}
end

-- a cartridge's route / bullseye in map metres
function SIT_DTM.route(data)
	local r = {}
	for i, p in ipairs(type(data.route) == "table" and data.route or {}) do
		local la, lo = tonumber(p.lat), tonumber(p.lon)
		local x, z = nil, nil
		if la and lo then x, z = SIT_DTM.to_world(la, lo) end
		if x then r[#r + 1] = {x = x, z = z, num = i, name = tostring(p.name or "")} end
	end
	return r
end
function SIT_DTM.bull(data)
	local b = type(data.bullseye) == "table" and data.bullseye or nil
	local la, lo = b and tonumber(b.lat), b and tonumber(b.lon)
	if not la or not lo then return nil end
	local x, z = SIT_DTM.to_world(la, lo)
	return x and {x, z} or nil
end
