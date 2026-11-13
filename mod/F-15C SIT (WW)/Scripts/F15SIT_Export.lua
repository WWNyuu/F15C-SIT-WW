-----------------------------------------------------------------------
-- F15SIT_Export.lua  --  feed for the F-15C SIT (WW) page, version 1.0
--
-- Based on MiG29DL_Export.lua of the Vitezovi MiG-29 MFD add-on, with the
-- SAME picture rules (own radar always; friendlies and the hostiles that a
-- friendly AWACS / EWR / ship / datalink fighter could plausibly see,
-- where the server allows object export), the same route / lock / stores
-- lines, but:
--   * only active in the Flaming Cliffs F-15C (unit type "F-15C")
--   * sends to 127.0.0.1:42889 (the MiG-29 add-on keeps 42888)
--   * packets start with "F15SIT"; RWR lines come from LoGetTWSInfo
--   * log: Saved Games\DCS\Logs\f15sit_export.log
--
-- Loaded from Saved Games\DCS\Scripts\Export.lua with:
--   pcall(function() local l=require('lfs'); dofile(l.writedir()..'Scripts/F15SIT_Export.lua') end)
-- Both scripts can be loaded at once: each one only works in its own jet.
-----------------------------------------------------------------------

local DL = {
	period          = 1.0,    -- s between packets to the cockpit
	awacs_period    = 6.0,    -- s between AWACS/EWR picture refreshes (report latency)

	friendly_range  = 300000, -- m: friendly aircraft shown within this distance
	awacs_range     = 350000, -- m: AWACS detection range vs. fighters
	ewr_range       = 250000, -- m
	ship_range      = 150000, -- m
	fighter_range   =  80000, -- m: shared fighter radar range
	fighter_cone    = 60,     -- deg half-angle of a shared fighter radar
	ewr_mast        = 25,     -- m antenna height above ground for EWR / SAM search radars
	terrain_samples = 24,     -- LOS samples per sensor/target pair
	use_horizon     = true,   -- apply 4/3-earth radar horizon
	share_fighters  = true,   -- friendly fighters with radar on share contacts
	share_ships     = true,
	max_contacts    = 40,     -- must match MAX_CONTACTS in sit_config.lua

	-- fighter-to-fighter datalink: friendly fighters of these types share
	-- what their radar sees (Lua patterns matched against the unit type)
	f2f_period      = 2.0,    -- s between fighter datalink updates
	threat_period   = 3.0,    -- s between ground-threat line-of-sight checks
	los_budget      = 2500,   -- max terrain samples per tick, shared by the three refreshes (keeps big missions cheap)
	-- v1.7.5: one packet's work is spread over several frames (no single
	-- long frame): the world scan gets a frame of its own, then at most
	-- this many objects / terrain samples per frame. false = all in one frame.
	spread          = true,
	spread_ms       = 1,      -- work per frame before it gives the frame back (os.clock steps in 1 ms on Windows)
	spread_objects  = 250,    -- (how often the clock is looked at: every 1/250 of the cost units below)
	spread_samples  = 300,
	spread_max_frames = 90,   -- after this many frames the rest of the packet is done at once
	-- v1.7.5: busy missions. When DCS's world scan (LoGetWorldObjects) takes
	-- big_scan_ms or more (average), it runs only every big_scan_period s;
	-- the packets in between (still every second: fuel, engines, stores...)
	-- send the last picture again, aged (the cockpit dead-reckons it), with
	-- the own radar's contacts fresh. Back to every second below 2/3 of it.
	-- the time between full scans then follows the scan's cost:
	-- big_scan_s_per_ms seconds per ms of scan, from big_scan_period up to
	-- big_scan_max s (a 6 ms scan: every ~3 s, a 12 ms scan: every 6 s)
	big_scan        = true,
	big_scan_ms     = 3,
	big_scan_period = 2,
	big_scan_s_per_ms = 0.5,
	big_scan_max    = 6,
	f2f_assume_radar_on = true, -- AI radar state is often not exported: assume on
	DATALINK = { "^F%-16", "^FA%-18", "^F%-15", "^F%-14", "^JF%-17", "^J%-11", "^Su%-30", "^Su%-35",
	             "^MiG%-31", "Typhoon", "Rafale", "Gripen", "^AV8BNA", "^A%-10C", "^F%-35", "^F%-22" },

	-- ground threats: enemy SAM / EWR radars that a friendly aircraft could
	-- pick up (inside the radar's detection range with line of sight) are
	-- reported with their approximate lethal ring.
	max_threats     = 12,     -- must match MAX_THREATS in sit_config.lua
	THREATS = {   -- {pattern (lower case), label, ring m, detection m}
		{"s%-300ps 40b6m tr", "SA-10", 75000, 160000}, {"s%-300ps 40b6md sr", "SA-10", 75000, 160000},
		{"s%-300ps 64h6e sr", "SA-10", 75000, 200000}, {"buk sr", "SA-11", 35000, 100000},
		{"buk ln", "SA-11", 35000, 60000}, {"kub 1s91", "SA-6", 25000, 70000},
		{"osa 9a33", "SA-8", 10000, 30000}, {"tor 9a331", "SA-15", 12000, 25000},
		{"snr_75v", "SA-2", 43000, 100000}, {"snr s%-125", "SA-3", 18000, 60000},
		{"p%-19 s%-125", "SA-3", 18000, 160000}, {"rpc_5n62v", "SA-5", 150000, 270000},
		{"strela%-10", "SA-13", 5000, 10000}, {"strela%-1 ", "SA-9", 4000, 8000},
		{"tunguska", "SA-19", 8000, 18000}, {"zsu%-23%-4", "ZSU", 2500, 8000},
		{"hawk tr", "HAWK", 45000, 90000}, {"hawk sr", "HAWK", 45000, 90000},
		{"patriot str", "PAT", 100000, 160000}, {"nasams_radar", "NASM", 25000, 50000},
		{"rapier_fsa_blindfire", "RAP", 7000, 20000}, {"roland ads", "ROL", 8000, 15000},
		{"hq%-7_str", "HQ-7", 12000, 25000}, {"gepard", "GEP", 4000, 15000},
		{"1l13 ewr", "EWR", 0, 300000}, {"55g6 ewr", "EWR", 0, 300000},
		{"fps%-117", "EWR", 0, 300000}, {"dog ear", "EWR", 0, 35000},
	},

	AWACS = { ["A-50"] = true, ["E-3A"] = true, ["E-2C"] = true, ["KJ-2000"] = true, ["E-2D"] = true },
	EWR   = {
		["1L13 EWR"] = true, ["55G6 EWR"] = true, ["FPS-117"] = true, ["FPS-117 Dome"] = true,
		["p-19 s-125 sr"] = 160000, ["S-300PS 40B6MD sr"] = 160000, ["S-300PS 64H6E sr"] = 200000,
		["SA-11 Buk SR 9S18M1"] = 100000, ["Dog Ear radar"] = 35000, ["Kub 1S91 str"] = 70000,
		["Patriot str"] = 160000, ["Hawk sr"] = 90000, ["NASAMS_Radar_MPQ64F1"] = 50000,
		["RLS_19J6"] = 150000, ["RPC_5N62V"] = 270000, ["S-200_Radar"] = 270000,
	},
}

-- switches from DCS Options > Special > F-15C SIT (Saved Games\DCS\Config\options.lua),
-- read when a mission starts: with the datalink off no world objects are
-- scanned at all (only the own radar picture is sent), with the RWR off no
-- RWR packets are sent
-- (RWR packets off: the SIT page shows no RWR, the TEWS scope does)
-- (f15c_sit_logs: timing and debug logs, for testing; off by default)
local OPT = {f15c_sit_enabled = true, f15c_sit_datalink = true, f15c_sit_rwr = false, f15c_sit_logs = false}
local function read_options()
	pcall(function()
		local lfs_mod = require("lfs")
		local f = loadfile(lfs_mod.writedir() .. "Config/options.lua")
		if not f then return end
		local env = {}
		setfenv(f, env)
		f()
		local p = env.options and env.options.plugins and env.options.plugins["f15c_sit"]
		if type(p) ~= "table" then return end
		for k in pairs(OPT) do if type(p[k]) == "boolean" then OPT[k] = p[k] end end
	end)
end
read_options()

-- (no coroutine library in this Lua state: everything in one frame, as before v1.7.5)
if type(coroutine) ~= "table" or not coroutine.create then DL.spread = false end

local MAX_ROUTE = 20   -- must match DL_MAX_WPTS
-- every datagram stays below this (contract with the cockpit device): long
-- names are cut and lines of lower priority are left out when it is full
local MAX_PACKET = 7500

-- a DCS export function that may be missing or switched off by the server
-- (it then raises an error or returns nothing): nil instead of an error
local function try(f, ...)
	if not f then return nil end
	local ok, r = pcall(f, ...)
	if ok then return r end
	return nil
end

-- F-15C SIT: only the Flaming Cliffs F-15C (unit type "F-15C"), the one
-- jet the SIT add-on cockpit exists in. (Function name kept from the
-- MiG-29 add-on this file is based on.)
local ff_cache = {}
local function is_ff_mig29(name)
	if type(name) ~= "string" then return false end
	local c = ff_cache[name]
	if c == nil then
		c = name:lower():gsub("[^%w]", "") == "f15c"
		ff_cache[name] = c
	end
	return c
end

-----------------------------------------------------------------------
-- names that go to the cockpit (unit, player and type names): the MFD
-- font only has ASCII 32-126 and the packet fields are separated by "," and
-- "|". Common accented / Cyrillic letters are transliterated, everything
-- else non-ASCII becomes "?", separators and control characters a space.
-- Long names are cut to 24 characters keeping the start and the end
-- ("[127th] Vitezovi~ani 1-1"), so numbered units stay apart and a packet
-- stays small.
-- KEEP clean() IDENTICAL IN MiG29DL_Hook.lua: the cockpit matches the unit
-- names of these F lines against the hook's player lists.
-----------------------------------------------------------------------
local TR = {}   -- UTF-8 two-byte letter -> ASCII
do
	local function map(first, list)
		local cp = first
		for w in list:gmatch("%S+") do
			-- "?" = no ASCII form, "-" = dropped (Cyrillic hard / soft sign)
			if w ~= "?" then TR[string.char(192 + math.floor(cp / 64), 128 + cp % 64)] = (w == "-") and "" or w end
			cp = cp + 1
		end
	end
	map(0x00C0, "A A A A A A AE C E E E E I I I I D N O O O O O x O U U U U Y TH ss " ..
	            "a a a a a a ae c e e e e i i i i d n o o o o o ? o u u u u y th y")
	map(0x0100, "A a A a A a C c C c C c C c D d Dj dj E e E e E e E e E e G g G g " ..
	            "G g G g H h H h I i I i I i I i I i IJ ij J j K k k L l L l L l L " ..
	            "l L l N n N n N n n N n O o O o O o OE oe R r R r R r S s S s S s " ..
	            "S s T t T t T t U u U u U u U u U u U u W w Y y Y Z z Z z Z z s")
	map(0x0400, "E E Dj G E Dz I I J Lj Nj C K I U Dz A B V G D E Zh Z I J K L M N O P " ..
	            "R S T U F H C Ch Sh Shch - Y - E Yu Ya a b v g d e zh z i j k l m n o p " ..
	            "r s t u f h c ch sh shch - y - e yu ya e e dj g e dz i i j lj nj c k i u dz")
	map(0x0490, "G g")
	TR["\194\160"] = " "   -- no-break space
