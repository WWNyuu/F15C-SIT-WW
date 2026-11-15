-----------------------------------------------------------------------
-- F-15C SIT (WW): bullseye for the SIT page
--
-- Neither the cockpit nor the export script can see the mission's
-- bullseye. This hook (Saved Games\DCS\Scripts\Hooks) reads it from the
-- mission at the start and sends it to the SIT page every 2 s:
--   F15SITB,red x,red z,blue x,blue z     (map metres, x north, z east)
-- v0.6: also the mission's map and date (TIME/DATE page, Zulu time):
--   F15SITD,theatre,day,month,year,start time (s after midnight, local)
-- v0.7: the pylons of the player's aircraft (ARMT / WPN LOAD pages):
--   F15SITP,pylon=CLSID,pylon=CLSID...
-- v0.8: the mission drawings of the player's side and the Common layer
-- (lines, polygons, circles, rectangles; MSN cartridge, LINES on SIT):
--   F15SITL,<version>\nA,name,x,z,x,z...\nL,name,x,z...   (A closed, L open)
-- v1.1: cartridge routes as Route Tool presets (see sync_route_presets)
-- Log: Saved Games\DCS\Logs\f15sit_hook.log
-----------------------------------------------------------------------
local F15SIT_hook = {}
local PORT = 42889
local udp, msg, msg_d, last = nil, nil, nil, -100
local msg_p, unit_seen, mission = nil, nil, nil
local msg_l, side_seen = nil, nil
local msg_r = nil
local searched = false   -- the player's unit was looked for in the mission (found or not)
-- Options > Special > F-15C SIT (read at each mission start): add-on on,
-- datalink part on (EWR reports are part of it)
local OPT = {f15c_sit_enabled = true, f15c_sit_datalink = true}
local function read_options()
	pcall(function()
		local l = require("lfs")
		local f = loadfile(l.writedir() .. "Config/options.lua")
		if not f then return end
		local env = {}
		setfenv(f, env)
		f()
		local p = env.options and env.options.plugins and env.options.plugins["f15c_sit"]
		if type(p) ~= "table" then return end
		for k in pairs(OPT) do if type(p[k]) == "boolean" then OPT[k] = p[k] end end
	end)
end

local function log(s)
	pcall(function()
		local l = lfs or require("lfs")
		local f = io.open(l.writedir() .. "Logs/f15sit_hook.log", "a")
		if f then f:write(os.date("%H:%M:%S ") .. tostring(s) .. "\n"); f:close() end
	end)
end

local function sock()
	if udp then return udp end
	pcall(function()
		package.path = package.path .. ";.\\LuaSocket\\?.lua"
		package.cpath = package.cpath .. ";.\\LuaSocket\\?.dll"
		local socket = require("socket")
		udp = socket.udp()
		udp:settimeout(0)
	end)
	return udp
end

local function read_bullseye()
	msg = nil
	local ok, err = pcall(function()
		local m = DCS.getCurrentMission()
		m = (type(m) == "table" and m.mission) or m
		mission = m
		local c = type(m) == "table" and m.coalition or nil
		local function pos(side)
			local s = c and c[side]
			local b = s and s.bullseye
			if type(b) == "table" and tonumber(b.x) and tonumber(b.y) then
				return string.format("%.0f,%.0f", b.x, b.y)
			end
			return "x,x"
		end
		msg = "F15SITB," .. pos("red") .. "," .. pos("blue")
		local d = type(m.date) == "table" and m.date or {}
		local th = tostring(m.theatre or ""):gsub("[^%w_]", "")
		msg_d = string.format("F15SITD,%s,%d,%d,%d,%d", th, tonumber(d.Day) or 0, tonumber(d.Month) or 0,
			tonumber(d.Year) or 0, tonumber(m.start_time) or 0)
	end)
	log(ok and ("bullseye: " .. tostring(msg) .. "  date: " .. tostring(msg_d)) or ("no bullseye: " .. tostring(err)))
end