end
local function tr_char(ch) return TR[ch] or "?" end
local function ascii(v)
	local s = tostring(v or ""):gsub("[\128-\255][\128-\191]*", tr_char)
	s = s:gsub("[%c,|;]", " ")
	return (s:gsub("^ +", ""):gsub(" +$", ""))
end
local clean_cache, clean_n = {}, 0
local function clean(v)
	local s = tostring(v or "")
	local c = clean_cache[s]
	if c then return c end
	c = ascii(s)
	if #c > 24 then c = c:sub(1, 16) .. "~" .. c:sub(-7) end
	-- the cache only holds the names of one mission; a mission that keeps
	-- spawning new units must not grow it without end
	if clean_n >= 4000 then clean_cache, clean_n = {}, 0 end
	clean_cache[s], clean_n = c, clean_n + 1
	return c
end

-- add one line to a packet unless that would make it larger than MAX_PACKET
-- (1 byte stays free for the closing "E" line). Once full, nothing more is
-- added, so the order in which lines are added is their priority.
local function put(out, line)
	if out.full then return false end
	local sz = (out.size or 0) + #line + 1
	if sz > MAX_PACKET - 1 then out.full = true; return false end
	out[#out + 1] = line
	out.size = sz
	return true
end

local last_send, last_awacs, last_prune = -1000, -1000, -1000
local f2f_seen    = {}      -- [id] = true for hostiles a datalink fighter sees
local threat_mem  = {}      -- [id] = {lbl, x, y, z, ring} detected enemy SAM / EWR sites
local thr_try     = {}      -- [id] = next friendly aircraft to try for a site not detected yet
-- type lookups are remembered per type name (they run for every unit, every second)
local dl_cache, threat_cache, notac_cache = {}, {}, {}
local function is_datalink(name)
	name = name or ""
	local c = dl_cache[name]
	if c == nil then
		c = false
		for _, p in ipairs(DL.DATALINK) do
			if string.find(name, p) then c = true; break end
		end
		dl_cache[name] = c
	end
	return c
end
local function threat_of(name)
	name = name or ""
	local c = threat_cache[name]
	if c == nil then
		c = false
		local n = string.lower(name)
		for _, th in ipairs(DL.THREATS) do
			if string.find(n, th[1]) then c = th; break end
		end
		threat_cache[name] = c
	end
	return c or nil
end
-- ejected pilots / parachutes are level1 = 1 objects but not aircraft
local function not_aircraft(name)
	local c = notac_cache[name]
	if c == nil then
		local n = string.lower(name)
		c = (n:find("^pilot") or n:find("parachut")) and true or false
		notac_cache[name] = c
	end
	return c
end
local awacs_seen  = {}      -- [id] = true for hostiles the coalition sensors saw at the last refresh
local awacs_up    = false
local prev_pos    = {}      -- [id] = {t, x, z}
local vel         = {}      -- [id] = {vx, vz}

-- errors into dcs.log: at most one per 30 s and 5 per mission, so a
-- broken feature can never fill the log
local last_log, log_count = -1000, 0
local function log_err(msg)
	local t = LoGetModelTime and LoGetModelTime() or 0
	if t - last_log < 30 or log_count >= 5 then return end
	last_log, log_count = t, log_count + 1
	if log and log.write then log.write("F15SIT", log.ERROR, tostring(msg)) end
end

-- transport: UDP to the cockpit device on this PC (127.0.0.1). The KRN
-- plugin devices share numbers with the jet's own devices, so GetDevice(n)
-- from here would reach the wrong system - a local socket avoids that.
-- LuaSocket is shared with the other export tools: one already loaded is
-- used as it is; otherwise our LuaSocket path is added to package.path /
-- cpath once (never twice, even if this file is loaded again), and a failed
-- require is retried at most every 30 s (each try searches the disk).
local DL_PORT = 42889   -- F-15C SIT device (the MiG-29 add-on uses 42888)
local udp = nil
local sock = {paths = false, fail_t = nil}
local function add_path(field, entry)
	local p = package[field] or ""
	if not p:find(entry, 1, true) then package[field] = p .. ";" .. entry end
end
local function get_udp()
	if udp then return udp end
	if sock.fail_t and math.abs(os.time() - sock.fail_t) < 30 then return nil end
	local socket = package.loaded["socket"]
	if type(socket) ~= "table" then
		if not sock.paths then
			sock.paths = true
			local ok_lfs, lfs_mod = pcall(require, "lfs")
			local root = (ok_lfs and lfs_mod and lfs_mod.currentdir and lfs_mod.currentdir()) or "."
			add_path("path", root .. "/LuaSocket/?.lua")
			add_path("cpath", root .. "/LuaSocket/?.dll")
		end
		local ok, s = pcall(require, "socket")
		socket = ok and type(s) == "table" and s or nil
	end
	local u = socket and try(socket.udp)
	if not u then sock.fail_t = os.time(); return nil end
	sock.fail_t = nil
	u:settimeout(0)
	u:setpeername("127.0.0.1", DL_PORT)
	udp = u
	return udp
end

local function dist2d(ax, az, bx, bz)
	local dx, dz = ax - bx, az - bz
	return math.sqrt(dx * dx + dz * dz)
end

-- v1.7.5: work spreading. SPREAD.on is true only while the picture runs in
-- its own coroutine; spread_point() then gives the frame back once enough
-- work is done. (No yield inside a pcall: Lua 5.1 cannot yield across it.)
-- v1.7.5 (after the third log flight): by TIME, not by a work estimate.
-- Each frame works until spread_ms has passed since that frame's slice
-- began (SPREAD.t0, set before every resume), then yields. The estimate
-- grew the slices with the mission, terrain checks included: up to ~540
-- terrain samples in one frame, 5-18 ms in DCS.
local SPREAD = {on = false, cost = 0, frames = 0, t0 = 0}
local clock = os.clock
local function spread_point(cost)
	if not SPREAD.on or SPREAD.frames >= DL.spread_max_frames then return end
	SPREAD.cost = SPREAD.cost + cost
	if SPREAD.cost < 0.02 then return end           -- (look at the clock every few objects only)
	SPREAD.cost = 0
	if clock() - SPREAD.t0 >= DL.spread_ms / 1000 then coroutine.yield() end
end
local JOB = nil                -- the packet being built (coroutine), see tick()

-- terrain samples left in this tick: set once per tick and shared by the
-- AWACS, fighter-datalink and ground-threat refreshes
local los_budget = 0
local alt_ok = true           -- false once LoGetAltitude raised an error
local function los_samples(x1, y1, z1, x2, y2, z2, n)
	for i = 1, n - 1 do
		local t = i / n
		local x = x1 + (x2 - x1) * t
		local z = z1 + (z2 - z1) * t
		local y = y1 + (y2 - y1) * t
		local g = LoGetAltitude(x, z)
		if g and g > y then return false end
	end
	return true
end
-- strict: out of budget returns nil ("not known yet") instead of true
local function terrain_clear(x1, y1, z1, x2, y2, z2, strict)
	if not LoGetAltitude or not alt_ok then return true end
	-- one sample every ~4 km (6 .. terrain_samples); out of budget: assume clear
	local d = dist2d(x1, z1, x2, z2)
	local n = math.max(6, math.min(DL.terrain_samples, math.floor(d / 4000)))
	if los_budget < n then
		if strict then return nil end
		return true
	end
	los_budget = los_budget - n
	spread_point(n / DL.spread_samples)
	local ok, clear = pcall(los_samples, x1, y1, z1, x2, y2, z2, n)
	if ok then return clear end
	-- LoGetAltitude switched off / broken: stop asking, treat as clear
	alt_ok = false
	log_err(clear)
	return true
end

local function horizon_ok(h1, h2, d)
	if not DL.use_horizon then return true end
	local R = 6371000 * 4 / 3
	local lim = math.sqrt(2 * R * math.max(h1, 0)) + math.sqrt(2 * R * math.max(h2, 0))
	return d <= lim
end

local function sees(sensor, tgt)
	local d = dist2d(sensor.x, sensor.z, tgt.x, tgt.z)
	if d > sensor.range then return false end
	if sensor.cone then
		local brg = math.atan2(tgt.z - sensor.z, tgt.x - sensor.x)   -- DCS: x north, z east
		local diff = math.abs(((brg - sensor.hdg) + math.pi) % (2 * math.pi) - math.pi)
		if diff > sensor.cone then return false end
	end
	if not horizon_ok(sensor.y, tgt.y, d) then return false end
	-- nil = the terrain budget of this tick is used up: not known (the
	-- caller keeps what the last refresh found for this target)
	return terrain_clear(sensor.x, sensor.y, sensor.z, tgt.x, tgt.y, tgt.z, true)
end

local function pos_of(o)
	local p = o.Position or (o.position and (o.position.p or o.position))
	if not p then return nil end
	return p.x, p.y, p.z
end

local function update_velocity(id, t, x, z)
	local p = prev_pos[id]
	if p then
		if t > p.t + 0.2 then
			local dt = t - p.t
			local vx, vz = (x - p.x) / dt, (z - p.z) / dt
			if math.abs(vx) < 1500 and math.abs(vz) < 1500 then
				local v = vel[id]
				if v then v[1], v[2] = vx, vz else vel[id] = {vx, vz} end
			end
		end
		p.t, p.x, p.z, p.seen = t, x, z, t
	else
		prev_pos[id] = {t = t, x = x, z = z, seen = t}
	end
end

-- v1.7.5: busy missions (DL.big_scan): the last full picture and how long the
-- world scan takes (see scan_timed / scan_due / reuse_picture)
local SCAN = {t = nil, ema = nil, big = false}
-- is the datalink picture on screen? The SIT device tells ("F15SITG,1/0",
-- once a second and on every page change): only the SIT, FLIGHT DATA and
-- SIT SETTINGS pages show it. Off them, DCS's world scan (LoGetWorldObjects,
-- several ms on a busy server) is skipped and the last picture is sent on,
-- aged. No word from the device for 3 s: scanned as before.
local PIC = {need = true, t = nil, n = 0}
local function pic_needed(t)
	if PIC.t == nil or t < PIC.t or t - PIC.t > 3 then return true end
	return PIC.need
end

-- the three coalition refreshes run on different ticks: tick n runs the
-- AWACS picture when n % 6 == 0, the fighter datalink when n % 2 == 1 and
-- the ground threats when n % 3 == 2 (with the default periods); they can
-- only meet every 6th tick, and then they share the one LOS budget
local SCHED = {n = -1, thr_ofs = 0}
-- seconds between full world scans: every packet (DL.period) normally; on a
-- busy mission from the scan's cost (DL.big_scan_s_per_ms), big_scan_period
-- .. big_scan_max s
local function scan_interval()
	if not (DL.big_scan and SCAN.big and SCAN.ema) then return DL.period end
	local iv = SCAN.ema * 1000 * (DL.big_scan_s_per_ms or 0.5)
	return math.max(DL.big_scan_period or 2, math.min(DL.big_scan_max or 6, iv))