-- the player's unit in the mission -> its pylons
local function read_pylons()
	local ok, err = pcall(function()
		local uid = DCS.getPlayerUnit and DCS.getPlayerUnit()
		-- the mission is walked once per unit: a unit that is not in it (a
		-- dynamic slot, spectators) is not looked for again every 2 s
		if uid == unit_seen and (msg_p or searched) then return end
		unit_seen, searched = uid, uid ~= nil
		msg_p, msg_r = nil, nil
		if not uid or not mission or type(mission.coalition) ~= "table" then return end
		uid = tonumber(uid)
		for _side_name, side in pairs(mission.coalition) do
			for _, c in pairs(type(side) == "table" and side.country or {}) do
				for _, cat in ipairs({"plane", "helicopter"}) do
					local gs = type(c[cat]) == "table" and c[cat].group or {}
					for _, g in pairs(gs) do
						for _, u in pairs(type(g.units) == "table" and g.units or {}) do
							if tonumber(u.unitId) == uid then
								local py = type(u.payload) == "table" and u.payload.pylons or {}
								local s = {}
								for n, pl in pairs(py) do
									if type(pl) == "table" and pl.CLSID then
										s[#s + 1] = tostring(n) .. "=" .. tostring(pl.CLSID):gsub("[^%w%-{}_]", "")
									end
								end
								msg_p = "F15SITP," .. table.concat(s, ",")
								-- radio presets of this aircraft + the flight's frequency:
								-- F15SITR|<group freq><A/F>|<radio 1 ch1>,<ch2>...|<radio 2 ...>
								local function fq(f, m)
									f = tonumber(f) or 0
									if f > 1e5 then f = f / 1e6 end      -- Hz -> MHz
									return string.format("%.3f%s", f, (tonumber(m) == 1) and "F" or "A")
								end
								local r = {fq(g.frequency, g.modulation)}
								for k = 1, 3 do
									local rd = type(u.Radio) == "table" and u.Radio[k]
									if type(rd) == "table" and type(rd.channels) == "table" then
										local list = {}
										local mods = type(rd.modulations) == "table" and rd.modulations or {}
										for ch = 1, 20 do
											if rd.channels[ch] then list[#list + 1] = fq(rd.channels[ch], mods[ch]) else break end
										end
										r[#r + 1] = table.concat(list, ",")
									end
								end
								msg_r = "F15SITR|" .. table.concat(r, "|")
								log("radios: " .. msg_r)
								side_seen = tostring(_side_name)
								msg_l = nil       -- (drawings read again for this side)
								log("pylons of unit " .. tostring(uid) .. " (" .. tostring(u.type) .. "): " .. msg_p)
								return
							end
						end
					end
				end
			end
		end
	end)
	if not ok then log("pylons: " .. tostring(err)) end
end

-- mission drawings -> map metres (points are relative to mapX / mapY)
local function read_drawings()
	msg_l = nil
	local ok, err = pcall(function()
		local dr = mission and mission.drawings
		local layers = type(dr) == "table" and dr.layers or nil
		if type(layers) ~= "table" then return end
		local side = (side_seen or ""):lower()
		local out, npts, size = {}, 0, 0
		local function clean(s) return (tostring(s or ""):gsub("[^%w%-%./ ]", ""):sub(1, 16)) end
		for _, ly in pairs(layers) do
			local ln = tostring(ly.name or ""):lower()
			if type(ly.objects) == "table" and (ln == "common" or ln == side) and ly.visible ~= false then
				for _, o in pairs(ly.objects) do
					if type(o) == "table" and o.visible ~= false and npts < 600 then
						local mx, my = tonumber(o.mapX) or 0, tonumber(o.mapY) or 0
						local pts, closed = {}, false
						if o.primitiveType == "Line" and type(o.points) == "table" then
							for _, q in ipairs(o.points) do pts[#pts + 1] = {mx + (q.x or 0), my + (q.y or 0)} end
							closed = o.closed == true
						elseif o.primitiveType == "Polygon" then
							closed = true
							if o.polygonMode == "circle" and tonumber(o.radius) then
								for k = 0, 35 do
									local a = 2 * math.pi * k / 36
									pts[#pts + 1] = {mx + o.radius * math.cos(a), my + o.radius * math.sin(a)}
								end
							elseif o.polygonMode == "rect" and tonumber(o.width) and tonumber(o.height) then
								local w, h = o.width / 2, o.height / 2
								local an = math.rad(tonumber(o.angle) or 0)
								for _, c in ipairs({{-h, -w}, {h, -w}, {h, w}, {-h, w}}) do
									pts[#pts + 1] = {mx + c[1] * math.cos(an) - c[2] * math.sin(an), my + c[1] * math.sin(an) + c[2] * math.cos(an)}
								end
							elseif type(o.points) == "table" then
								for _, q in ipairs(o.points) do pts[#pts + 1] = {mx + (q.x or 0), my + (q.y or 0)} end
							end
						end
						if #pts >= 2 then
							local s = {(closed and "A" or "L"), clean(o.name)}
							for _, q in ipairs(pts) do s[#s + 1] = string.format("%.0f,%.0f", q[1], q[2]) end
							local line = table.concat(s, ",")
							-- (one datagram: at most ~7500 bytes, DCS's LuaSocket cuts at 8 KB)
							if size + #line + 1 <= 7400 then
								out[#out + 1] = line
								size = size + #line + 1
								npts = npts + #pts
							end
						end
					end
				end
			end
		end
		msg_l = "F15SITL," .. tostring(math.floor(os.time() % 100000)) .. "\n" .. table.concat(out, "\n")
		log("drawings for side '" .. side .. "': " .. #out .. " shapes, " .. npts .. " points")
	end)
	if not ok then log("drawings: " .. tostring(err)) end
end

-----------------------------------------------------------------------
-- v1.1: cartridge routes as Route Tool presets. FC3 jets take their route
-- from the mission at spawn only; DCS's Route Tool (F10 map, before you
-- spawn) can set it. Every F-15C cartridge in Saved Games\DCS\DTC\F-15C
-- becomes a preset "F-15C DTC: <name>" in
-- Saved Games\DCS\Config\RouteToolPresets\<map>.lua (the other presets in
-- that file are kept; a deleted cartridge's preset goes). Pick it in the
-- Route Tool and tick USE THIS ROUTE ON NEXT SPAWN: the jet, its HUD
-- steering and the SIT page then fly the cartridge route.
-- Done when DCS starts, when a mission loads and when it ends.
-----------------------------------------------------------------------
local RT_PREFIX = "F-15C DTC: "
local RT_SPEED = 220       -- m/s for the ETAs (the Route Tool shows them)
local function rt_json(txt)
	if net and net.json2lua then
		local ok, d = pcall(net.json2lua, txt)
		if ok and type(d) == "table" then return d end
	end
	local f = loadfile("Scripts/JSON.lua")
	if f then
		local ok, J = pcall(f)
		if ok and J then
			local ok2, d = pcall(function() return J:decode(txt) end)
			if ok2 and type(d) == "table" then return d end
		end
	end
	return nil
end
-- lat / lon -> map metres through DCS's terrain (only for the loaded map)
local function rt_terrain()
	local ok, t = pcall(require, "terrain")
	if ok and type(t) == "table" and t.convertLatLonToMeters then return t end
	if type(Terrain) == "table" and Terrain.convertLatLonToMeters then return Terrain end
	return nil
end
local SAME_MAP = {germanycoldwar = "germanycw", sinai = "sinaimap", marianaswwii = "marianaislandswwii"}
local function map_id(n) n = tostring(n or ""):lower(); return SAME_MAP[n] or n end
local function rt_val(v)
	if type(v) == "number" then
		if v == math.floor(v) and math.abs(v) < 1e9 then return string.format("%d", v) end
		return string.format("%.15g", v)
	elseif type(v) == "boolean" then return tostring(v) end
	return string.format("%q", tostring(v))
end
-- the presets file, as DCS writes it
local PT_KEYS = {"alt", "type", "ETA", "ETA_locked", "y", "x", "name", "action", "alt_type", "speed", "speed_locked"}
local function rt_write(presets)
	local names = {}
	for k in pairs(presets) do names[#names + 1] = k end
	table.sort(names)
	local o = {"presets = \n{\n"}
	for _, n in ipairs(names) do
		o[#o + 1] = "\t[" .. string.format("%q", n) .. "] = \n\t{\n"
		for i, pt in ipairs(presets[n]) do
			o[#o + 1] = "\t\t[" .. i .. "] = \n\t\t{\n"
			local seen = {}
			for _, k in ipairs(PT_KEYS) do
				if pt[k] ~= nil then o[#o + 1] = "\t\t\t[\"" .. k .. "\"] = " .. rt_val(pt[k]) .. ",\n"; seen[k] = true end
			end
			for k, v in pairs(pt) do
				if not seen[k] and type(k) == "string" and type(v) ~= "table" then o[#o + 1] = "\t\t\t[" .. string.format("%q", k) .. "] = " .. rt_val(v) .. ",\n" end
			end
			o[#o + 1] = "\t\t}, -- end of [" .. i .. "]\n"
		end
		o[#o + 1] = "\t}, -- end of [" .. string.format("%q", n) .. "]\n"
	end
	o[#o + 1] = "} -- end of presets\n"
	return table.concat(o)
end
-- cartridge -> preset points (nil: no route / no coordinates)
local function rt_points(d, terr)
	if type(d.route) ~= "table" then return nil end
	local pts, eta, px, py = {}, 0, nil, nil
	for i, p in ipairs(d.route) do
		if type(p) ~= "table" then return nil end
		local x, y = tonumber(p.x), tonumber(p.y)
		if terr and tonumber(p.lat) and tonumber(p.lon) then
			local ok, tx, ty = pcall(terr.convertLatLonToMeters, tonumber(p.lat), tonumber(p.lon))
			if ok and type(tx) == "number" and tx == tx and type(ty) == "number" and ty == ty then x, y = tx, ty end
		end
		if not x or not y then return nil end
		if px then eta = eta + math.sqrt((x - px) ^ 2 + (y - py) ^ 2) / RT_SPEED end
		px, py = x, y
		local nm = tostring(p.name or ""):gsub("[^%w%-%./ ]", ""):sub(1, 16)
		pts[#pts + 1] = {alt = math.floor((tonumber(p.alt) or 0) * 0.3048 + 0.5), type = "Turning Point", ETA = math.floor(eta + 0.5),
			ETA_locked = false, y = y, x = x, name = (nm ~= "" and nm or ("STPT " .. i)), action = "Turning Point",
			alt_type = "BARO", speed = RT_SPEED, speed_locked = false}
	end
	return #pts > 0 and pts or nil
end
-- theatre_now: the loaded mission's map (its cartridges converted with the
-- terrain); others use the x / y the DTM Planner stores in the cartridge
local function sync_route_presets(theatre_now)
	local ok, err = pcall(function()
		local l = require("lfs")
		local dtc_dir = l.writedir() .. "DTC/F-15C/"
		local by_map, maps_seen, n_cart = {}, {}, 0
		local okd = pcall(function()
			for f in l.dir(dtc_dir) do
				if type(f) == "string" and f:lower():match("%.dtc$") then
					local fh = io.open(dtc_dir .. f, "r")
					local txt = fh and fh:read("*a") or ""
					if fh then fh:close() end
					if txt:sub(1, 3) == "\239\187\191" then txt = txt:sub(4) end
					local d = txt:find("F-15C", 1, true) and rt_json(txt)
					if d and tostring(d.type or ""):find("F%-15C") and type(d.terrain) == "string" and d.terrain ~= "" then
						local here = theatre_now and map_id(d.terrain) == map_id(theatre_now)
						local pts = rt_points(d, here and rt_terrain() or nil)
						local file_map = here and theatre_now or d.terrain
						maps_seen[file_map] = true
						if pts then
							by_map[file_map] = by_map[file_map] or {}
							by_map[file_map][RT_PREFIX .. f:gsub("%.[dD][tT][cC]$", "")] = pts
							n_cart = n_cart + 1
						end
					end
				end
			end
		end)
		if not okd then return end   -- no DTC folder
		local rt_dir = l.writedir() .. "Config/RouteToolPresets/"
		pcall(l.mkdir, rt_dir)
		-- also clean maps whose cartridges were all deleted: any presets file with ours in it
		pcall(function()
			for f in l.dir(rt_dir) do
				if type(f) == "string" and f:match("%.lua$") then maps_seen[f:sub(1, -5)] = maps_seen[f:sub(1, -5)] or false end
			end
		end)
		local n_files = 0
		for map, _ in pairs(maps_seen) do
			local path = rt_dir .. map .. ".lua"
			local presets, old_txt = {}, nil
			local fh = io.open(path, "r")
			if fh then old_txt = fh:read("*a"); fh:close() end
			if old_txt then
				local f = loadstring(old_txt)
				if not f then log("route presets: " .. map .. ".lua not readable, left alone"); presets = nil
				else
					local env = {}
					setfenv(f, env)
					if pcall(f) and type(env.presets) == "table" then presets = env.presets end
				end
			end
			if presets then
				local had_ours = false
				for k in pairs(presets) do
					if type(k) == "string" and k:sub(1, #RT_PREFIX) == RT_PREFIX then presets[k] = nil; had_ours = true end
				end
				local add = by_map[map] or {}
				for k, v in pairs(add) do presets[k] = v end
				if next(add) or had_ours then
					local new_txt = rt_write(presets)
					if new_txt ~= old_txt then
						-- the user's own file, once, before the add-on first changes it
						if old_txt and not had_ours then
							local b = io.open(path .. ".f15sit-backup", "r")
							if b then b:close() else
								b = io.open(path .. ".f15sit-backup", "w")
								if b then b:write(old_txt); b:close() end
							end
						end
						local w = io.open(path, "w")
						if w then w:write(new_txt); w:close(); n_files = n_files + 1 end
					end
				end
			end
		end
		log("route presets: " .. n_cart .. " cartridge route(s), " .. n_files .. " presets file(s) written" .. (theatre_now and (" (map " .. theatre_now .. ")") or ""))
	end)
	if not ok then log("route presets: " .. tostring(err)) end
end
local function mission_theatre()
	local ok, t = pcall(function()
		local m = DCS.getCurrentMission and DCS.getCurrentMission()
		return m and m.mission and m.mission.theatre
	end)
	return ok and type(t) == "string" and t or nil
end

function F15SIT_hook.onMissionLoadEnd()
	read_options()
	if OPT.f15c_sit_enabled then sync_route_presets(mission_theatre()) end
end

function F15SIT_hook.onSimulationStart()
	last = -100
	read_options()
	if not OPT.f15c_sit_enabled then log("add-on off (Options > Special)"); return end
	read_bullseye()
end

function F15SIT_hook.onSimulationStop()
	if OPT.f15c_sit_enabled then sync_route_presets(nil) end
	msg, msg_d, msg_p, unit_seen, mission, msg_r, searched = nil, nil, nil, nil, nil, nil, false
	msg_l, side_seen = nil, nil
end

function F15SIT_hook.onSimulationFrame()
	if not msg then return end
	local t = DCS.getRealTime()
	if t - last < 2 then return end
	last = t
	read_pylons()
	local u = sock()
	if u then
		if msg_p then pcall(u.sendto, u, msg_p, "127.0.0.1", PORT) end
		if msg_r then pcall(u.sendto, u, msg_r, "127.0.0.1", PORT) end
		if msg_p and side_seen and not msg_l then read_drawings() end
		if msg_l then pcall(u.sendto, u, msg_l, "127.0.0.1", PORT) end
		pcall(u.sendto, u, msg, "127.0.0.1", PORT)
		if msg_d then pcall(u.sendto, u, msg_d, "127.0.0.1", PORT) end
	end
end

-- EWR picture reports (server trigger texts, e.g. Contention): servers that
-- block export still show these. Forwarded as "F15SITE\n<text>" (ASCII,
-- at most 7500 bytes); the SIT draws their contacts when it has no
-- datalink picture. Only while a mission runs.
function F15SIT_hook.onTriggerMessage(message, duration, clearView)
	if not msg or type(message) ~= "string" or not OPT.f15c_sit_datalink then return end
	local up = message:upper()
	if not (up:find("EWR", 1, true) and up:find("PICTURE", 1, true)) then return end
	pcall(function()
		local out, n = {"F15SITE"}, 8
		for line in message:gmatch("[^\r\n]+") do
			local l = line:gsub("[\128-\255][\128-\191]*", "?"):gsub("%c", " ")
			if n + #l + 1 > 7500 then break end
			out[#out + 1] = l
			n = n + #l + 1
		end
		local u = sock()
		if u then pcall(u.sendto, u, table.concat(out, "\n"), "127.0.0.1", PORT) end
	end)
end

DCS.setUserCallbacks(F15SIT_hook)
log("loaded")
read_options()
if OPT.f15c_sit_enabled then sync_route_presets(nil) end