end
local function due(period, offset)
	local every = math.max(1, math.floor(period / DL.period + 0.5))
	-- v1.7.5: busy mission (a full scan only every big_scan_period s): the
	-- periods stay in seconds (AWACS every 6 s, not every 6th scan)
	if DL.big_scan and SCAN.big then every = math.max(1, math.floor(period / scan_interval() + 0.5)) end
	return SCHED.n % every == offset % every
end

-- own radar contacts (sensor export)
local function own_radar()
	local radar = {}
	local ok, tgts = pcall(function() return LoGetTargetInformation and LoGetTargetInformation() end)
	if ok and type(tgts) == "table" then
		for _, tg in pairs(tgts) do
			local x, y, z = pos_of(tg)
			if x then
				local vx, vz = 0, 0
				if type(tg.velocity) == "table" then vx, vz = tg.velocity.x or 0, tg.velocity.z or 0 end
				radar[#radar + 1] = {id = tg.ID, x = x, y = y, z = z, vx = vx, vz = vz}
			end
		end
	end
	return radar
end

-- nearest first, own radar first
local function by_distance(a, b)
	local ra, rb = a.typ >= 10, b.typ >= 10
	if ra ~= rb then return ra end
	return a.d < b.d
end

-- only the own radar: used when the full picture failed (an error must
-- never stop the packet)
local function radar_picture(me)
	local list = {}
	local radar = own_radar()
	for _, r in ipairs(radar) do
		list[#list + 1] = {typ = 13, x = r.x, z = r.z, y = r.y, vx = r.vx, vz = r.vz, age = 0,
		                   d = dist2d(r.x, r.z, me.x, me.z)}
	end
	table.sort(list, by_distance)
	return list, (#radar > 0) and 4 or 0, {}, {}
end

-- v1.7.5: busy missions (DL.big_scan): the last full picture, and how long
-- the world scan takes (average of the last scans)
local function scan_timed(d, t)
	SCAN.ema = SCAN.ema and (0.7 * SCAN.ema + 0.3 * d) or d
	local lim = (DL.big_scan_ms or 3) / 1000
	local big = SCAN.big
	if not big and SCAN.ema >= lim then big = true
	elseif big and SCAN.ema < lim * 2 / 3 then big = false end
	SCAN.big = big
	-- (logged when the whole seconds between scans change, at most 12 times)
	local every = math.floor(scan_interval() + 0.5)
	if every ~= SCAN.every and (SCAN.n_log or 0) < 12 then
		SCAN.n_log = (SCAN.n_log or 0) + 1
		if SCAN.log and SCAN.every then SCAN.log(string.format("world scan %.1f ms: full scan every %d s", SCAN.ema * 1000, every)) end
	end
	SCAN.every = every
end
local function build_picture(t, self_id, me, noscan)
	local list = {}
	local status = 0
	local mx, my, mz = me.x, me.y, me.z
	local my_coal = me.coal

	-- world objects --------------------------------------------------
	-- (noscan: the picture is not on screen and there is none yet: own radar only)
	local sc0 = os.clock()
	local objs = (OPT.f15c_sit_datalink and not noscan) and try(LoGetWorldObjects) or nil
	if not noscan then
		scan_timed(os.clock() - sc0, t)
		SCHED.scan = true                  -- (timing log: this frame had the world scan)
	end
	-- v1.7.5: the scan gets a frame of its own (also when the slices are big)
	if SPREAD.on and SPREAD.frames < DL.spread_max_frames then SPREAD.cost = 0; coroutine.yield() end
	local have_objs = false
	local air, sensors, fighters, ground, present = {}, {}, {}, {}, {}
	if type(objs) == "table" then
		local per_obj = 1 / DL.spread_objects
		for id, o in pairs(objs) do
			have_objs = true
			spread_point(per_obj)
			local fl = o.Flags
			-- late-activation templates (not born yet) and static objects are
			-- no contacts, no flight members, no sensors and no threats
			if not (fl and (fl.Born == false or fl.Static == true)) then
				local lvl1 = o.Type and o.Type.level1
				local x, y, z = pos_of(o)
				local coal = o.CoalitionID
				-- without our object id: our own jet is the friendly at our position
				if x and (id == self_id or (self_id == nil and coal == my_coal and math.abs(x - mx) < 5 and math.abs(z - mz) < 5)) then
					x = nil
				end
				if x then
					local name = o.Name or ""
					if lvl1 == 1 and not_aircraft(name) then lvl1 = nil end
					if lvl1 == 1 then
						update_velocity(id, t, x, z)
						local a = {id = id, x = x, y = y, z = z, coal = coal, name = name,
						           group = o.GroupName, hdg = o.Heading or 0,
						           radar = fl and fl.RadarActive,
						           unit = o.UnitName or (name .. " " .. tostring(id)), human = fl and fl.Human,
						           jam = fl and (fl.Jamming or fl.IRJamming)}
						a.dl = is_datalink(name)
						air[#air + 1] = a
						if coal == my_coal then
							if DL.AWACS[name] then
								sensors[#sensors + 1] = {x = x, y = y, z = z, range = DL.awacs_range}
							elseif DL.share_fighters and a.dl and (a.radar or DL.f2f_assume_radar_on) then
								fighters[#fighters + 1] = {x = x, y = y, z = z, range = DL.fighter_range,
								                           hdg = a.hdg, cone = math.rad(DL.fighter_cone)}
							end
						end
					elseif coal ~= my_coal and coal ~= 0 and lvl1 == 2 then
						local th = threat_of(name)
						if th then
							present[id] = true
							-- a remembered site that has driven off (mobile SAMs) is
							-- looked for again: its ring stays at the last known
							-- place until an aircraft sees it where it is now
							-- (before, it stayed at the first place for good)
							local m = threat_mem[id]
							if m and not m.moved and dist2d(m.x, m.z, x, z) > 500 then m.moved = true end
							if not m or m.moved then
								ground[#ground + 1] = {id = id, th = th, x = x, y = y or 0, z = z}
							end
						end
					elseif coal == my_coal and (lvl1 == 2 or lvl1 == 3) then
						local r = DL.EWR[name]
						if r then
							local rng = (r == true) and DL.ewr_range or r
							sensors[#sensors + 1] = {x = x, y = (y or 0) + DL.ewr_mast, z = z, range = rng}
						elseif lvl1 == 3 and DL.share_ships then
							sensors[#sensors + 1] = {x = x, y = (y or 0) + 30, z = z, range = DL.ship_range}
						end
					end
				end
			end
		end
	end
	if have_objs then status = status + 1 end
	-- forget aircraft that are gone (keeps the tables small in long missions)
	if t - last_prune > 30 then
		last_prune = t
		for id, p in pairs(prev_pos) do
			if t - (p.seen or p.t) > 15 then prev_pos[id] = nil; vel[id] = nil; awacs_seen[id] = nil; f2f_seen[id] = nil end
		end
	end

	-- one terrain budget for this tick, whichever refreshes run in it
	SCHED.n = SCHED.n + 1
	los_budget = DL.los_budget

	-- coalition sensor refresh (slow, like a real report cycle) --------
	if due(DL.awacs_period, 0) then
		last_awacs = t
		-- A target the terrain budget did not reach in this refresh keeps
		-- the answer of the last one: out of budget must not count as
		-- "seen" (it showed aircraft behind terrain in big missions). The
		-- next refresh starts at the first target this one could not check,
		-- so every target gets its real check within a few refreshes.
		local was = awacs_seen
		awacs_seen = {}
		awacs_up = false
		for _, s in ipairs(sensors) do
			if not s.cone then awacs_up = true end
		end
		local na = #air
		local ofs, first_unknown = SCHED.air_ofs or 0, nil
		for k = 0, na - 1 do
			local a = air[(ofs + k) % na + 1]
			spread_point(1 / DL.spread_objects)
			if a.coal ~= my_coal and a.coal ~= 0 then
				local seen, unknown = false, false
				for _, s in ipairs(sensors) do
					local r = sees(s, a)
					if r then seen = true; break end
					if r == nil then unknown = true; break end      -- no budget left: the other sensors cannot be asked either
				end
				if unknown and not first_unknown then first_unknown = k end
				if seen or (unknown and was[a.id]) then
					local v = vel[a.id] or {0, 0}
					awacs_seen[a.id] = {x = a.x, y = a.y, z = a.z, vx = v[1], vz = v[2]}
				end
			end
		end
		if first_unknown then SCHED.air_ofs = (ofs + first_unknown) % na end
	end
	if awacs_up then status = status + 2 end

	-- fighter-to-fighter datalink: what datalink fighters' radars see ------
	if due(DL.f2f_period, 1) then
		local was = f2f_seen          -- as above: no budget = last refresh's answer
		f2f_seen = {}
		local na = #air
		local ofs, first_unknown = SCHED.f2f_ofs or 0, nil
		for k = 0, na - 1 do
			local a = air[(ofs + k) % na + 1]
			if a.coal ~= my_coal and a.coal ~= 0 then
				local seen, unknown = false, false
				for _, s in ipairs(fighters) do
					local r = sees(s, a)
					if r then seen = true; break end
					if r == nil then unknown = true; break end
				end
				if unknown and not first_unknown then first_unknown = k end
				if seen or (unknown and was[a.id]) then f2f_seen[a.id] = true end
			end
		end
		if first_unknown then SCHED.f2f_ofs = (ofs + first_unknown) % na end
	end
	if #fighters > 0 then status = status + 8 end

	-- ground threats: picked up by any friendly aircraft (incl. us) -------
	if have_objs and due(DL.threat_period, 2) then
		for id in pairs(threat_mem) do
			if not present[id] then threat_mem[id] = nil end       -- destroyed / gone
		end
		for id in pairs(thr_try) do
			if not present[id] or (threat_mem[id] and not threat_mem[id].moved) then thr_try[id] = nil end
		end
		local friends = {{x = mx, y = my, z = mz}}
		for _, a in ipairs(air) do
			if a.coal == my_coal then friends[#friends + 1] = a end
		end
		-- a detected site is remembered until it is gone, so running out of
		-- budget must not count as "seen" here (that would reveal SAMs behind
		-- terrain for good): the check stops and the next threat refresh goes
		-- on from that site. A site is tried against at most 3 friendly
		-- aircraft per refresh (the next 3 at the next refresh), so a few
		-- hidden sites cannot use up the budget and starve all the others.
		local ng, nf = #ground, #friends
		local start = (ng > 0) and (SCHED.thr_ofs % ng) or 0
		for k = 0, ng - 1 do
			spread_point(1 / DL.spread_objects)
			local g = ground[(start + k) % ng + 1]
			local th = g.th
			local i0 = thr_try[g.id] or 0
			local j, tried, out_of_budget = 0, 0, false
			while j < nf and tried < 3 do
				local f = friends[(i0 + j) % nf + 1]
				local d = dist2d(f.x, f.z, g.x, g.z)
				if d <= th[4] and horizon_ok(g.y + DL.ewr_mast, f.y, d) then
					local clear = terrain_clear(g.x, g.y + DL.ewr_mast, g.z, f.x, f.y, f.z, true)
					if clear == nil then out_of_budget = true; break end
					tried = tried + 1
					if clear then
						threat_mem[g.id] = {lbl = th[2], x = g.x, y = g.y, z = g.z, ring = th[3]}
						break
					end
				end
				j = j + 1
			end
			thr_try[g.id] = (i0 + j) % nf       -- the first friend not tried yet
			if out_of_budget then SCHED.thr_ofs = start + k; break end
		end
	end

	-- own radar --------------------------------------------------------
	local radar = own_radar()
	if #radar > 0 then status = status + 4 end
	local radar_by_id = {}
	for _, r in ipairs(radar) do if r.id then radar_by_id[r.id] = r end end

	-- assemble ---------------------------------------------------------
	local used = {}
	for _, a in ipairs(air) do
		spread_point(1 / DL.spread_objects)
		local typ = nil
		if a.coal == my_coal then
			if dist2d(a.x, a.z, mx, mz) <= DL.friendly_range then
				if DL.AWACS[a.name] then typ = 4
				elseif me.group and a.group == me.group then typ = 5
				elseif a.dl then typ = 6
				else typ = 1 end
			end
		elseif f2f_seen[a.id] then
			typ = 2
			a.f2f = true
		elseif awacs_seen[a.id] then
			typ = 2
		end
		local r = radar_by_id[a.id]
		local base_typ = typ
		if r then
			if a.coal == my_coal then
				typ = (typ == 5 and 15) or (typ == 4 and 14) or (typ == 6 and 16) or 11
			else
				typ = 12
			end
		end
		if typ then
			local v = vel[a.id] or {0, 0}
			local item = {typ = typ, x = a.x, z = a.z, y = a.y, vx = v[1], vz = v[2], age = 0,
			              d = dist2d(a.x, a.z, mx, mz), nm = (a.name ~= "") and a.name or nil,
			              id = a.id, base_typ = base_typ, own = (a.coal == my_coal)}   -- (last three: v1.7.5, not sent)
			if r then
				item.x, item.z, item.y, item.vx, item.vz = r.x, r.z, r.y, r.vx, r.vz
			elseif typ == 2 and not a.f2f then
				-- AWACS / coalition report: position as of the last report, the
				-- cockpit dead-reckons it forward
				local snap = awacs_seen[a.id]
				item.x, item.z, item.y, item.vx, item.vz = snap.x, snap.z, snap.y, snap.vx, snap.vz
				item.age = t - last_awacs
			end
			list[#list + 1] = item
			used[a.id] = true
		end
	end
	-- radar contacts we could not match to a world object (export off)
	for _, r in ipairs(radar) do
		if not (r.id and used[r.id]) then
			list[#list + 1] = {typ = 13, x = r.x, z = r.z, y = r.y, vx = r.vx, vz = r.vz, age = 0,
			                   d = dist2d(r.x, r.z, mx, mz)}
		end
	end

	table.sort(list, by_distance)
	local thr = {}
	for _, m in pairs(threat_mem) do
		spread_point((#thr + 1) / (20 * DL.spread_objects))   -- (v1.7.5: the compare below grows with the sites)
		-- one entry per site: skip a second radar of the same type close by
		local dup = false
		for _, o in ipairs(thr) do
			if o.lbl == m.lbl and dist2d(o.x, o.z, m.x, m.z) < 5000 then dup = true; break end
		end
		if not dup then
			m.d = dist2d(m.x, m.z, mx, mz)
			thr[#thr + 1] = m
		end
	end
	table.sort(thr, function(a, b) return a.d < b.d end)
	return list, status, thr, air
end

local function fmt(v) return string.format("%.1f", v or 0) end

-- the route that is loaded in the jet (DTC / mission / edits in the cockpit)
local function route_lines(out)
	local ok, r = pcall(function() return LoGetRoute and LoGetRoute() end)
	if not ok or type(r) ~= "table" or type(r.route) ~= "table" then return end
	local pts = {}
	for _, p in pairs(r.route) do
		if type(p) == "table" and type(p.world_point) == "table" and p.world_point.x then
			pts[#pts + 1] = p
		end
	end
	table.sort(pts, function(a, b) return (a.this_point_num or 0) < (b.this_point_num or 0) end)
	local goto_num = r.goto_point and r.goto_point.this_point_num
	local active = 0
	for i = 1, math.min(#pts, MAX_ROUTE) do
		local p = pts[i]
		if not put(out, "W," .. fmt(p.world_point.x) .. "," .. fmt(p.world_point.z) .. "," .. tostring(p.this_point_num or (i - 1))) then break end
		if goto_num and p.this_point_num == goto_num then active = i end
	end
	put(out, "A," .. active)
end

-- weapon names for the SMS page, looked up once per weapon type
local name_cache = {}
local function store_name(w)
	if type(w) ~= "table" or not LoGetNameByType then return "" end
	local key = (w.level1 or 0) .. "." .. (w.level2 or 0) .. "." .. (w.level3 or 0) .. "." .. (w.level4 or 0)
	local n = name_cache[key]
	if not n then
		local ok, r = pcall(LoGetNameByType, w.level1 or 0, w.level2 or 0, w.level3 or 0, w.level4 or 0)
		n = ascii((ok and r) and tostring(r) or ""):sub(1, 40)
		name_cache[key] = n
	end
	return n
end

-----------------------------------------------------------------------
-- which aircraft we sit in, once per frame time. LoGetSelfData (ownship
-- export) can be switched off by the server or be nil (dead, ejected);
-- then the object export knows our type and position too. If neither
-- tells, the add-on's own cockpit parameter DL_MODE_TXT (created by its
-- cockpit device, which exists only in the full-fidelity MiG-29) still
-- shows that this is our jet: enough for the cockpit-lamp lines, which
-- only need GetDevice(0). Checked every 10 s.
-----------------------------------------------------------------------
local ID = {t = nil, ff = false, self = nil, obj = nil, id = nil, cp_t = -1000, cp_ff = false}
local function cockpit_is_ours(t)
	if math.abs(t - ID.cp_t) < 10 then return ID.cp_ff end
	ID.cp_t = t
	ID.cp_ff = false
	if list_cockpit_params and try(GetDevice, 0) then
		local s = try(list_cockpit_params)
		ID.cp_ff = type(s) == "string" and s:find("F15SIT_READY", 1, true) ~= nil
	end
	return ID.cp_ff
end
local function ident(t)
	if ID.t == t then return ID.ff, ID.self, ID.obj, ID.id end
	ID.t = t
	local s = try(LoGetSelfData)
	ID.self = (type(s) == "table") and s or nil
	ID.obj, ID.id = nil, nil
	local name = ID.self and ID.self.Name
	if not (name and ID.self.Position) then
		ID.id = try(LoGetPlayerPlaneId)
		local o = ID.id and try(LoGetObjectById, ID.id)
		ID.obj = (type(o) == "table") and o or nil
		name = name or (ID.obj and ID.obj.Name)
	end
	if name then ID.ff = is_ff_mig29(name) else ID.ff = cockpit_is_ours(t) end
	return ID.ff, ID.self, ID.obj, ID.id
end

local function scan_due(t)
	if not (DL.big_scan and SCAN.big and SCAN.list and SCAN.t) then return true end
	if t < SCAN.t then return true end                       -- model time started again
	return (t - SCAN.t) >= scan_interval() - 0.5 * DL.period
end
local function radar_typ(base, own)
	if own then return (base == 5 and 15) or (base == 4 and 14) or (base == 6 and 16) or 11 end
	return 12
end
-- a packet between two scans: the last picture, aged by the time since the
-- scan; contacts on the own radar now get its position (and the radar type),
-- the ones it lost get their type without radar back.
local function reuse_picture(t, me)
	local dt = t - SCAN.t
	local radar = own_radar()
	local by_id = {}
	for _, r in ipairs(radar) do if r.id then by_id[r.id] = r end end
	local list, used = {}, {}
	local per = 1 / DL.spread_objects
	for _, it in ipairs(SCAN.list) do
		spread_point(per)
		if it.typ ~= 13 then
			local r = it.id and by_id[it.id]
			local n = nil
			if r then
				n = {typ = (it.typ >= 11) and it.typ or radar_typ(it.base_typ, it.own), x = r.x, z = r.z, y = r.y, vx = r.vx, vz = r.vz, age = 0}
				used[it.id] = true
			else
				local typ = (it.typ >= 11) and it.base_typ or it.typ
				if typ then n = {typ = typ, x = it.x, z = it.z, y = it.y, vx = it.vx, vz = it.vz, age = (it.age or 0) + dt} end
			end
			if n then
				n.nm, n.id, n.base_typ, n.own = it.nm, it.id, it.base_typ, it.own
				n.d = dist2d(n.x + (n.vx or 0) * n.age, n.z + (n.vz or 0) * n.age, me.x, me.z)
				list[#list + 1] = n
			end
		end
	end
	for _, r in ipairs(radar) do
		if not (r.id and used[r.id]) then
			list[#list + 1] = {typ = 13, x = r.x, z = r.z, y = r.y, vx = r.vx, vz = r.vz, age = 0, d = dist2d(r.x, r.z, me.x, me.z)}
		end
	end
	table.sort(list, by_distance)
	local status = SCAN.status or 0
	if status % 8 >= 4 then status = status - 4 end
	if #radar > 0 then status = status + 4 end
	local thr = {}
	for i, m in ipairs(SCAN.thr or {}) do m.d = dist2d(m.x, m.z, me.x, me.z); thr[i] = m end
	table.sort(thr, function(a, b) return a.d < b.d end)
	-- friendly aircraft (FLIGHT page): moved on by their speed
	local air = {}
	for i, a in ipairs(SCAN.air or {}) do
		spread_point(per)
		local v = vel[a.id] or {0, 0}
		air[i] = setmetatable({x = a.x + v[1] * dt, z = a.z + v[2] * dt}, {__index = a})
	end
	return list, status, thr, air
end

-- v1.7.5: build_picture in a coroutine of its own (that is what pcall did
-- before: an error gives ok = false). With DL.spread on, every yield of the
-- picture also gives the frame back (the packet job is a coroutine too).
local function run_spread(fn, ...)
	if not (DL.spread and JOB) then return pcall(fn, ...) end
	local co = coroutine.create(fn)
	SPREAD.on, SPREAD.cost = true, 0
	local res = {coroutine.resume(co, ...)}
	SPREAD.on = false
	while coroutine.status(co) ~= "dead" do
		coroutine.yield()
		SPREAD.on = true
		res = {coroutine.resume(co)}
		SPREAD.on = false
	end
	return unpack(res)
end

-- radar readings, logged while they change (Logs\f15sit_radar.log), so the
-- SIT page's coverage lines can be checked against the VSD
local radar_log_n, radar_last = 0, nil
local function radar_log(line, si)
	if not OPT.f15c_sit_logs or line == radar_last or radar_log_n >= 40 then return end
	radar_last = line
	radar_log_n = radar_log_n + 1
	pcall(function()
		local l = require("lfs")
		local f = io.open(l.writedir() .. "Logs/f15sit_radar.log", radar_log_n == 1 and "w" or "a")
		if not f then return end
		local sz = type(si.ScanZone) == "table" and si.ScanZone or {}
		local function kv(t)
			local s = {}
			for k, v in pairs(type(t) == "table" and t or {}) do
				if type(v) == "table" then
					local s2 = {}
					for k2, v2 in pairs(v) do s2[#s2 + 1] = tostring(k2) .. "=" .. tostring(v2) end
					s[#s + 1] = tostring(k) .. "={" .. table.concat(s2, " ") .. "}"
				else
					s[#s + 1] = tostring(k) .. "=" .. tostring(v)
				end
			end
			return table.concat(s, " ")
		end
		f:write(os.date("%H:%M:%S ") .. line .. "\n   scan: " .. kv(sz) .. "\n   scale: " .. kv(si.scale) ..
			"  TDC: " .. kv(si.TDC) .. "  radar_on=" .. tostring(si.radar_on) .. "\n")
		f:close()
	end)
end

local PAYLOAD_LOGGED = false   -- (the stores log is written once)
local function packet_job(t)
	local ff, self, obj, self_id = ident(t)
	if not ff then return end
	local u = get_udp()
	if not u then return end

	if not obj then
		self_id = try(LoGetPlayerPlaneId)
		local o = self_id and try(LoGetObjectById, self_id)
		obj = (type(o) == "table") and o or nil
	end
	-- own position: ownship export, else object export, else none (then
	-- only the cockpit lines are sent)
	local me = nil
	local px, py, pz = nil, nil, nil
	if self and type(self.Position) == "table" then px, py, pz = self.Position.x, self.Position.y, self.Position.z
	elseif obj then px, py, pz = pos_of(obj) end
	local coal = (obj and obj.CoalitionID) or (self and self.CoalitionID)
	if px and pz then
		me = {x = px, y = py or 0, z = pz, coal = coal, group = (obj and obj.GroupName) or (self and self.GroupName)}
	end

	local list, status, thr, air = {}, 0, {}, {}
	if me then
		local ok, l, s, th, a
		local need = pic_needed(t)
		if scan_due(t) and (need or not SCAN.list) then
			ok, l, s, th, a = run_spread(build_picture, t, self_id, me, not need)
			if ok and need then SCAN.t, SCAN.list, SCAN.status, SCAN.thr, SCAN.air = t, l, s, th, a end
		else
			ok, l, s, th, a = run_spread(reuse_picture, t, me)
		end
		if ok then
			list, status, thr, air = l, s, th, a
		else
			log_err(l)
			local ok2, l2, s2 = pcall(radar_picture, me)
			if ok2 then list, status = l2, s2 end
		end
	end

	-- lines in order of importance: own jet, route, stores, then the
	-- picture nearest first (put() drops whatever does not fit any more)
	local out = {size = 0}
	put(out, "F15SIT 1")
	put(out, "S," .. status)
	-- radar scan zone for the SIT page's coverage lines:
	--   R,on,scan centre azimuth (rad),scan width (rad),range scale (m),TDC x,TDC y
	do
		local ok, si = pcall(function() return LoGetSightingSystemInfo and LoGetSightingSystemInfo() end)
		if ok and type(si) == "table" then
			local sz = type(si.ScanZone) == "table" and si.ScanZone or {}
			local pos = type(sz.position) == "table" and sz.position or {}
			local size = type(sz.size) == "table" and sz.size or {}
			local sc = type(si.scale) == "table" and si.scale or {}
			local tdc = type(si.TDC) == "table" and si.TDC or {}
			-- (fields 7, 8: ECM on, VSD azimuth scale (rad, half width) - for the cursor)
			local line = string.format("R,%d,%.4f,%.4f,%.0f,%.4f,%.4f,%d,%.4f", si.radar_on and 1 or 0,
				tonumber(pos.azimuth) or 0, tonumber(size.azimuth) or 0, tonumber(sc.distance) or 0,
				tonumber(tdc.x) or 0, tonumber(tdc.y) or 0, si.ECM_on and 1 or 0, tonumber(sc.azimuth) or 0)
			put(out, line)
			radar_log(line, si)
		end
	end
	-- own data page: P,lat,lon,unit id,unit name,pilot name
	do
		local lla = (self and type(self.LatLongAlt) == "table" and self.LatLongAlt) or (obj and type(obj.LatLongAlt) == "table" and obj.LatLongAlt)
		if lla and tonumber(lla.Lat) then
			local unit = (self and self.UnitName) or (obj and obj.UnitName) or ""
			local pilot = try(LoGetPilotName) or ""
			put(out, string.format("P,%.6f,%.6f,%s,%s,%s", lla.Lat, lla.Long or 0, tostring(self_id or 0), clean(unit), clean(pilot)))
		end
	end
	-- BIT page: B,<failed system>,<failed system>... (LoGetMCPState flags that are true)
	do
		local ok, mcp = pcall(function() return LoGetMCPState and LoGetMCPState() end)
		if ok and type(mcp) == "table" then
			local bad = {}
			for k, v in pairs(mcp) do
				if v == true and tostring(k):find("Failure", 1, true) or (v == true and (k == "FuelTankDamage" or k == "StuckGear")) then
					bad[#bad + 1] = tostring(k)
				end
			end
			table.sort(bad)
			put(out, "B," .. table.concat(bad, ","))
		end
	end
	-- master mode for the SIT page (NAV, BVR, CAC, LNG, A2G ...)
	do
		local ok, nav = pcall(function() return LoGetNavigationInfo and LoGetNavigationInfo() end)
		if ok and type(nav) == "table" and type(nav.SystemMode) == "table" then
			put(out, "N," .. clean(nav.SystemMode.master or ""))
		end
	end
	if coal then put(out, "O," .. tostring(coal)) end
	-- the target the radar is locked on (shown selected on the DL page)
	do
		local ok, lk = pcall(function() return LoGetLockedTargetInformation and LoGetLockedTargetInformation() end)
		if ok and type(lk) == "table" then
			for _, tg in pairs(lk) do
				local x, y, z = pos_of(tg)
				if x then
					local vx, vz = 0, 0
					if type(tg.velocity) == "table" then vx, vz = tg.velocity.x or 0, tg.velocity.z or 0 end
					put(out, "L," .. fmt(x) .. "," .. fmt(z) .. "," .. fmt(y) .. "," .. fmt(vx) .. "," .. fmt(vz))
					break
				end
			end
		end
	end
	route_lines(out)
	-- stores (SMS page): Y,station,count,name   Z,gun shells,chaff,flares,current station
	do
		local ok, pl = pcall(function() return LoGetPayloadInfo and LoGetPayloadInfo() end)
		if ok and type(pl) == "table" then
			for i, st in ipairs(type(pl.Stations) == "table" and pl.Stations or {}) do
				st = type(st) == "table" and st or {}
				local nm = ""
				if (tonumber(st.count) or 0) > 0 then nm = store_name(st.weapon) end
				-- (F15SIT: + the store's CLSID, to find its pylon; logged once)
				local cl = tostring(st.CLSID or ""):gsub("[^%w%-{}_]", "")
				put(out, string.format("Y,%d,%d,%s,%s", i, tonumber(st.count) or 0, cl, nm))
				if OPT.f15c_sit_logs and not PAYLOAD_LOGGED then
					PAYLOAD_LOGGED = i >= #pl.Stations
					pcall(function()
						local l = require("lfs")
						local f = io.open(l.writedir() .. "Logs/f15sit_payload.log", i == 1 and "w" or "a")
						if not f then return end
						local s = {}
						for k, v in pairs(st) do
							if type(v) == "table" then
								local s2 = {}
								for k2, v2 in pairs(v) do s2[#s2 + 1] = tostring(k2) .. "=" .. tostring(v2) end
								s[#s + 1] = tostring(k) .. "={" .. table.concat(s2, " ") .. "}"
							else s[#s + 1] = tostring(k) .. "=" .. tostring(v) end
						end
						f:write(i .. ": " .. nm .. "  " .. table.concat(s, " ") .. "\n")
						f:close()
					end)
				end
			end
			local sn = try(LoGetSnares)
			sn = type(sn) == "table" and sn or {}
			put(out, string.format("Z,%d,%d,%d,%d", (pl.Cannon and pl.Cannon.shells) or 0, sn.chaff or 0, sn.flare or 0, pl.CurrentStation or 0))
		end
	end
	for i = 1, math.min(#thr, DL.max_threats) do
		local m = thr[i]
		if not put(out, "G," .. m.lbl .. "," .. fmt(m.x) .. "," .. fmt(m.z) .. "," .. fmt(m.ring)) then break end
	end
	for i = 1, math.min(#list, DL.max_contacts) do
		local c = list[i]
		if not put(out, "C," .. c.typ .. "," .. fmt(c.x) .. "," .. fmt(c.z) .. "," .. fmt(c.y) .. "," ..
			fmt(c.vx) .. "," .. fmt(c.vz) .. "," .. fmt(c.age) .. (c.nm and ("," .. clean(c.nm)) or "")) then break end
	end
	-- friendly aircraft by name, for the FLIGHT page (designating flight members)
	if me then
		local okf, fr = run_spread(function()
			local fr, per = {}, 1 / DL.spread_objects
			for _, a in ipairs(air or {}) do
				spread_point(per)
				if a.coal == me.coal and a.id ~= self_id then
					local d = dist2d(a.x, a.z, me.x, me.z)
					if d <= DL.friendly_range then fr[#fr + 1] = {a = a, d = d} end
				end
			end
			return fr
		end)
		if not okf then log_err(fr); fr = {} end
		table.sort(fr, function(p, q)
			if (p.a.human and true or false) ~= (q.a.human and true or false) then return p.a.human and true or false end
			return p.d < q.d
		end)
		for i = 1, math.min(#fr, DL.max_flight_list or 24) do
			local a = fr[i].a
			local v = vel[a.id] or {0, 0}
			-- (F15SIT: field 12 = own flight member 1/0, before type and unit name)
			if not put(out, string.format("F,%s,%s,%s,%s,%.3f,%s,%s,%d,%d,%d,%d,%s,%s", tostring(a.id), fmt(a.x), fmt(a.z), fmt(a.y),
				a.hdg or 0, fmt(v[1]), fmt(v[2]), a.human and 1 or 0, a.radar and 1 or 0, a.jam and 1 or 0,
				(me.group and a.group == me.group) and 1 or 0, clean(a.name), clean(a.unit))) then break end
		end
	end
	out[#out + 1] = "E"
	u:send(table.concat(out, "\n"))
end

local function tick(t)
	-- a packet in the making: its next slice
	if JOB then
		SPREAD.frames = SPREAD.frames + 1
		SPREAD.t0 = clock()
		local ok, err = coroutine.resume(JOB)
		SPREAD.on = false
		if not ok or coroutine.status(JOB) == "dead" then JOB = nil end
		if not ok then error(err, 0) end
		return
	end
	-- (t < last_send: model time started again, e.g. a new mission without LuaExportStop)
	if t - last_send < DL.period and t >= last_send then return end
	last_send = t
	if not DL.spread then return packet_job(t) end
	JOB = coroutine.create(packet_job)
	SPREAD.frames, SPREAD.t0 = 0, clock()
	local ok, err = coroutine.resume(JOB, t)
	SPREAD.on = false
	if not ok or coroutine.status(JOB) == "dead" then JOB = nil end
	if not ok then error(err, 0) end
end

-- debug log: Saved Games\DCS\Logs\mig29dl_export.log
local dbg_n = 0
local function dbg(msg)
	if dbg_n > 50 then return end
	dbg_n = dbg_n + 1
	pcall(function()
		local l = require("lfs")
		local f = io.open(l.writedir() .. "Logs/f15sit_export.log", (dbg_n == 1) and "w" or "a")
		if f then f:write(os.date("%H:%M:%S ") .. tostring(msg) .. "\n"); f:close() end
	end)
end
SCAN.log = dbg              -- (v1.7.5: busy-mission switch in the export log)
-- RWR, in its own small packet "F15SITV": the emitters the F-15C's RWR
-- hears (LoGetTWSInfo), 10 times a second, sent when the list changes and
-- twice a second to keep it alive.
--   V,azimuth (rad, relative, + = right),power (0-1),state (1 search,
--     2 lock, 3 missile guidance),level1,type name
local last_rwr, last_rwr_send, last_spo = -1000, -1000, nil
local SIG = {scan = 1, lock = 2, missile_radio_guided = 3, track_while_scan = 2}
local function spo_line(t)
	local tws = try(LoGetTWSInfo)
	if type(tws) ~= "table" then return nil end
	local out = {}
	for _, e in pairs(type(tws.Emitters) == "table" and tws.Emitters or {}) do
		local ty = type(e.Type) == "table" and e.Type or {}
		local nm = ""
		if LoGetNameByType then nm = try(LoGetNameByType, ty.level1 or 0, ty.level2 or 0, ty.level3 or 0, ty.level4 or 0) or "" end
		out[#out + 1] = string.format("V,%.3f,%.2f,%d,%d,%s", tonumber(e.Azimuth) or 0, tonumber(e.Power) or 0,
			SIG[e.SignalType] or 1, ty.level1 or 0, clean(nm))
		if #out >= 16 then break end
	end
	return table.concat(out, "\n")
end
-- countermeasure programs and jettison, asked for by the SIT
-- device (it sends to 127.0.0.1:42890):
--   F15SITX,chaff,flares,interval (s),cycles   run a dispense program
--   F15SITJ,weapons | tanks                    jettison
-- The commands go to the jet with LoSetCommand, as a key press would. Their
-- numbers come from Logs\f15sit_icmd.lua, written by the add-on's block in
-- the F-15C's controls file (DCS knows them there by name).
local CM = {rx = nil, rx_fail = nil, cmd = nil, cmd_t = -1000, queue = {}, port = 42890}
local HOLD = {q = false, q_t = -1000}       -- TDC slew held at ~0 while the SIT page has the cursor
local function cm_cmds(t)
	if CM.cmd or t - CM.cmd_t < 5 and t >= CM.cmd_t then return CM.cmd end
	CM.cmd_t = t
	pcall(function()
		local l = require("lfs")
		local f = loadfile(l.writedir() .. "Logs/f15sit_icmd.lua")
		local ok, c = pcall(f or error)
		if ok and type(c) == "table" then CM.cmd = c; dbg("command numbers: chaff " .. tostring(c.chaff) .. ", flare " .. tostring(c.flare) .. ", jettison " .. tostring(c.jett) .. ", tanks " .. tostring(c.tanks)) end
	end)
	return CM.cmd
end
local function cm_rx()
	if CM.rx then return CM.rx end
	if CM.rx_fail then return nil end
	local socket = package.loaded["socket"]
	if type(socket) ~= "table" then return nil end
	local u = try(socket.udp)
	if not u then CM.rx_fail = true; return nil end
	u:settimeout(0)
	if not u:setsockname("127.0.0.1", CM.port) then CM.rx_fail = true; return nil end
	CM.rx = u
	return u
end
local function cmds_tick(t)
	local u = cm_rx()
	if u then
		for _ = 1, 4 do
			local m = u:receive()
			if not m then break end
			local c = cm_cmds(t)
			if m:sub(1, 7) == "F15SITX" and c then
				local ch, fl, iv, cy = m:match("^F15SITX,([%d%.]+),([%d%.]+),([%d%.]+),([%d%.]+)")
				ch, fl, iv, cy = tonumber(ch) or 0, tonumber(fl) or 0, tonumber(iv) or 1, tonumber(cy) or 1
				CM.queue = {}
				for k = 0, math.min(cy, 20) - 1 do
					local t0 = t + k * iv
					for j = 0, math.min(ch, 10) - 1 do CM.queue[#CM.queue + 1] = {t = t0 + j * 0.06, cmd = c.chaff} end
					for j = 0, math.min(fl, 10) - 1 do CM.queue[#CM.queue + 1] = {t = t0 + 0.03 + j * 0.06, cmd = c.flare} end
				end
				table.sort(CM.queue, function(a, b) return a.t < b.t end)
				dbg(string.format("program: %d chaff, %d flares, every %.2f s, %d times", ch, fl, iv, cy))
			elseif m:sub(1, 7) == "F15SITQ" then
				-- the device: SIT has the cursor (1) -> keep the TDC slew at ~0
				-- every frame; (0,h,v) -> stop, and give the radar the stick back
				local on, h, v = m:match("^F15SITQ,(%d),?([^,]*),?([^,]*)")
				if on == "1" then
					if not HOLD.q then dbg("TDC slew held at 0 every frame") end
					HOLD.q, HOLD.q_t = true, t
				else
					HOLD.q = false
					if c and LoSetCommand and c.sel_h then
						LoSetCommand(c.sel_h, tonumber(h) or 0); LoSetCommand(c.sel_v, tonumber(v) or 0)
					end
				end
			elseif m:sub(1, 7) == "F15SITG" then
				-- the device: datalink picture on screen (1) or not (0)
				local on = m:sub(9, 9) ~= "0"
				if on ~= PIC.need and PIC.n < 10 then
					PIC.n = PIC.n + 1
					dbg(on and "SIT page on screen: world scan on" or "SIT page off screen: world scan paused")
				end
				PIC.need, PIC.t = on, t
			elseif m:sub(1, 7) == "F15SITU" then
				-- the device: press this key once (undoes a radar zoom key that
				-- went to the SIT range instead)
				local cmd = tonumber(m:match("^F15SITU,(%d+)"))
				if cmd and LoSetCommand then LoSetCommand(cmd) end
			elseif m:sub(1, 7) == "F15SITZ" then
				-- the device: set this axis command to 0 (cancels the TDC slew
				-- while SIT has the cursor)
				local cmd = tonumber(m:match("^F15SITZ,(%d+)"))
				if cmd and LoSetCommand then
					LoSetCommand(cmd, 0)
					HOLD.nz = (HOLD.nz or 0) + 1
					if HOLD.nz <= 3 then dbg("TDC slew cancelled: " .. cmd) end
				end
			elseif m:sub(1, 7) == "F15SITJ" and c then
				local what = m:match("^F15SITJ,(%a+)")
				local cmd = (what == "tanks") and c.tanks or c.jett
				if cmd and LoSetCommand then LoSetCommand(cmd); dbg("jettison: " .. tostring(what)) end
			end
		end
	end
	while CM.queue[1] and CM.queue[1].t <= t do
		local q = table.remove(CM.queue, 1)
		if q.cmd and LoSetCommand then LoSetCommand(q.cmd) end
	end
	-- SIT has the cursor: TDC slew to a marker value (1e-6, nothing for the
	-- radar) every frame. The device knows the marker and ignores it.
	if HOLD.q then
		if t - HOLD.q_t > 2 or t < HOLD.q_t then HOLD.q = false; dbg("TDC slew hold timed out")
		else
			local c = cm_cmds(t)
			if c and c.sel_h and LoSetCommand then LoSetCommand(c.sel_h, 1e-6); LoSetCommand(c.sel_v, 1e-6) end
		end
	end
end

-- the radar cursor in its own small packet "F15SITC", 20 times a
-- second while it moves (and twice a second anyway): the SIT page's
-- capture window and EXP follow the VSD cursor smoothly.
--   F15SITC,radar on,TDC x,TDC y,range scale (m),azimuth scale (rad),scan centre,scan width,chaff,flares
local last_cur, last_cur_send, last_cur_line = -1000, -1000, nil
local function cursor_tick(t)
	if t - last_cur < 0.05 and t >= last_cur then return end
	last_cur = t
	local si = try(LoGetSightingSystemInfo)
	if type(si) ~= "table" then return end
	local sz = type(si.ScanZone) == "table" and si.ScanZone or {}
	local pos = type(sz.position) == "table" and sz.position or {}
	local size = type(sz.size) == "table" and sz.size or {}
	local sc = type(si.scale) == "table" and si.scale or {}
	local tdc = type(si.TDC) == "table" and si.TDC or {}
	local sn = try(LoGetSnares)
	sn = type(sn) == "table" and sn or {}
	local line = string.format("F15SITC,%d,%.4f,%.4f,%.0f,%.4f,%.4f,%.4f,%d,%d", si.radar_on and 1 or 0,
		tonumber(tdc.x) or 0, tonumber(tdc.y) or 0, tonumber(sc.distance) or 0, tonumber(sc.azimuth) or 0,
		tonumber(pos.azimuth) or 0, tonumber(size.azimuth) or 0, tonumber(sn.chaff) or 0, tonumber(sn.flare) or 0)
	if line ~= last_cur_line or t - last_cur_send >= 0.5 then
		local u = get_udp()
		if not u then return end
		last_cur_line, last_cur_send = line, t
		u:send(line)
	end
end
-----------------------------------------------------------------------
-- own missiles in flight (F15SITW, 4 per second while any fly):
-- a launch = an air-to-air missile count going down on a station. Its
-- target = what the radar is locked on at that moment. The missile itself
-- is the new "ballistic" world object that appears next to us (where the
-- server allows the world objects); then the time to impact comes from its
-- real closing speed, else from an average missile speed.
--   F15SITW|typ,has missile,mx,mz,has target,tx,tz,tti|...
-----------------------------------------------------------------------
local MSL = {list = {}, counts = nil, known = {}, t = -1000, sent_empty = true}
local MSL_V = {A = 900, S = 750, M = 650}       -- average speeds (m/s) for the estimate
local function msl_letter(name)
	name = tostring(name or ""):upper()
	if name:find("120", 1, true) then return "A" end
	if name:find("AIM%-7") or name:find("AIM7") then return "S" end
	if name:find("AIM%-9") or name:find("AIM9") then return "M" end
	return "W"
end
local function msl_counts()
	local pl = try(LoGetPayloadInfo)
	if type(pl) ~= "table" or type(pl.Stations) ~= "table" then return nil end
	local c = {}
	for i, st in ipairs(pl.Stations) do
		local w = type(st) == "table" and st.weapon
		if type(w) == "table" and w.level1 == 4 and w.level2 == 4 and w.level3 == 7 then
			c[i] = {n = tonumber(st.count) or 0, name = store_name(w)}
		end
	end
	return c
end
local function msl_lock()
	local lk = try(LoGetLockedTargetInformation)
	if type(lk) ~= "table" then return nil end
	for _, tg in pairs(lk) do
		local x, _, z = pos_of(tg)
		if x then
			local v = type(tg.velocity) == "table" and tg.velocity or {}
			return {x = x, z = z, vx = v.x or 0, vz = v.z or 0}
		end
	end
end
local function msl_tick(t)
	if t - MSL.t < 0.25 and t >= MSL.t then return end
	local dt = t - MSL.t
	MSL.t = t
	local me = try(LoGetSelfData)
	local ox, _, oz = nil, nil, nil
	if type(me) == "table" then ox, _, oz = pos_of(me) end
	if not ox then return end
	-- launches (count drops on air-to-air missile stations)
	local c = msl_counts()
	local fired = {}
	if c and MSL.counts then
		for i, now_c in pairs(c) do
			local was = MSL.counts[i]
			if was and now_c.n < was.n then
				for _ = 1, was.n - now_c.n do fired[#fired + 1] = msl_letter(was.name ~= "" and was.name or now_c.name) end
			end
		end
	end
	if c then MSL.counts = c end
	if #MSL.list == 0 and #fired == 0 then
		if not MSL.sent_empty then local u = get_udp(); if u then u:send("F15SITW") end; MSL.sent_empty = true end
		MSL.known, MSL.scan_t = {}, nil
		return
	end
	-- the radar lock, once per tick: the target of a new missile, and where
	-- the targets of the missiles in flight are now
	local lk = msl_lock()
	for _, typ in ipairs(fired) do
		local tg = lk and {x = lk.x, z = lk.z, vx = lk.vx, vz = lk.vz, t = t} or nil
		local r0 = tg and math.sqrt((tg.x - ox) ^ 2 + (tg.z - oz) ^ 2) or nil
		table.insert(MSL.list, {t0 = t, typ = typ, tg = tg, mx = ox, mz = oz,
			tti = r0 and r0 / (MSL_V[typ] or 800) or nil, est = true})
		dbg(string.format("missile away: %s, target %s", typ, r0 and string.format("%.0f m", r0) or "none"))
	end
	-- the missiles as world objects (where the server allows them). A new
	-- "ballistic" object close to us in a missile's first 3 s is that missile;
	-- after that it is followed by its id alone (LoGetObjectById), so the
	-- scan of all weapons in the air runs only for the first seconds of a
	-- flight. If the id lookup gives no weapons (MSL.byid false), the scan
	-- runs for the whole flight, as before.
	local need_scan = false
	for _, m in ipairs(MSL.list) do
		m.px, m.pz, m.asked = nil, nil, false
		if OPT.f15c_sit_datalink then
			if not m.id then
				if t - m.t0 < 3 then need_scan = true end
			elseif MSL.byid == false then
				need_scan = true
			else
				local o = try(LoGetObjectById, m.id)
				local x, y_, z = nil, nil, nil
				if type(o) == "table" then x, y_, z = pos_of(o) end
				if x then m.px, m.pz, MSL.byid = x, z, true
				elseif MSL.byid == nil then need_scan, m.asked = true, true end     -- gone, or no weapons by id: the scan tells
			end
		end
	end
	local balls = need_scan and try(LoGetWorldObjects, "ballistic") or nil
	if type(balls) == "table" then
		-- (after a pause every object counts as new, as at a first launch)
		local was = (MSL.scan_t and t - MSL.scan_t <= 0.6 and t >= MSL.scan_t) and MSL.known or {}
		local taken = {}
		for _, m in ipairs(MSL.list) do if m.id then taken[m.id] = true end end
		local known = {}
		for id, o in pairs(balls) do
			known[id] = true
			if not was[id] and not taken[id] then
				local x, y_, z = pos_of(o)
				if x and (x - ox) ^ 2 + (z - oz) ^ 2 < 600 ^ 2 then
					for _, m in ipairs(MSL.list) do
						if not m.id and t - m.t0 < 3 then m.id = id; taken[id] = true; break end
					end
				end
			end
		end
		MSL.known, MSL.scan_t = known, t
		for _, m in ipairs(MSL.list) do
			if m.id and not m.px then
				local o = balls[m.id]
				local x, y_, z = nil, nil, nil
				if o then x, y_, z = pos_of(o) end
				if x then
					m.px, m.pz = x, z
					if m.asked and MSL.byid == nil then MSL.byid = false; dbg("missiles: no weapons by id, followed by the scan") end
				end
			end
		end
	end
	local out, keep = {"F15SITW"}, {}
	for _, m in ipairs(MSL.list) do
		local alive = t - m.t0 < 120
		-- target: the lock if it is still near where we expect it, else dead reckoning
		local tx, tz
		if m.tg then
			tx = m.tg.x + m.tg.vx * (t - m.tg.t)
			tz = m.tg.z + m.tg.vz * (t - m.tg.t)
			if lk and (lk.x - tx) ^ 2 + (lk.z - tz) ^ 2 < 3000 ^ 2 then
				m.tg = {x = lk.x, z = lk.z, vx = lk.vx, vz = lk.vz, t = t}; tx, tz = lk.x, lk.z
			end
		end
		if m.id then
			local x, z = m.px, m.pz
			if x then
				m.lost = nil
				if tx then
					local d = math.sqrt((x - tx) ^ 2 + (z - tz) ^ 2)
					if m.pd and dt > 0 then
						local cl = (m.pd - d) / dt
						if cl > 100 then
							local tti = d / cl
							m.tti = m.tti and (m.tti * 0.6 + tti * 0.4) or tti
							m.est = false
						end
					end
					m.pd = d
				end
				m.mx, m.mz = x, z
			else
				m.lost = m.lost or t
				if t - m.lost > 1.5 then alive = false end        -- impact / gone
			end
		end
		if m.est and m.tti then m.tti = math.max(0, m.tti - dt) end
		if m.tti and m.tti <= 0 and m.est and t - m.t0 > 2 then
			if t - (m.zero or t) > 3 then alive = false end
			m.zero = m.zero or t
		end
		if alive then
			keep[#keep + 1] = m
			out[#out + 1] = string.format("%s,%d,%.0f,%.0f,%d,%.0f,%.0f,%.1f", m.typ, m.id and not m.lost and 1 or 0, m.mx or 0, m.mz or 0,
				tx and 1 or 0, tx or 0, tz or 0, m.tti or -1)
		end
	end
	MSL.list = keep
	local u = get_udp()
	if u then u:send(table.concat(out, "|")); MSL.sent_empty = #keep == 0 end
end

local function rwr_tick(t)
	if not OPT.f15c_sit_rwr then return end
	if t - last_rwr < 0.1 and t >= last_rwr then return end
	last_rwr = t
	if not ident(t) then return end
	local line = spo_line(t)
	if line and (line ~= last_spo or t - last_rwr_send >= 0.5) then
		local u = get_udp()
		if not u then return end
		last_spo, last_rwr_send = line, t
		u:send("F15SITV\n" .. line)
	end
end

-----------------------------------------------------------------------
-- timing log (Options > Special > F-15C SIT: timing and debug logs, off
-- by default): every 30 s one block in Saved Games\DCS\Logs\
-- f15sit_export_perf.log: calls, average and worst time, calls of 1 ms or
-- more, Lua memory created per call. os.clock steps in 1 ms on Windows:
-- single short calls read 0 or 1 ms, the average over many calls is still
-- right. Every step in a pcall: it can never stop the script.
-----------------------------------------------------------------------
local PERF = {on = false, file = "f15sit_export_perf.log", period = 30, max_blocks = 480}
local function perf_read_setting()
	PERF.on = OPT.f15c_sit_logs == true
	if PERF.on and not PERF.st then
		PERF.st = {b = {}, order = {}, p0 = os.clock(), frames = 0, blocks = 0, opened = false}
	end
end
local function perf_kb()
	local ok, v = pcall(collectgarbage, "count")
	return (ok and type(v) == "number") and v or nil
end
local function perf_write(lines)
	pcall(function()
		local l = require("lfs")
		local path = l.writedir() .. "Logs/" .. PERF.file
		local st = PERF.st
		local mode = "a"
		if not st.opened then
			st.opened = true
			local old = path:gsub("%.log$", ".old.log")
			pcall(os.remove, old); pcall(os.rename, path, old)
			mode = "w"
		end
		local fh = io.open(path, mode)
		if fh then fh:write(table.concat(lines, "\n") .. "\n"); fh:close() end
	end)
end
-- start of a measured step: clock and memory now
local function perf_begin() return os.clock(), perf_kb() end
-- end of step k (begun at c0 / m0); returns the clock / memory now, so
-- the next step can start from there
local function perf_add(k, c0, m0)
	local c1, m1 = os.clock(), perf_kb()
	pcall(function()
		local st = PERF.st
		local b = st.b[k]
		if not b then b = {n = 0, sum = 0, max = 0, n1 = 0, n4 = 0, n16 = 0, asum = 0, an = 0}; st.b[k] = b; st.order[#st.order + 1] = k end
		local d = c1 - c0
		b.n = b.n + 1; b.sum = b.sum + d
		if d > b.max then b.max = d end
		if d >= 0.001 then b.n1 = b.n1 + 1 end
		if d >= 0.004 then b.n4 = b.n4 + 1 end
		if d >= 0.016 then b.n16 = b.n16 + 1 end
		if m0 and m1 and m1 >= m0 then b.asum = b.asum + (m1 - m0); b.an = b.an + 1 end
	end)
	return c1, m1
end
-- once per frame: writes the block when the period is over
local function perf_frame()
	pcall(function()
		local st = PERF.st
		if st.blocks >= PERF.max_blocks then return end
		st.frames = st.frames + 1
		local now = os.clock()
		local dt = now - st.p0
		if dt < PERF.period then return end
		st.blocks = st.blocks + 1
		local L = {}
		if st.blocks == 1 then
			L[#L + 1] = "F-15C SIT export timing log (" .. PERF.file .. ")  " .. os.date("%Y-%m-%d %H:%M:%S")
			L[#L + 1] = "  one block every " .. PERF.period .. " s; avg is per call; 'of the time' = share of one CPU core"
		end
		local mem = perf_kb()
		L[#L + 1] = string.format("%s  %.0f s  %d frames (%.1f/s)  Lua memory %s KB", os.date("%H:%M:%S"), dt, st.frames, st.frames / dt,
			mem and string.format("%.0f", mem) or "?")
		for _, k in ipairs(st.order) do
			local b = st.b[k]
			if b.n > 0 then
				L[#L + 1] = string.format("  %-9s %6d calls  avg %.3f ms  worst %.3f ms  >=1ms %d  >=4ms %d  >=16ms %d  alloc %s KB/call  %.2f%% of the time",
					k, b.n, 1000 * b.sum / b.n, 1000 * b.max, b.n1, b.n4, b.n16,
					(b.an > 0) and string.format("%.2f", b.asum / b.an) or "?", 100 * b.sum / dt)
			end
			st.b[k] = {n = 0, sum = 0, max = 0, n1 = 0, n4 = 0, n16 = 0, asum = 0, an = 0}
		end
		if st.blocks == PERF.max_blocks then L[#L + 1] = "(log full: nothing more is written until DCS restarts)" end
		perf_write(L)
		st.p0, st.frames = now, 0
	end)
end
perf_read_setting()

-----------------------------------------------------------------------
-- chain into the export callbacks without disturbing other scripts.
--  * our frame function runs inside pcall, then the previous one is called
--    outside it: an error of ours can never keep the next tool from
--    running, and the next tool's errors reach DCS as they would without us
--  * we wrap LuaExportAfterNextFrame when loaded and once more right after
--    the other tools' LuaExportStart has run: a tool may replace the
--    function (and LuaExportActivityNextEvent) inside its start, and then
--    we must be in the chain anyway. Later we wrap it again only if our
--    function did not run at all while the simulation went on (a tool
--    replaced the function without calling the previous one). Wrapping
--    again every time we are not the head would, with a tool using the
--    same re-attach idea, grow the chain every second.
--    The start re-attach is skipped when our wrapper is still reachable
--    from the head (a tool wrapped us: it keeps the previous function as an
--    upvalue): wrapping again would put us twice into the chain, and a tool
--    that re-attaches whenever it is not the head would then run twice.
--    When that cannot be told (no debug library), we wrap anyway: a second
--    call of ours in the same frame returns at once.
--  * after LuaExportStop nothing of ours runs (until the next start)
--  * a second copy of this file loaded into the same export state makes
--    the first one inactive (F15SIT_GEN), so we never run twice
-----------------------------------------------------------------------
F15SIT_GEN = (F15SIT_GEN or 0) + 1
local RUN = {gen = F15SIT_GEN, stopped = false, ran = false, before = false, chk_t = nil, last_t = nil, hook = nil, n_att = 0}
-- are we in the F-15C? Looked at once a second: in any other aircraft the
-- cursor, hold and missile parts do nothing (the once-a-second packet asks
-- for itself, and stops at once outside the F-15C)
local OURS = {t = -1000, v = false}
local function ours(t)
	if t - OURS.t >= 1 or t < OURS.t then
		OURS.t = t
		local ok, ff = pcall(ident, t)
		OURS.v = (ok and ff) and true or false
	end
	return OURS.v
end
local function our_after()
	if RUN.stopped or F15SIT_GEN ~= RUN.gen then return end
	if not OPT.f15c_sit_enabled then return end      -- Options > Special: add-on off
	RUN.ran = true
	local t = LoGetModelTime and LoGetModelTime() or 0
	-- called twice in one frame (our wrapper twice in someone's chain): once is enough
	if t == RUN.last_t then return end
	RUN.last_t = t
	local pc, pm
	if PERF.on then pc, pm = perf_begin() end
	local ok, err = pcall(tick, t)
	if not ok then log_err(err); dbg("error: " .. tostring(err)) end
	if PERF.on then pc, pm = perf_add(SCHED.scan and "dl scan" or "datalink", pc, pm) end
	SCHED.scan = false
	local ok2, err2 = pcall(rwr_tick, t)
	if not ok2 then dbg("rwr error: " .. tostring(err2)) end
	-- (the device's requests are always read: a release of the TDC hold must
	-- get through whatever happens)
	local ok4, err4 = pcall(cmds_tick, t)
	if not ok4 then dbg("cmds error: " .. tostring(err4)) end
	local mine = ours(t)
	if mine then
		local ok3, err3 = pcall(cursor_tick, t)
		if not ok3 then dbg("cursor error: " .. tostring(err3)) end
	end
	if mine then
		local ok6, err6 = pcall(msl_tick, t)
		if not ok6 then dbg("missile error: " .. tostring(err6)) end
	end
	if PERF.on then perf_add("others", pc, pm); perf_frame() end
end
local function attach()
	local cur = LuaExportAfterNextFrame
	if cur and cur == RUN.hook then return end
	local function hook(...)
		pcall(our_after)
		if cur then return cur(...) end
	end
	RUN.hook = hook
	LuaExportAfterNextFrame = hook
end
-- before-frame mark: tells check_attached that frames are running (once,
-- when loaded; nothing else is done in it)
local function attach_before()
	local prev = LuaExportBeforeNextFrame
	LuaExportBeforeNextFrame = function(...)
		RUN.before = true
		if prev then return prev(...) end
	end
end
-- is our wrapper still reachable from f? Walks the upvalues of the chained
-- functions, read only: from a function all its upvalues, from a table its
-- functions, and from a small table (64 entries at most, met right below a
-- function) also the tables in it. Data tables (contacts, caches) are not
-- walked: in a busy mission they made the walk give up ("can not tell"),
-- and every check wrapped the frame function once more (seen: ~30 wrappers
-- per flight on a busy server). At most 5000 nodes. nil = can not tell
-- (no debug library, or too big to look through)
local function in_chain(f, target)
	if not (debug and debug.getupvalue) then return nil end
	local stack, depth, seen, n = {f}, {0}, {}, 0
	while #stack > 0 do
		local v = table.remove(stack)
		local d = table.remove(depth)
		if v == target then return true end
		if not seen[v] then
			seen[v] = true
			n = n + 1
			if n > 5000 then return nil end
			if type(v) == "function" then
				for i = 1, 255 do
					local name, u = debug.getupvalue(v, i)
					if name == nil then break end
					if name == "_ENV" then                 -- (Lua 5.2+: the globals; not followed)
					elseif type(u) == "function" then stack[#stack + 1] = u; depth[#depth + 1] = 0
					elseif type(u) == "table" then stack[#stack + 1] = u; depth[#depth + 1] = 1 end
				end
			else
				local small = d < 2
				if small then
					local c = 0
					for _ in pairs(v) do c = c + 1; if c > 64 then small = false; break end end
				end
				for _, u in pairs(v) do
					if type(u) == "function" then stack[#stack + 1] = u; depth[#depth + 1] = 0
					elseif small and type(u) == "table" then stack[#stack + 1] = u; depth[#depth + 1] = d + 1 end
				end
			end
		end
	end
	return false
end
-- called from LuaExportActivityNextEvent (about once a second)
local function check_attached()
	if RUN.stopped or F15SIT_GEN ~= RUN.gen then return end
	local now = LoGetModelTime and LoGetModelTime() or 0
	if RUN.chk_t == nil or now < RUN.chk_t then RUN.chk_t, RUN.ran = now, false; return end
	if now - RUN.chk_t < 0.5 then return end      -- no frames since the last look
	if not RUN.ran then
		-- only when our wrapper is really gone. While DCS loads (and on the
		-- slot screen) model time runs with no frames: no reason to wrap
		-- again. DCS's export has no debug library, so the walk usually can
		-- not tell (nil); then only frames that ran without us count: our
		-- before-frame mark (RUN.before) was set, our after-frame function
		-- did not run. (Before, every check during loading wrapped again:
		-- ~30 wrappers a flight, each one called every frame.) At most 20
		-- re-attaches a mission.
		local cur = LuaExportAfterNextFrame
		local inc = (cur == RUN.hook) or (RUN.hook ~= nil and in_chain(cur, RUN.hook))
		if inc ~= true and (inc == false or RUN.before) and RUN.n_att < 20 then
			attach()
			RUN.n_att = RUN.n_att + 1
			dbg("re-attached to LuaExportAfterNextFrame (someone replaced it)")
		end
	end
	RUN.chk_t, RUN.ran, RUN.before = now, false, false
end
-- all per-mission state back to the start values
local function reset_state()
	JOB = nil; SPREAD.on, SPREAD.cost, SPREAD.frames = false, 0, 0
	SCAN.t, SCAN.list, SCAN.status, SCAN.thr, SCAN.air, SCAN.ema, SCAN.big = nil, nil, nil, nil, nil, nil, false
	SCAN.every, SCAN.n_log = nil, 0
	PIC.need, PIC.t = true, nil
	last_send, last_awacs, last_prune = -1000, -1000, -1000
	last_rwr, last_rwr_send, last_spo = -1000, -1000, nil
	last_log, log_count = -1000, 0
	name_cache = {}
	clean_cache, clean_n = {}, 0
	prev_pos, vel, awacs_seen, f2f_seen, threat_mem, thr_try = {}, {}, {}, {}, {}, {}
	awacs_up = false
	SCHED.n, SCHED.thr_ofs = -1, 0
	alt_ok = true
	ID.t, ID.ff, ID.self, ID.obj, ID.id, ID.cp_t, ID.cp_ff = nil, false, nil, nil, nil, -1000, false
	RUN.chk_t, RUN.ran, RUN.before, RUN.last_t, RUN.n_att = nil, false, false, nil, 0
	OURS.t, OURS.v = -1000, false
	MSL.list, MSL.counts, MSL.known, MSL.t, MSL.sent_empty, MSL.byid, MSL.scan_t = {}, nil, {}, -1000, true, nil, nil
	last_cur, last_cur_send, last_cur_line = -1000, -1000, nil
	sock.fail_t = nil
	if udp then pcall(function() udp:close() end); udp = nil end
end
attach()
attach_before()
dbg("export script loaded")
do
	local function our_start()
		if F15SIT_GEN ~= RUN.gen then return end
		RUN.stopped = false
		reset_state()
		read_options()
		perf_read_setting()
		if PERF.on then dbg("perf_log on: timing in Logs/f15sit_export_perf.log") end
		dbg("LuaExportStart: options on=" .. tostring(OPT.f15c_sit_enabled) .. " datalink=" .. tostring(OPT.f15c_sit_datalink) .. " rwr=" .. tostring(OPT.f15c_sit_rwr))
	end
	local function our_stop()
		if F15SIT_GEN ~= RUN.gen then return end
		RUN.stopped = true
		reset_state()
		dbg("LuaExportStop")
	end
	local prev_start = LuaExportStart
	-- the other tools' start is called outside our pcall (its errors reach
	-- DCS as they would without us); afterwards we make sure we are in the
	-- chain, whatever it did to LuaExportAfterNextFrame
	local function start_attach()
		if F15SIT_GEN ~= RUN.gen or RUN.stopped then return end
		local cur = LuaExportAfterNextFrame
		-- (only when surely gone; "can not tell" is left to check_attached,
		-- which sees it within a second of flying if it is)
		if cur == RUN.hook or not RUN.hook or in_chain(cur, RUN.hook) ~= false then return end
		attach()
		dbg("LuaExportStart: re-attached (LuaExportAfterNextFrame was replaced)")
	end
	LuaExportStart = function(...)
		pcall(our_start)
		if prev_start then prev_start(...) end
		pcall(start_attach)
	end
	local prev_act = LuaExportActivityNextEvent
	LuaExportActivityNextEvent = function(t, ...)
		pcall(check_attached)
		if prev_act then return prev_act(t, ...) end
		return t + 1.0
	end
	local prev_stop = LuaExportStop
	LuaExportStop = function(...)
		pcall(our_stop)
		if prev_stop then return prev_stop(...) end
	end
end
