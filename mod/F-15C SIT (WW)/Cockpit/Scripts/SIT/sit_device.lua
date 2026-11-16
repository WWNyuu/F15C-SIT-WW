-----------------------------------------------------------------------
-- F-15C SIT (WW): MPCD device (v0.6.0): SIT, MENU and its pages
-- (DTM, ARMT, CBT JETT, WPN LOAD, BIT, TIME/DATE, OWN DATA, FLIGHT DATA, WPN)
--
-- Own aircraft from get_base_data(); the picture (radar contacts,
-- datalink friendlies / hostiles, route, locked target, ground threats)
-- from Scripts\F15SIT_Export.lua over UDP 127.0.0.1:42889 - the same
-- picture rules as the MiG-29 add-on. The bullseye comes from
-- Scripts\Hooks\F15SIT_hook.lua (packet "F15SITB"), same port.
-- Everything goes to the page (SIT/indicator/sit_page.lua) as cockpit
-- parameters F15SIT_*. Buttons: see BUTTONS below.
-- Log: Saved Games\DCS\Logs\f15sit_device.log
-----------------------------------------------------------------------
dofile(LockOn_Options.script_path .. "devices.lua")
dofile(LockOn_Options.script_path .. "command_defs.lua")
dofile(LockOn_Options.script_path .. "SIT/sit_config.lua")
dofile(LockOn_Options.script_path .. "HMD/hmd_config.lua")
pcall(dofile, LockOn_Options.script_path .. "HMD/hmd_options.lua")   -- (HMD.ENABLED: Options > Special)
dofile(LockOn_Options.script_path .. "SIT/sit_dtm.lua")

local dev = GetSelf()
make_default_activity(SIT.UPDATE)

local TWO_PI = 2 * math.pi
local NM, FT = 1852.0, 0.3048
local floor, sqrt, sin, cos, atan2, abs = math.floor, math.sqrt, math.sin, math.cos, math.atan2, math.abs

---------------------------------------------------------------------------
-- log
---------------------------------------------------------------------------
local log_n = 0
local function log(msg)
	if log_n > 300 then return end
	log_n = log_n + 1
	pcall(function()
		local lfs = require("lfs")
		local f = io.open(lfs.writedir() .. "Logs/f15sit_device.log", log_n == 1 and "w" or "a")
		if f then f:write(os.date("%H:%M:%S ") .. tostring(msg) .. "\n"); f:close() end
	end)
end

---------------------------------------------------------------------------
-- parameters
---------------------------------------------------------------------------
-- v0.9: parameters are written only when their value changes (most of
-- the page stays the same from one update to the next)
local PH = {}
PH.__index = PH
function PH:set(v) if v ~= self.v then self.v = v; self.h:set(v) end end
function PH:get() return self.h:get() end
local function P(n) return setmetatable({h = get_param_handle("F15SIT_" .. n)}, PH) end
-- text parameter: created and given a string in the same step. The page
-- draws on DCS's render thread while this file is still loading; a text
-- parameter that exists but still holds the number 0 crashes DCS
-- (access violation in ceStringPoly, v0.3.0 / v0.3.1)
local function PT(n)
	local h = P(n)
	h:set("")
	return h
end
-- a text for a "%s" field: never number-like ("40", "1e5", " 7"), else
-- DCS would store it as a number and crash on the "%s"
local function safe_text(v)
	v = tostring(v or "")
	if tonumber(v) then v = "'" .. v end
	return v
end
-- the page stays hidden until this is 1 (set when everything is ready)
local READY = get_param_handle("F15SIT_READY")
READY:set(0)
local H = {
	own_y = P("OWN_Y"), center = P("CENTER"), rng = P("RNG"),
	page = P("PAGE"), dclt = P("DCLT"), lines = P("LINES"), fch = P("FCH"),
	net = PT("NET_TXT"), dtm = PT("DTM_TXT"),
	dl = P("DL"), rte = P("RTE"), thr = P("THR"),
	time = PT("TIME"), status = PT("STATUS"), stpt = PT("STPT_TXT"),
	rot = P("ROT"), own_rot = P("OWN_ROT"),
	st_vis = P("ST_VIS"), inv = {PT("INV1_TXT"), PT("INV2_TXT"), PT("INV3_TXT"), PT("INV4_TXT")}, inv_sel = P("INV_SEL"),
	chaff = P("CHAFF"), flare = P("FLARE"), master = PT("MASTER_TXT"),
	be = {x = P("BE_X"), y = P("BE_Y"), vis = P("BE_VIS"), on = P("BE_ON"), txt = PT("BE_TXT")},
	az = {},
	lk = {x = P("LK_X"), y = P("LK_Y"), vis = P("LK_VIS"), t1 = PT("LK_T1"), t2 = PT("LK_T2"), t3 = PT("LK_T3"), blk = P("LK_BLK")},
}
for k = 1, 2 do
	local p = "AZ" .. k .. "_"
	H.az[k] = {ax = P(p .. "AX"), ay = P(p .. "AY"), bx = P(p .. "BX"), by = P(p .. "BY"), vis = P(p .. "VIS")}
end
-- MPCD pages
H.crs = P("CRS"); H.zulu = P("ZULU")
H.rng_mode = P("RNG_MODE"); H.rngt = PT("RNG_TXT")
H.cur = {x = P("CUR_X"), y = P("CUR_Y"), vis = P("CUR_VIS")}
H.cur_sit = P("CUR_SIT"); H.autor = P("AUTOR")
H.pdt = {ax = P("PDT_AX"), ay = P("PDT_AY"), bx = P("PDT_BX"), by = P("PDT_BY"), vis = P("PDT_VIS")}
H.ics_fail = P("ICS_FAIL")
H.own_x = P("OWN_X")
H.own_vis = P("OWN_VIS")                     -- ownship symbol on the SIT area (EXP can move it off)
H.geo = {}
for j = 1, SIT.GEO_SEGS do
	local p = "GS" .. j .. "_"
	H.geo[j] = {ax = P(p .. "AX"), ay = P(p .. "AY"), bx = P(p .. "BX"), by = P(p .. "BY"), vis = P(p .. "VIS")}
end
H.gb = {}
for b = 1, math.ceil(SIT.GEO_SEGS / 16) do H.gb[b] = P("GB" .. b) end      -- blocks of 16 pieces (page: hidden blocks cost nothing)
H.gl = {}
for k = 1, SIT.GEO_LABELS do
	local p = "GL" .. k .. "_"
	H.gl[k] = {x = P(p .. "X"), y = P(p .. "Y"), vis = P(p .. "VIS"), txt = PT(p .. "TXT")}
end
H.dtm_cart = PT("DTM_CART_TXT"); H.dtm_loaded = PT("DTM_LOADED_TXT")
H.hk = {PT("HK1_TXT"), PT("HK2_TXT"), PT("HK3_TXT"), PT("HK4_TXT")}
H.hk_vis = P("HK_VIS"); H.hk_col = P("HK_COL"); H.hkm = {x = P("HKM_X"), y = P("HKM_Y"), vis = P("HKM_VIS")}
H.aa_b = {PT("AA_B1_TXT"), PT("AA_B2_TXT"), PT("AA_B3_TXT")}
H.aa = {selvis = P("AA_SEL_VIS"), sel = PT("AA_SEL_TXT"), gun = P("AA_GUN"), chf = P("AA_CHF"), flr = P("AA_FLR"), ics = PT("AA_ICS_TXT")}
H.crs_l = {ax = P("CRS_AX"), ay = P("CRS_AY"), bx = P("CRS_BX"), by = P("CRS_BY"), vis = P("CRS_VIS")}
H.cmd = PT("CMD_TXT"); H.pf = PT("PF_TXT")
H.sta = {}
for n = 1, #SIT.STATIONS do H.sta[n] = {txt = PT("STA" .. n .. "_TXT"), vis = P("STA" .. n .. "_VIS")} end
H.trng = P("TRNG"); H.icsd = P("ICSD")
H.jg = {}
for g = 1, 5 do H.jg[g] = P("JG" .. g) end
H.jprog = P("JPROG"); H.jett = PT("JETT_TXT")
H.cm = {}; for k = 1, 6 do H.cm[k] = PT("CM" .. k .. "_TXT") end
H.msl = {}
for k = 1, SIT.MAX_MSL do
	local p = "MSL" .. k .. "_"
	H.msl[k] = {x = P(p .. "X"), y = P(p .. "Y"), vis = P(p .. "VIS"), sym = P(p .. "SYM"), tx = P(p .. "TX"), ty = P(p .. "TY"), tvis = P(p .. "TVIS"),
		txt = PT(p .. "TXT"), l = {ax = P(p .. "LAX"), ay = P(p .. "LAY"), bx = P(p .. "LBX"), by = P(p .. "LBY"), vis = P(p .. "LVIS")}}
end
H.mk = {}
for k = 1, SIT.MAX_MARKS do
	local p = "MK" .. k .. "_"
	H.mk[k] = {x = P(p .. "X"), y = P(p .. "Y"), vis = P(p .. "VIS"), txt = PT(p .. "TXT")}
end
H.dcl_lv = PT("DCL_TXT"); H.dcl_pop = P("DCL_POP")
H.jpwr = P("JPWR")                           -- jet power 1/0, for the helmet device
H.boot = P("BOOT"); H.dim = P("DIM")          -- start-up screen phase, brightness cover (0..19)
H.rad = {{}, {}}; H.rad_act = {}; H.rad_cur = {}; H.rad_vol = {}
for r = 1, 2 do
	for k = 1, 20 do H.rad[r][k] = PT("RAD" .. r .. "_" .. k .. "_TXT") end
	H.rad_act[r] = P("RAD" .. r .. "_ACT"); H.rad_cur[r] = PT("RAD" .. r .. "_CUR_TXT"); H.rad_vol[r] = PT("RAD" .. r .. "_VOL_TXT")
end
H.rad_edit = P("RAD_EDIT"); H.rad_etxt = PT("RAD_E_TXT"); H.rad_ecar = PT("RAD_EC_TXT"); H.rad_emsg = PT("RAD_EM_TXT")
H.rad_src = PT("RAD_SRC_TXT")
H.cm_row = P("CM_ROW"); H.cm_fld = P("CM_FLD"); H.cm_sel = PT("CM_SEL_TXT")
H.load = {}
for n = 1, #SIT.STATIONS + 2 do H.load[n] = PT("LOAD" .. n .. "_TXT") end
H.bit = {}
for n = 1, #SIT.BIT_ROWS do H.bit[n] = P("BIT" .. n) end
H.bit_mode = P("BIT_MODE"); H.bit_txt = PT("BIT_TXT")
H.td = {}
for n = 1, 6 do H.td[n] = PT("TD" .. n .. "_TXT") end
H.own = {}
for n = 1, 11 do H.own[n] = PT("OWN" .. n .. "_TXT") end
H.fs = {}
for k = 1, 4 do
	local p = "FS" .. k .. "_"
	H.fs[k] = {n = PT(p .. "N_TXT"), d = PT(p .. "D_TXT"), own = P(p .. "OWN"), sel = P(p .. "SEL"), empty = P(p .. "EMPTY")}
end
H.fmode = P("FLT_AUTO"); H.fhint = PT("FLT_HINT_TXT")
H.fc = {}
for k = 1, 5 do H.fc[k] = {txt = PT("FC" .. k .. "_TXT"), on = P("FC" .. k .. "_ON")} end
H.fc_pg = PT("FC_PG_TXT")
local ALL_TEXT = {}         -- every page text parameter, set to "" before the first frame
for _, h in ipairs({H.cmd, H.pf, H.jett, H.bit_txt, H.rngt, H.aa.sel, H.aa.ics, H.dtm_cart, H.dtm_loaded}) do ALL_TEXT[#ALL_TEXT + 1] = h end
for _, t in ipairs({H.load, H.td, H.own}) do for _, h in ipairs(t) do ALL_TEXT[#ALL_TEXT + 1] = h end end
for _, s in ipairs(H.sta) do ALL_TEXT[#ALL_TEXT + 1] = s.txt end
for _, s in ipairs(H.fc) do ALL_TEXT[#ALL_TEXT + 1] = s.txt end
for _, s in ipairs(H.fs) do ALL_TEXT[#ALL_TEXT + 1] = s.n; ALL_TEXT[#ALL_TEXT + 1] = s.d end
ALL_TEXT[#ALL_TEXT + 1] = H.fhint
ALL_TEXT[#ALL_TEXT + 1] = H.fc_pg
for _, t in ipairs({H.hk, H.aa_b}) do for _, h in ipairs(t) do ALL_TEXT[#ALL_TEXT + 1] = h end end
for _, g in ipairs(H.gl) do ALL_TEXT[#ALL_TEXT + 1] = g.txt end

local HC = {}
for n = 1, SIT.MAX_CONTACTS do
	local p = "C" .. n .. "_"
	HC[n] = {x = P(p .. "X"), y = P(p .. "Y"), typ = P(p .. "TYPE"), hdg = P(p .. "HDG"), col = P(p .. "COL"),
	         mov = P(p .. "MOV"), alt = P(p .. "ALT"), num = P(p .. "NUM")}
end
local HW = {}
for n = 1, SIT.MAX_WPTS do
	local p = "W" .. n .. "_"
	HW[n] = {x = P(p .. "X"), y = P(p .. "Y"), vis = P(p .. "VIS"), num = P(p .. "NUM"), seg = P(p .. "SEG"),
	         ax = P(p .. "AX"), ay = P(p .. "AY"), bx = P(p .. "BX"), by = P(p .. "BY")}
end
local HG = {}
for g = 1, SIT.MAX_THREATS do
	local p = "G" .. g .. "_"
	local h = {x = P(p .. "X"), y = P(p .. "Y"), vis = P(p .. "VIS"), txt = PT(p .. "TXT"), ring = P(p .. "RING"), rv = P(p .. "RV"), seg = {}}
	for j = 1, SIT.RING_SEGS do
		h.seg[j] = {ax = P(p .. "S" .. j .. "_AX"), ay = P(p .. "S" .. j .. "_AY"),
		            bx = P(p .. "S" .. j .. "_BX"), by = P(p .. "S" .. j .. "_BY"), vis = P(p .. "S" .. j .. "_VIS")}
	end
	HG[g] = h
end
---------------------------------------------------------------------------
-- page state (changed by the buttons)
---------------------------------------------------------------------------
local ST = {rng = SIT.RANGE_DEFAULT, center = true, nup = false, form = false,
            rdr = true, dl = true, rte = true, thr = true,
            page = 1,                     -- 1 SIT, 2 MENU, 3 DTM
            dclt = false, lines = true, fch = 19,
            dtm_msg = "", dtm_t = -1000, dtm_done = "",
            crs = false, zulu = SIT.ZULU_DEFAULT, net_t = -1000, ipf_t = -1000,
            cmd = 1, pf = 1, trng = false, icsd = false,
            jprog = 1, jg = {[1] = {true, false, true, false, true}, [2] = {true, true, true, true, true}},
            ibit_t = -1000, bit_mode = 1,
            slot = {"OWN"}, slot_man = false, flt_page = 0, fsel = nil,   -- the flight: slots 1-4 (FLIGHT DATA page)
            exp = false,
            soi_sit = false,            -- castle up: the SIT page has the cursor (TDC) instead of the VSD
            autor = false, cm_row = 1, cm_fld = 1, dcl = 1, rch = {1, 1}, vol = {SIT.SRS_VOL_START or 80, SIT.SRS_VOL_START or 80}, marks = {},              -- AUTO RANGE: SIT range follows the VSD range
            mode = 2, brt = SIT.BRT_STEPS,   -- display knob (0 OFF, 1 NIGHT, 2 DAY), brightness step
            cart = 1, carts = nil,      -- DTM: choice (1 = MSN, 2.. = cartridge files)
            loaded = {name = "MSN"}}    -- the cartridge in use: {name, route, bull, geo} (nil fields = mission's)

local tick = 0                  -- updates so far
local PF = {n = 0, sum = 0, max = 0, t = nil, blocks = 0, on = false}   -- timing log (see update())
-- power: sw = the jet's electric power switch as we know it (nil = not
-- looked at yet), on = powered, disp = powered and knob not OFF, shown =
-- the page is up (start-up over), cmd = the power switch command
local PWR = {sw = nil, on = true, disp = true, shown = true, boot_t = nil, cmd = nil, ready = nil, n_log = 0}
local PGF = {now = true, last = nil}   -- MENU pages: redraw now (button pressed) / page last drawn

-- the flight on the FLIGHT DATA page (v1.1): slots 1-4, each "OWN" (the
-- ownship), a unit name or empty. AUTO: the ownship and its group in
-- unit-name order; any change on the page makes it manual. Kept in
-- Saved Games\DCS\Config\F15SIT_flight.txt:
--   #MODE=MAN / #MODE=AUTO, #SLOT<n>=OWN / #SLOT<n>=<unit name>
-- (before v1.1 the file held unit names, one per line: read as a manual flight)
local function flt_file()
	local ok, l = pcall(require, "lfs")
	return ok and l and (l.writedir() .. "Config/F15SIT_flight.txt") or nil
end
local function flt_load()
	local fn = flt_file()
	local f = fn and io.open(fn, "r")
	if not f then return end
	local old, own, slots, mode = {}, nil, {}, nil
	for raw in f:lines() do
		local line = raw:gsub("\r", "")
		local k, v = line:match("^#SLOT(%d)=(.+)$")
		if k then slots[tonumber(k)] = v
		elseif line:match("^#MODE=") then mode = line:match("^#MODE=(%u+)")
		elseif line:match("^#OWN=%d") then own = tonumber(line:match("^#OWN=(%d)"))
		elseif line ~= "" then old[#old + 1] = line end
	end
	f:close()
	if mode then
		ST.slot_man = mode == "MAN"
		if ST.slot_man then ST.slot = {} for k = 1, 4 do ST.slot[k] = slots[k] end end
	elseif #old > 0 or own then
		ST.slot_man, ST.slot = true, {}
		ST.slot[own or 1] = "OWN"
		table.sort(old)
		for _, nm in ipairs(old) do
			for k = 1, 4 do if not ST.slot[k] then ST.slot[k] = nm; break end end
		end
	end
end
local function flt_save()
	local fn = flt_file()
	local f = fn and io.open(fn, "w")
	if not f then return end
	f:write("#MODE=" .. (ST.slot_man and "MAN" or "AUTO") .. "\n")
	if ST.slot_man then
		for k = 1, 4 do if ST.slot[k] then f:write("#SLOT" .. k .. "=" .. ST.slot[k] .. "\n") end end
	end
	f:close()
end

---------------------------------------------------------------------------
-- own aircraft
---------------------------------------------------------------------------
local SD = nil
local function sensors()
	if SD then return SD end
	if get_base_data then
		local ok, d = pcall(get_base_data)
		if ok and d then SD = d end
	end
	if not SD and sensor_data then SD = sensor_data end
	return SD
end

---------------------------------------------------------------------------
-- feed from the export script
---------------------------------------------------------------------------
local feed = {rx = -1000, list = {}, wpts = {}, active = 0, lock = nil, thr = {}, status = 0,
              packets = 0, coal = 0, master = "", stores = nil, cm = nil,
              bull = nil,     -- bull = {red = {x, z} or nil, blue = {x, z} or nil}, from the hook
              radar = nil,    -- radar = {on, az, size, dist}: scan centre / width (rad), range scale (m)
              date = nil,     -- from the hook: {th, day, mon, year, start}
              own = nil,      -- {lat, lon, id, unit, pilot}
              fail = {},      -- failed systems (LoGetMCPState)
              flight = {},    -- friendly aircraft {x, z, y, vx, vz, unit, type, human, own (same group)}
              sta = {},       -- export stations {n, name, cl}
              pylons = nil,   -- from the hook: [pylon 1..11] = CLSID
              slot_map = {},  -- export station -> pylon (1..11 = 2A 2 2B 3 4 5 6 7 8B 8 8A), kept once found
              cur_sta = 0,
              mgeo = nil, mgeo_ver = nil}  -- mission drawings (hook): shapes {kw, name, x = {}, z = {}}     -- bull = {red = {x, z} or nil, blue = {x, z} or nil}, from the hook
local udp, udp_state = nil, "init"
local function open_udp()
	local ok_lfs, lfs_mod = pcall(require, "lfs")
	local root = (ok_lfs and lfs_mod and lfs_mod.currentdir and lfs_mod.currentdir()) or "."
	if not package.path:find(root .. "/LuaSocket/?.lua", 1, true) then
		package.path  = package.path .. ";" .. root .. "/LuaSocket/?.lua"
		package.cpath = package.cpath .. ";" .. root .. "/LuaSocket/?.dll"
	end
	local ok, socket = pcall(require, "socket")
	if not ok or not socket then udp_state = "no LuaSocket"; return end
	local u = socket.udp()
	u:settimeout(0)
	local r, err = u:setsockname("127.0.0.1", SIT.PORT)
	if not r then
		pcall(function() u:setoption("reuseaddr", true) end)
		r, err = u:setsockname("127.0.0.1", SIT.PORT)
	end
	if not r then udp_state = "port busy: " .. tostring(err); return end
	udp, udp_state = u, "listening"
end

local function now() return get_model_time and get_model_time() or 0 end

-- missiles by weapon name (from LoGetNameByType): A = AIM-120, M = AIM-9, S = AIM-7
local function store_class(name)
	name = (name or ""):upper()
	if name:find("120", 1, true) then return "a" end
	if name:find("AIM.?7") then return "s" end
	if name:find("AIM.?9") then return "m" end
	return nil
end
local MASTER = {NAV = "NAV", BVR = "A/A", CAC = "A/A", LNG = "A/A", VS = "A/A", BORE = "A/A",
                FI0 = "A/A", A2G = "A/G", OFF = ""}

---------------------------------------------------------------------------
-- EWR picture from server text messages (as the MiG-29 add-on, v1.7.8/9):
-- servers that block export still send "<server> EWR | Picture Report"
-- texts. The hook forwards them (F15SITE); their rows become contacts,
-- placed from our position when the report came in, moved along their
-- heading (at most EWR_EXTRAP_S) and dropped after EWR_KEEP_S.
--   "... EWR | Friendly Picture Report" -> friendly, else hostile
--   row: TYPE BRG RNG NM ALT ft SPD Knts HDG [name / aspect] (or km, m, km/h)
---------------------------------------------------------------------------
EWR = {fr = nil, hs = nil, t_fr = nil, t_hs = nil, n = 0}
do
	local KT = 0.514444
	local LINE = "^%s*(.-)%s+(%d+)%s+([%d,%.]+)%s*(%a+)%s+(%-?[%d,%.]+)%s*(%a+)%s+([%d,%.]+)%s*([%a/]+)%s+(%d+)%s*(.-)%s*$"
	local U_RNG = {nm = 1852, km = 1000, m = 1}
	local U_ALT = {ft = 0.3048, feet = 0.3048, m = 1, km = 1000}
	local U_SPD = {kts = KT, knts = KT, knots = KT, kt = KT, kn = KT, kph = 1 / 3.6, kmh = 1 / 3.6, ["km/h"] = 1 / 3.6,
	               kmph = 1 / 3.6, mph = 0.44704, ["m/s"] = 1, mps = 1}
	local function num(s) return tonumber((s:gsub(",", ""))) end
	local function row(line)
		local ty, brg, rng, ur, alt, ua, spd, us, hdg, rest = line:match(LINE)
		if not ty or ty == "" or ty:upper() == "TYPE" then return nil end
		local fr, fa, fs = U_RNG[ur:lower()], U_ALT[ua:lower()], U_SPD[us:lower()]
		if not (fr and fa and fs) then return nil end
		brg, rng, alt, spd, hdg = tonumber(brg), num(rng), num(alt), num(spd), tonumber(hdg)
		if not (brg and rng and alt and spd and hdg) then return nil end
		return {type = ty, brg = brg, rng = rng * fr, alt = alt * fa, spd = spd * fs, hdg = hdg, rest = rest}
	end
	local function contacts(rows, code, t, ox, oz)
		local list = {}
		for _, r in ipairs(rows) do
			-- (a friendly right on top of us is our own jet)
			if not (code == 1 and r.rng < 1000) then
			local b, h = math.rad(r.brg), math.rad(r.hdg)
			list[#list + 1] = {code = code, x = ox + r.rng * math.cos(b), z = oz + r.rng * math.sin(b), y = r.alt,
			                   vx = r.spd * math.cos(h), vz = r.spd * math.sin(h), t = t, mx = SIT.EWR_EXTRAP_S,
			                   nm = r.type:sub(1, 10), ewr = true}
			end
		end
		return list
	end
	function EWR.on_packet(text, t, ox, oz)
		if not ox then return end
		local out, cur = {}, nil
		for line in tostring(text or ""):gmatch("[^\r\n]+") do
			local u = line:upper()
			if u:find("PICTURE", 1, true) and u:find("EWR", 1, true) then
				cur = u:find("FRIENDLY", 1, true) and "fr" or "hs"
				out[cur] = out[cur] or {}
			elseif cur then
				local r = row(line)
				if r then local l = out[cur]; l[#l + 1] = r end
			end
		end
		if out.fr then EWR.fr, EWR.t_fr = contacts(out.fr, 1, t, ox, oz), t end
		if out.hs then EWR.hs, EWR.t_hs = contacts(out.hs, 2, t, ox, oz), t end
		if out.fr or out.hs then EWR.n = EWR.n + 1 end
	end
	local function alive(tt, t) return tt and t >= tt and t - tt <= SIT.EWR_KEEP_S end
	function EWR.fresh(t) return alive(EWR.t_fr, t) or alive(EWR.t_hs, t) end
	-- the contacts to draw: the export's list; with no datalink picture in it
	-- (export blocked / stale) the EWR contacts are added
	local EMPTY, MC = {}, {}
	function EWR.merge(list, t, stale)
		if not SIT.EWR_ON then return stale and EMPTY or list end
		if EWR.t_fr and not alive(EWR.t_fr, t) then EWR.fr, EWR.t_fr = nil, nil end
		if EWR.t_hs and not alive(EWR.t_hs, t) then EWR.hs, EWR.t_hs = nil, nil end
		local base = stale and EMPTY or list
		if not (EWR.fr or EWR.hs) then return base end
		if MC.base == base and MC.fr == EWR.fr and MC.hs == EWR.hs then return MC.out end
		local out = base
		local dl = false
		for _, c in ipairs(base) do if (c.code or 0) < 10 then dl = true; break end end
		if not dl then
			out = {}
			for i, c in ipairs(base) do out[i] = c end
			for _, l in ipairs({EWR.fr or EMPTY, EWR.hs or EMPTY}) do for _, c in ipairs(l) do out[#out + 1] = c end end
		end
		MC.base, MC.fr, MC.hs, MC.out = base, EWR.fr, EWR.hs, out
		return out
	end
end

-- the SIT cursor's own movement while SIT has the cursor: the jet's TDC
-- slew axis (it reaches us) and the add-on's own "SIT Cursor" binds
SLEW = {kx = 0, ky = 0, ax = 0, ay = 0, rx = 0, ry = 0, seen = {}, n_seen = 0, cmds = nil}
function SLEW.dz(v)
	if math.abs(v) < SIT.SLEW_DEADZONE then return 0 end
	return v
end
local CUR_F = {}                                        -- (F15SITC fields, reused: 20 packets a second)
local C_NAME = "^C" .. string.rep(",[^,]*", 7) .. ",([^,]*)$"   -- (a contact's name: field 8)
local function parse(data)
	if data:sub(1, 7) == "F15SITB" then                  -- bullseye from the hook: red x,z, blue x,z
		local f = {}
		for v in data:gmatch(",([^,]*)") do f[#f + 1] = tonumber(v) or false end
		local b = {}
		if f[1] and f[2] then b.red = {f[1], f[2]} end
		if f[3] and f[4] then b.blue = {f[3], f[4]} end
		feed.bull = b
		return
	end
	if data:sub(1, 7) == "F15SITW" then                  -- own missiles in flight from the export
		local list = {}
		for e in data:gmatch("|([^|]*)") do
			local f = {}
			for v in (e .. ","):gmatch("([^,]*),") do f[#f + 1] = v end
			-- typ, has missile, mx, mz, has target, tx, tz, tti (s, -1 = none)
			list[#list + 1] = {typ = f[1], m = f[2] == "1", mx = tonumber(f[3]), mz = tonumber(f[4]),
				tg = f[5] == "1", tx = tonumber(f[6]), tz = tonumber(f[7]), tti = tonumber(f[8]) or -1}
		end
		feed.msl, feed.msl_t = list, now()
		return
	end
	if data:sub(1, 7) == "F15SITE" then                  -- EWR picture report text from the hook
		EWR.pending = data:sub(9)            -- placed in update(), from our position then
		return
	end
	if data:sub(1, 7) == "F15SITR" then                  -- radio presets from the hook
		if data ~= feed.radio_raw then
			local parts = {}
			for s in (data .. "|"):gmatch("([^|]*)|") do parts[#parts + 1] = s end
			local r = {grp = parts[2], radios = {}}
			for k = 3, #parts do
				local list = {}
				for f in parts[k]:gmatch("[^,]+") do list[#list + 1] = f end
				r.radios[#r.radios + 1] = list
			end
			feed.radio_raw, feed.radio = data, r
		end
		return
	end
	if data:sub(1, 7) == "F15SITP" then                  -- the jet's pylons from the hook: pylon=CLSID
		if data ~= feed.pylons_raw then
			local py = {}
			for n, cl in data:gmatch(",(%d+)=([^,]*)") do py[tonumber(n)] = cl end
			feed.pylons_raw, feed.pylons, feed.slot_map = data, py, {}
		end
		return
	end
	if data:sub(1, 7) == "F15SITC" then                  -- radar cursor, 20 per second (export)
		local f, n = CUR_F, 0
		for v in data:gmatch(",([^,]*)") do n = n + 1; f[n] = tonumber(v) or 0 end
		for i = n + 1, #f do f[i] = nil end
		if n >= 7 then
			local c = feed.cur or {}
			c.on, c.tx, c.ty, c.dist, c.saz, c.az, c.size = f[1] == 1, f[2], f[3], f[4], f[5], f[6], f[7]
			c.chaff, c.flare, c.t = f[8], f[9], now()
			c.acq = f[10] or 0               -- (auto acquisition: 0 none, 1 SS, 2 LR, 3 helmet)
			feed.cur = c
		end
		return
	end
	if data:sub(1, 7) == "F15SITL" then                  -- mission drawings from the hook
		local ver = data:match("^F15SITL,([^\n]*)")
		if ver == feed.mgeo_ver then return end
		local shapes = {}
		for line in data:gmatch("[^\n]+") do
			local k = line:sub(1, 1)
			if (k == "A" or k == "L") and line:sub(2, 2) == "," then
				local name, rest = line:match("^.,([^,]*),(.*)$")
				local s = {kw = (k == "A") and "area" or "line", name = name or "", x = {}, z = {}}
				for x, z in (rest or ""):gmatch("([-%d%.]+),([-%d%.]+)") do s.x[#s.x + 1], s.z[#s.z + 1] = tonumber(x), tonumber(z) end
				if #s.x >= 2 then shapes[#shapes + 1] = s end
			end
		end
		feed.mgeo, feed.mgeo_ver = shapes, ver
		log("mission drawings: " .. #shapes)
		return
	end
	if data:sub(1, 7) == "F15SITD" then                  -- map and date from the hook
		local th, dd, mm, yy, st = data:match("^F15SITD,([^,]*),([^,]*),([^,]*),([^,]*),([^,]*)")
		if th then feed.date = {th = th, day = tonumber(dd) or 0, mon = tonumber(mm) or 0, year = tonumber(yy) or 0, start = tonumber(st) or 0} end
		return
	end
	if data:sub(1, 8) ~= "F15SIT 1" then return end
	local t = now()
	local list, wpts, thr, lock, active, status = {}, {}, {}, nil, 0, 0
	local stores, cm, master, gun = nil, nil, "", false
	local own, fail, flight, sta, cur_sta = feed.own, {}, {}, {}, feed.cur_sta
	local coal = feed.coal
	local radar = nil
	local f = {}
	for line in data:gmatch("[^\n]+") do
		local k = line:sub(1, 1)
		for i = #f, 1, -1 do f[i] = nil end
		for v in line:gmatch(",([^,]*)") do local x = tonumber(v); if x ~= nil then f[#f + 1] = x end end
		if k == "C" and #f >= 7 then
			local nm = line:match(C_NAME)
			list[#list + 1] = {code = f[1], x = f[2], z = f[3], y = f[4], vx = f[5], vz = f[6], t = t - (f[7] or 0),
			                   nm = (nm and nm ~= "") and nm or nil}
		elseif k == "W" and #f >= 3 then
			wpts[#wpts + 1] = {x = f[1], z = f[2], num = f[3]}
		elseif k == "A" then
			active = f[1] or 0
		elseif k == "S" then
			status = f[1] or 0
		elseif k == "L" and #f >= 5 then
			-- (+ the launch envelope, metres: Raero, Rmin, Rpi, Rtr; 0 = none)
			lock = {x = f[1], z = f[2], y = f[3], vx = f[4], vz = f[5], t = t,
			        ra = f[6] or 0, rm = f[7] or 0, rp = f[8] or 0, rt = f[9] or 0}
		elseif k == "R" and #f >= 4 then
			-- R,on,scan centre az (rad),scan width (rad),range scale (m)[,TDC x,TDC y]
			radar = {on = f[1] == 1, az = f[2], size = f[3], dist = f[4], tx = f[5] or 0, ty = f[6] or 0,
			         ecm = f[7] == 1, scale_az = f[8] or math.rad(60)}
		elseif k == "O" then
			coal = f[1] or coal
		elseif k == "N" then
			local m, sub = line:match("^N,([%w_]*),?([%w_]*)")
			master = MASTER[(m or ""):upper()] or ""
			gun = (sub or ""):upper():find("GUN") ~= nil
		elseif k == "Y" and #f >= 2 then
			-- Y,station,count,CLSID,name
			stores = stores or {a = 0, m = 0, s = 0}
			local clsid, nm = line:match("^Y,[^,]*,[^,]*,([^,]*),(.*)$")
			local cl = store_class(nm)
			if cl then stores[cl] = stores[cl] + f[2] end
			sta[f[1]] = {n = f[2], name = nm or "", cl = clsid or ""}
		elseif k == "Z" and #f >= 3 then
			-- Z,gun shells,chaff,flares,current station
			cm = {gun = f[1], chaff = f[2], flare = f[3]}
			cur_sta = f[4] or 0
		elseif k == "P" then
			local la, lo, id, un, pn = line:match("^P,([^,]*),([^,]*),([^,]*),([^,]*),(.*)$")
			if tonumber(la) then own = {lat = tonumber(la), lon = tonumber(lo) or 0, id = tonumber(id) or 0, unit = un or "", pilot = pn or ""} end
		elseif k == "B" then
			for nm in line:gmatch(",([%w_]+)") do fail[nm] = true end
		elseif k == "F" then
			-- F,id,x,z,y,hdg,vx,vz,human,radar,jammer,own flight,type,unit name
			local id, x, z, y, hd, vx, vz, hu, rd, jm, of, ty, un = line:match("^F,([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),(.*)$")
			if tonumber(x) then
				flight[#flight + 1] = {x = tonumber(x), z = tonumber(z), y = tonumber(y) or 0, vx = tonumber(vx) or 0,
				                       vz = tonumber(vz) or 0, unit = un or "", type = ty or "", human = hu == "1",
				                       own = of == "1"}
			end
		elseif k == "G" then
			local lbl, gx, gz, gr = line:match("^G,([^,]*),([^,]*),([^,]*),([^,]*)")
			local gy = line:match("^G,[^,]*,[^,]*,[^,]*,[^,]*,([^,]*)")
			if lbl and tonumber(gx) then thr[#thr + 1] = {lbl = lbl, x = tonumber(gx), z = tonumber(gz), ring = tonumber(gr) or 0,
				y = tonumber(gy) or 0} end
		end
	end
	feed.list, feed.wpts, feed.thr, feed.lock, feed.active, feed.status = list, wpts, thr, lock, active, status
	feed.coal, feed.master, feed.radar, feed.gun = coal, master, radar, gun
	if stores then stores.gun = cm and cm.gun or 0 end
	feed.stores, feed.cm = stores, cm
	feed.own, feed.fail, feed.flight, feed.sta, feed.cur_sta = own, fail, flight, sta, cur_sta
	feed.rx = t
	feed.packets = feed.packets + 1
	if feed.packets == 1 then
		log(string.format("first packet: %d contacts, %d waypoints, %d threats, status %d", #list, #wpts, #thr, status))
	end
end

local HOOK_PFX = {B = true, D = true, E = true, L = true, P = true, R = true}
local function read_udp()
	if not udp then return end
	for _ = 1, 20 do
		local data = udp:receive(32768)
		if not data then break end
		-- (any packet not from the hook - B D E L P R - is from the export
		-- script: the "no export data" check in update)
		if not HOOK_PFX[data:sub(7, 7)] or data:sub(1, 6) ~= "F15SIT" then feed.exp_t = now() end
		local ok, err = pcall(parse, data)
		if not ok and not feed.err then feed.err = true; log("packet error: " .. tostring(err)) end
	end
end

---------------------------------------------------------------------------
-- buttons
--   L1 RNG up   L2 RNG down   L3 CNTR/DCNT   L4 FORM   L5 HUP/NUP
--   R1 RDR      R2 DL         R3 (free)      R4 RTE    R5 MENU (later)
--   B1 THRT     B5 PACS (later)              top row: free (stations, later)
---------------------------------------------------------------------------
local function dtm_msg(busy, done)
	ST.dtm_msg, ST.dtm_done, ST.dtm_t = busy, done, now()
end
local PG = SIT.PG
-- DTM: cartridge choices (1 = MSN) and loading one
local function dtm_choices()
	ST.carts = SIT_DTM.list(feed.date and feed.date.th or "")
	if ST.cart > #ST.carts + 1 then ST.cart = 1 end
end
local function dtm_name(i)
	if i == 1 then return "MSN" end
	local c = ST.carts and ST.carts[i - 1]
	return c and c.name or "MSN"
end
local JETT_NAMES = {"L", "LC", "C", "RC", "R"}
local srs_set, rad_vol, srs_vol_tick, preset_tune, rfp_command    -- (RADIO page, below)
local function dtm_apply()
	if ST.cart == 1 then ST.loaded = {name = "MSN"}; ST.sit_act = nil; return true end
	local c = ST.carts and ST.carts[ST.cart - 1]
	if not c then return false end
	local d = c.data
	local L = {name = c.name}
	local r = SIT_DTM.route(d)
	if #r > 0 then L.route = r end
	L.bull = SIT_DTM.bull(d)
	L.geo = SIT_DTM.read_geo(c.name)
	local j = type(d.jtids) == "table" and d.jtids or {}
	if tonumber(j.fighter_channel) then ST.fch = floor(tonumber(j.fighter_channel)) % 128 end
	if j.own_tn then L.tn = tostring(j.own_tn) end
	if type(j.flight) == "table" then
		SIT_FLT_FROM_LIST(j.flight)
		ST.flt_ver = (ST.flt_ver or 0) + 1
		pcall(flt_save)
	end
	local p = type(d.pacs) == "table" and d.pacs or {}
	for k, v in ipairs(SIT.CMD_PROGRAMS) do if v == p.cmd then ST.cmd = k end end
	-- programs: {"PRG1": {"chaff": 2, "flare": 2, "interval": 0.5, "cycles": 2}, ...}
	if type(p.programs) == "table" then
		ST.cmd_def = {}
		for name, q in pairs(p.programs) do
			if type(q) == "table" then
				ST.cmd_def[name] = {floor(tonumber(q.chaff) or 0), floor(tonumber(q.flare) or 0), tonumber(q.interval) or 1, floor(tonumber(q.cycles) or 1)}
			end
		end
	end
	for k, v in ipairs(SIT.PF_MESSAGES) do if v == p.pf then ST.pf = k end end
	for prog = 1, 2 do
		local list = p["jett" .. prog]
		if type(list) == "table" then
			local sel = {false, false, false, false, false}
			for _, nm in ipairs(list) do
				for g, gn in ipairs(JETT_NAMES) do if gn == nm then sel[g] = true end end
			end
			ST.jg[prog] = sel
		end
	end
	-- radios: {"uhf1": [{"f": 264.0, "n": "TAC"}, ...], "uhf2": [...]}
	local rd = type(d.radios) == "table" and d.radios or nil
	ST.rad_lists = nil
	if rd then
		ST.rad_lists = {}
		for r, key in ipairs({"uhf1", "uhf2"}) do
			if type(rd[key]) == "table" then
				local list = {}
				for k = 1, 20 do
					local q = rd[key][k]
					if type(q) == "table" and tonumber(q.f) then list[k] = {f = tonumber(q.f), n = tostring(q.n or ""):sub(1, 8)} end
				end
				ST.rad_lists[r] = list
			end
		end
		ST.rch = {1, 1}
		for r = 1, 2 do local c = ST.rad_lists[r] and ST.rad_lists[r][1]; if c then preset_tune(r, c.f) end end
	end
	local s = type(d.sit) == "table" and d.sit or {}
	for k, v in ipairs(SIT.RANGES_NM) do if v == tonumber(s.range) then ST.rng = k end end
	for k, v in ipairs(SIT.RANGES_DC_NM) do if v == tonumber(s.range) then ST.rng = k end end
	if s.center ~= nil then ST.center = s.center == true end
	if s.nup ~= nil then ST.nup = s.nup == true end
	if s.zulu ~= nil then ST.zulu = s.zulu == true end
	ST.loaded = L
	ST.sit_act = nil
	log("cartridge loaded: " .. c.name .. " (" .. #r .. " steerpoints, " .. #L.geo .. " drawings)")
	return true
end

-- FLIGHT DATA (v1.1): the flight in slots 1-4. L1..L5 list the friendly
-- aircraft; pick one, then a slot (R1..R4), or a slot, then an aircraft or
-- another slot (swap). CLR empties the picked slot, AUTO goes back to the
-- ownship and its group in unit-name order.
local function own_name() return feed.own and feed.own.unit or "" end
local AUTO_C = {src = nil, own = nil, slots = {"OWN"}}
local function slots_now()
	if ST.slot_man then return ST.slot end
	if AUTO_C.src == feed.flight and AUTO_C.own == own_name() then return AUTO_C.slots end
	local names = {{n = own_name(), own = true}}
	for _, a in ipairs(feed.flight or {}) do
		if a.own and a.unit ~= "" then names[#names + 1] = {n = a.unit} end
	end
	table.sort(names, function(p, q) return p.n < q.n end)
	local sl = {}
	for k = 1, math.min(4, #names) do sl[k] = names[k].own and "OWN" or names[k].n end
	AUTO_C.src, AUTO_C.own, AUTO_C.slots = feed.flight, own_name(), sl
	return sl
end
local function slot_of(unit)
	local sl = slots_now()
	for k = 1, 4 do if sl[k] == unit then return k end end
	return nil
end
local function flt_find(unit)
	for _, a in ipairs(feed.flight or {}) do if a.unit == unit then return a end end
	return nil
end
local function flt_changed(hint)
	ST.flt_ver = (ST.flt_ver or 0) + 1
	ST.fsel = nil
	if hint then ST.fhint, ST.fhint_t = hint, now() end
	flt_save()
end
-- any change by hand: the page's flight becomes manual (starting from what is shown)
local function freeze()
	if ST.slot_man then return end
	local sl = slots_now()
	ST.slot = {}
	for k = 1, 4 do ST.slot[k] = sl[k] end
	ST.slot_man = true
end
local function put_in_slot(unit, k)
	freeze()
	local j = slot_of(unit)
	local cur = ST.slot[k]
	ST.slot[k] = unit
	if j and j ~= k then ST.slot[j] = cur end
	flt_changed()
end
-- a cartridge's flight list (DTM READ): the ownship stays where it is
function SIT_FLT_FROM_LIST(list)
	local own = slot_of("OWN") or 1
	ST.slot, ST.slot_man = {}, true
	ST.slot[own] = "OWN"
	for _, nm in ipairs(list) do
		if type(nm) == "string" and nm ~= "" then
			for k = 1, 4 do if not ST.slot[k] then ST.slot[k] = nm; break end end
		end
	end
	flt_changed()
end
local FLT_CACHE = {src = nil, ver = -1, list = {}}
local function flt_members()
	if FLT_CACHE.src == feed.flight and FLT_CACHE.ver == (ST.flt_ver or 0) and FLT_CACHE.own == own_name() and not (not ST.slot_man and AUTO_C.src ~= feed.flight) then return FLT_CACHE.list end
	local m, sl = {}, slots_now()
	for k = 1, 4 do
		local v = sl[k]
		if v and v ~= "OWN" then
			local a = flt_find(v)
			if a then a.num = k; m[#m + 1] = a end
		end
	end
	FLT_CACHE.src, FLT_CACHE.ver, FLT_CACHE.own, FLT_CACHE.list = feed.flight, ST.flt_ver or 0, own_name(), m
	return m
end
local function flt_candidates() return feed.flight or {} end
local function flt_pick(k)
	local a = flt_candidates()[ST.flt_page * 5 + k]
	if not a or a.unit == "" then return end
	local sel = ST.fsel
	if sel and sel.s then put_in_slot(a.unit, sel.s)
	elseif sel and sel.c == a.unit then ST.fsel = nil
	else ST.fsel = {c = a.unit} end
end
local function flt_slot(k)
	local sel = ST.fsel
	if sel and sel.c then put_in_slot(sel.c, k)
	elseif sel and sel.s then
		if sel.s ~= k then
			freeze()
			ST.slot[k], ST.slot[sel.s] = ST.slot[sel.s], ST.slot[k]
			flt_changed()
		else ST.fsel = nil end
	elseif slots_now()[k] then ST.fsel = {s = k} end
end
local function flt_clr()
	local sel = ST.fsel
	local k = sel and (sel.s or slot_of(sel.c))
	if not k then ST.fsel = nil; return end
	if slots_now()[k] == "OWN" then ST.fsel = nil; ST.fhint, ST.fhint_t = "THE OWNSHIP STAYS IN THE FLIGHT", now(); return end
	freeze()
	ST.slot[k] = nil
	flt_changed()
end
local function flt_auto()
	ST.slot_man = false
	AUTO_C.src = nil
	flt_changed("AUTO: OWN GROUP IN NAME ORDER")
end
local function go(p) return function() ST.page = p end end
local function cycle(key, list) return function() ST[key] = ST[key] % #list + 1 end end
local function jg(g) return function() local t = ST.jg[ST.jprog]; t[g] = not t[g] end end
local cm_edit, rad_step, rad_edit, rad_edit_key
-- declutter: 1 FULL, 2 no lines / route / course line, 3 no data blocks,
-- 4 no threat rings, 5 also no radar coverage; shown for a moment on the SIT
local function dcl_step()
	ST.dcl = ST.dcl % #SIT.DCL_NAMES + 1
	ST.dcl_t = now()
end
-- CMD programs page: change the selected program's field (1 chaff, 2 flares,
-- 3 interval, 4 cycles) one step; reset = back to the add-on's default
local function cm_prog(name)
	ST.cmd_def = ST.cmd_def or {}
	local p = ST.cmd_def[name]
	if not p then
		local d = SIT.CMD_DEF[name] or {0, 0, 1, 1}
		p = {d[1], d[2], d[3], d[4]}; ST.cmd_def[name] = p
	end
	return p
end
function cm_edit(dir, reset)
	local name = SIT.CMD_PROGRAMS[ST.cm_row]
	if not name then return end
	if reset then
		local d = SIT.CMD_DEF[name] or {0, 0, 1, 1}
		ST.cmd_def = ST.cmd_def or {}
		ST.cmd_def[name] = {d[1], d[2], d[3], d[4]}
		return
	end
	local p, f = cm_prog(name), ST.cm_fld
	if f == 1 or f == 2 then p[f] = math.max(0, math.min(10, p[f] + dir))
	elseif f == 3 then
		local v = p[3]
		local st = (v < 1 or (v == 1 and dir < 0)) and 0.05 or 0.25
		p[3] = math.max(0.1, math.min(5, floor((v + dir * st) * 100 + 0.5) / 100))
	else p[4] = math.max(1, math.min(20, p[4] + dir)) end
end
local function page_cmds()
	for k = 1, 6 do
		local name = SIT.CMD_PROGRAMS[k]
		if name then
			local p = (ST.cmd_def and ST.cmd_def[name]) or SIT.CMD_DEF[name] or {0, 0, 1, 1}
			H.cm[k]:set(string.format("%1s%-5s %3d %3d %5.2f %3d", (k == ST.cmd) and ">" or " ", name, p[1], p[2], p[3], p[4]))
		else H.cm[k]:set("") end
	end
	H.cm_row:set(ST.cm_row); H.cm_fld:set(ST.cm_fld)
	local fl = {"CHAFF", "FLARES", "INTERVAL", "CYCLES"}
	H.cm_sel:set("EDIT " .. (SIT.CMD_PROGRAMS[ST.cm_row] or "") .. " " .. fl[ST.cm_fld])
end
local ACTIONS = {
	[PG.SIT] = {
		L1 = function() wp_step(1) end, L2 = function() wp_step(-1) end,   -- WP+ / WP-
		R3 = function() ST.autor = not ST.autor end,   -- range AUTO / MAN
		R5 = go(PG.MENU),
		L5 = go(PG.SETS),
	},
	[PG.SETS] = {
		L1 = function() ST.dl = not ST.dl end,
		L2 = function() ST.rte = not ST.rte end,
		L3 = function() ST.thr = not ST.thr end,
		L4 = function() ST.lines = not ST.lines end,
		L5 = go(PG.SIT),
		R1 = function() ST.crs = not ST.crs end,
		R2 = function() dcl_step() end,
		R3 = function() ST.autor = not ST.autor end,
		R5 = go(PG.MENU),
	},
	[PG.MENU] = {
		T1 = function() ST.crs = not ST.crs end,
		T2 = go(PG.RADIO),
		T4 = function() ST.net_t = now() end,
		T5 = function() ST.ipf_t = now() end,
		L1 = go(PG.ARMT), L2 = go(PG.BIT), L3 = go(PG.SIT), L4 = go(PG.WPN),
		L5 = function() dtm_choices(); ST.page = PG.DTM end,
		R1 = go(PG.TIME), R2 = go(PG.OWN), R3 = go(PG.FLT),
		R4 = go(PG.SETS),
		B2 = function() ST.fch = (ST.fch + 1) % 128 end,
		B4 = function() ST.fch = (ST.fch + 127) % 128 end,
		B5 = function() ST.autor = not ST.autor end,
	},
	[PG.DTM] = {
		L1 = function()
			if dtm_apply() then dtm_msg("READ IN PROGRESS", "READ COMPLETE: " .. dtm_name(ST.cart):upper():sub(1, 16))
			else dtm_msg("READ IN PROGRESS", "READ FAIL") end
		end,
		B3 = function() dtm_choices(); ST.cart = ST.cart % (#ST.carts + 1) + 1 end,
		L2 = function() dtm_msg("", "READ STATUS: GO") end,
		R2 = function() dtm_msg("WRITE IN PROGRESS", "WRITE COMPLETE") end,
		R3 = function() dtm_msg("", "WRITE STATUS: GO") end,
		B5 = function() dtm_msg("", "CC BUFFER CLEARED") end,
		R5 = go(PG.MENU),
	},
	[PG.ARMT] = {
		L2 = go(PG.WPN), L3 = go(PG.JETT), L4 = go(PG.LOAD),
		L5 = function() ST.trng = not ST.trng end,
		R1 = go(PG.SIT),
		R2 = function() ST.icsd = not ST.icsd end,
		R3 = function() ST.cm_row = ST.cmd; ST.page = PG.CMDS end,   -- CMD programs page
		R4 = cycle("pf", SIT.PF_MESSAGES),
		R5 = go(PG.MENU),
	},
	[PG.JETT] = {
		T1 = jg(1), T2 = jg(2), T3 = jg(3), T4 = jg(4), T5 = jg(5),
		L1 = function() ST.jprog = 1 end,
		L2 = function() ST.jprog = 2 end,
		L5 = go(PG.ARMT), R5 = go(PG.MENU),
	},
	[PG.LOAD] = {L5 = go(PG.ARMT), R5 = go(PG.MENU)},
	[PG.BIT] = {
		L1 = function() ST.bit_mode = 1 end,
		L2 = function() ST.bit_mode = 2; ST.ibit_t = now() end,
		R5 = go(PG.MENU),
	},
	[PG.TIME] = {
		R1 = function() ST.zulu = true end,
		R2 = function() ST.zulu = false end,
		R5 = go(PG.MENU),
	},
	[PG.OWN] = {R5 = go(PG.MENU)},
	[PG.FLT] = {
		L1 = function() flt_pick(1) end, L2 = function() flt_pick(2) end, L3 = function() flt_pick(3) end,
		L4 = function() flt_pick(4) end, L5 = function() flt_pick(5) end,
		R1 = function() flt_slot(1) end, R2 = function() flt_slot(2) end,
		R3 = function() flt_slot(3) end, R4 = function() flt_slot(4) end,
		B2 = function() ST.flt_page = math.max(0, ST.flt_page - 1) end,
		B3 = flt_clr,
		B4 = function() ST.flt_page = ST.flt_page + 1 end,
		B5 = flt_auto,
		R5 = go(PG.MENU),
	},
	[PG.WPN] = {L1 = go(PG.ARMT), R5 = go(PG.MENU)},
	[PG.RADIO] = {
		-- UP = up the list (lower channel number), DN = down the list
		L1 = function() rad_step(1, -1) end, L2 = function() rad_step(1, 1) end,
		R1 = function() rad_step(2, -1) end, R2 = function() rad_step(2, 1) end,
		L3 = function() rad_vol(1, 1) end, L4 = function() rad_vol(1, -1) end,
		R3 = function() rad_vol(2, 1) end, R4 = function() rad_vol(2, -1) end,
		T1 = function() rad_edit(1) end, T5 = function() rad_edit(2) end,
		B1 = function() rad_edit_key("L") end, B2 = function() rad_edit_key("-") end,
		B3 = function() rad_edit_key("E") end, B4 = function() rad_edit_key("+") end,
		B5 = function() rad_edit_key("R") end,
		R5 = function() ST.redit = nil; ST.page = PG.MENU end,
	},
	[PG.CMDS] = {
		L1 = function() ST.cm_row = (ST.cm_row - 2) % #SIT.CMD_PROGRAMS + 1 end,
		L2 = function() ST.cm_row = ST.cm_row % #SIT.CMD_PROGRAMS + 1 end,
		L3 = function() ST.cmd = ST.cm_row end,
		L4 = function() cm_edit(0, true) end,
		L5 = go(PG.ARMT), R5 = go(PG.MENU),
		T1 = function() ST.cm_fld = 1 end, T2 = function() ST.cm_fld = 2 end,
		T3 = function() ST.cm_fld = 3 end, T4 = function() ST.cm_fld = 4 end,
		B2 = function() cm_edit(-1) end, B4 = function() cm_edit(1) end,
	},
}
local CMD2BTN = {}
for name, cmd in pairs(SIT_CMD) do CMD2BTN[cmd] = name end

local hotas, jett_what, to_export    -- (defined below)
-- while SIT has the cursor: every value the slew axis gives the radar is
-- followed at once by a 0 from us (dispatch_action), so the radar cursor
-- hardly moves. Our own 0 comes back to us too: that one is skipped.
SLEW.pend = {}
local function radar_squelch(command, v)
	-- the export's marker value (it keeps the TDC slew at ~0 every frame while
	-- SIT has the cursor): not the pilot's stick
	if v > 0 and v < 1e-5 then return true end
	return false
end
-- SIT range one step (keybinds; the radar's Display Zoom keys while SIT has
-- the cursor)
local function sit_range(dir)
	local r0 = ST.rng
	ST.rng = math.max(1, math.min(#SIT.RANGES_NM, ST.rng + dir))
	if ST.rng ~= r0 then ST.autor = false; ST.form = false; ST.exp = false end
end
-- the radar's zoom keys: with SIT holding the cursor they step the SIT range
-- and the export presses the opposite key, so the radar stays where it was
-- (that press comes back to us too and is skipped)
SLEW.zskip = {}
local function zoom_command(command, c)
	local z = SLEW.zskip[command]
	if z and z.n > 0 and now() - z.t < 0.5 then z.n = z.n - 1; return true end
	if not ST.soi_sit then return true end
	local up = command == c.zoom_out           -- zoom out = more range
	sit_range(up and 1 or -1)
	local back = up and c.zoom_in or c.zoom_out
	if back then
		local s = SLEW.zskip[back] or {n = 0}
		s.n, s.t = s.n + 1, now(); SLEW.zskip[back] = s
		to_export("F15SITU," .. back)
	end
	return true
end
local function slew_command(command, value)
	local c = SLEW.cmds or {}
	if c.zoom_in and (command == c.zoom_in or command == c.zoom_out) then return zoom_command(command, c) end
	local v = tonumber(value) or 0
	-- log every command we get the first time (which ones reach the add-on)
	if (not SLEW.seen[command] or (command >= 3101 and command <= 3115 and v ~= 0)) and SLEW.n_seen < 80 then
		SLEW.seen[command] = true; SLEW.n_seen = SLEW.n_seen + 1
		log(string.format("command in: %s value %s", tostring(command), tostring(value)))
	end
	if command == 3110 then SLEW.kx = (v > 0) and -1 or 0
	elseif command == 3111 then SLEW.kx = (v > 0) and 1 or 0
	elseif command == 3112 then SLEW.ky = (v > 0) and 1 or 0
	elseif command == 3113 then SLEW.ky = (v > 0) and -1 or 0
	elseif command == 3114 then SLEW.ax = v
	elseif command == 3115 then SLEW.ay = v
	-- the radar slew keys (88-91) are left alone: the export's cursor hold
	-- presses those itself. The radar slew AXIS does reach us: use it directly.
	elseif command == c.sel_h or command == c.axis_h_abs or command == c.axis_h then
		if radar_squelch(command, v) then return true end
		SLEW.rx = v; if command == c.sel_h then SLEW.raw_h = v end
	elseif command == c.sel_v or command == c.axis_v_abs or command == c.axis_v then
		if radar_squelch(command, v) then return true end
		SLEW.ry = (SIT.SLEW_INVERT_Y and -v or v); if command == c.sel_v then SLEW.raw_v = v end
	else return false end
	return true
end

-- JHMCS controls: the panel on the left console (power switch, brightness
-- knob: clickable, their model arguments 131 / 130) and the binds. The
-- helmet device reads them as F15SIT_HPWR (1 on), HBRT (0..1), HMUTE (1 =
-- symbology off).
local HCTL = {pwr = HMD.PWR_START ~= false, brt = HMD.BRT_START or 1, mute = false, args_t = nil}
local HCP = {pwr = P("HPWR"), brt = P("HBRT"), mute = P("HMUTE")}
-- the switch and the knob in the model follow binds too (clicks move them themselves)
local function hmd_args()
	pcall(function()
		local mp = GetDevice(0)
		if mp then
			mp:set_argument_value(HMD_ARG.PWR, HCTL.pwr and 1 or 0)
			mp:set_argument_value(HMD_ARG.BRT, HCTL.brt)
		end
	end)
end
local function hmd_controls(command, value)
	local on = (value or 0) > 0
	if command == HMD_PANEL.PWR or command == HMD_PANEL.BRT then
		-- a click: the model's own argument holds the new position (the
		-- command's value may be the position or the step)
		local ok, v = pcall(function() local mp = GetDevice(0); return mp and mp:get_argument_value(command == HMD_PANEL.PWR and HMD_ARG.PWR or HMD_ARG.BRT) end)
		v = (ok and tonumber(v)) or value or 0
		if HCTL.starting then v = value or 0 end      -- (the start positions: the click's own value)
		if command == HMD_PANEL.PWR then HCTL.pwr = v > 0.5 else HCTL.brt = math.min(1, math.max(0, v)) end
		if log_n < 25 then log(string.format("HMD panel: %s %.2f (command value %s)", command == HMD_PANEL.PWR and "power" or "brightness", v, tostring(value))) end
	elseif command == HMD_BIND.PWR then
		if on then HCTL.pwr = not HCTL.pwr; hmd_args() end
	elseif command == HMD_BIND.BRT_UP then
		if on then HCTL.brt = math.min(1, HCTL.brt + 0.1); hmd_args() end
	elseif command == HMD_BIND.BRT_DN then
		if on then HCTL.brt = math.max(0, HCTL.brt - 0.1); hmd_args() end
	elseif command == HMD_BIND.SYM_TOGGLE then
		if on then HCTL.mute = not HCTL.mute end
	else
		return false
	end
	return true
end
local function hmd_controls_tick(t)
	-- the model's switch and knob to the start positions (ON, full): 1 s
	-- into the flight, "clicked" as the pilot would (DCS moves the parts; the
	-- clicks come back here as commands and set the same state)
	if t > 0 and not HCTL.args_t then HCTL.args_t = t end
	if HCTL.args_t and not HCTL.args_done and t - HCTL.args_t >= 1 then
		HCTL.args_done = true
		HCTL.starting = true
		local ok, err = pcall(function()
			dev:performClickableAction(HMD_PANEL.PWR, HCTL.pwr and 1 or 0)
			dev:performClickableAction(HMD_PANEL.BRT, HCTL.brt)
		end)
		HCTL.starting = false
		hmd_args()
		log("HMD panel: start positions " .. (ok and "set" or ("not set: " .. tostring(err))))
	end
	HCP.pwr:set(HCTL.pwr and 1 or 0); HCP.brt:set(HCTL.brt); HCP.mute:set(HCTL.mute and 1 or 0)
end
hmd_controls_tick(0)

-- auto acq switch (v1.1), after the real F-15C:
--   forward short   Supersearch (from Supersearch: Boresight); looking off
--                   the nose: helmet acquisition
--   forward held 1 s Long Range Boresight (while still held)
--   aft             Vertical Scan
--   depress         return to search
-- and the helmet acquisition bind. The export does the work (F15SITA).
local AQ = {fwd_t = nil, fwd_long = false}
-- (v1.3 SIT lock: the hooked contact, now; set by draw_contacts, read by
-- SetCommand - declared here, before both: G is declared after SetCommand)
local SITLOCK = {at = nil}
local HACQ_P = get_param_handle("F15SIT_HACQ")
local function acq_send(what)
	-- the radar takes the cursor back from the SIT page
	if ST.soi_sit then
		ST.soi_sit = false
		if SIT.SQUELCH_RADAR then to_export("F15SITQ,0,0,0") end
	end
	to_export("F15SITA," .. what)
	if log_n < 200 then log("auto acq: " .. what) end
end
-- the helmet usable: on in Options > Special and its panel power on
local HPWR_P = get_param_handle("F15SIT_HPWR")
local function helmet_on()
	if type(HMD) == "table" and HMD.ENABLED == false then return false end
	return (HPWR_P:get() or 0) >= 0.5
end
local function acq_bind(command, value)
	if command ~= ACQ_BIND.FWD and command ~= ACQ_BIND.AFT and command ~= ACQ_BIND.DEP and command ~= ACQ_BIND.HACQ
		and command ~= ACQ_BIND.SSB and command ~= ACQ_BIND.BST then return false end
	if not PWR.on then return true end
	local down = (value or 0) > 0
	if command == ACQ_BIND.FWD then
		if down then
			if not AQ.fwd_t then AQ.fwd_t, AQ.fwd_long = now(), false end
		elseif AQ.fwd_t then
			-- (v1.1: forward short = helmet acquisition; without the helmet,
			-- FC3's boresight)
			if not AQ.fwd_long then acq_send(helmet_on() and "HM" or "BST") end
			AQ.fwd_t = nil
		end
	elseif command == ACQ_BIND.SSB or command == ACQ_BIND.BST then
		-- (v1.1: own switches) supersearch on the nose; FC3's boresight
		if down then acq_send(command == ACQ_BIND.SSB and "SS" or "BST") end
	elseif down then
		acq_send((command == ACQ_BIND.AFT) and "VS" or (command == ACQ_BIND.DEP) and "RTS" or "HM")
	end
	return true
end
local CD = {t = nil, long = false}      -- castle down held: since when, long press done
local function acq_tick(t)
	-- castle down held 1 s: one declutter step (the release then does nothing)
	if CD.t and not CD.long and now() - CD.t >= (SIT.CASTLE_LONG_S or 1.0) then
		CD.long = true
		if PWR.on and PWR.shown then hotas(SIT_HOTAS.DCLT) end
	end
	if CD.t and now() - CD.t > 10 then CD.t = nil end
	-- the long press: on its own once held long enough (no need to let go)
	if AQ.fwd_t and not AQ.fwd_long and now() - AQ.fwd_t >= (SIT.AACQ_LONG_S or 1.0) then
		AQ.fwd_long = true
		acq_send("LR")
	end
	-- (a stuck press, e.g. a lost release: forgotten after 10 s)
	if AQ.fwd_t and now() - AQ.fwd_t > 10 then AQ.fwd_t = nil end
	local c = feed.cur
	HACQ_P:set((c and now() - c.t < 1) and (c.acq or 0) or 0)
end

-- weapon select switch / missile reject: the export picks the weapon
-- (FC3 has only "weapon change" and "cannon": it presses them until the
-- asked kind is selected)
local WPN_NAME = {}
for k, v in pairs(WPN_BIND) do WPN_NAME[v] = k end
for k, v in pairs(TGT_BIND) do WPN_NAME[v] = "T" .. k end      -- (target step / unlock: same path)
local function wpn_bind(command, value)
	local what = WPN_NAME[command]
	if not what then return false end
	if PWR.on and (value or 0) > 0 then
		-- (target step / unlock slew the radar cursor: the radar takes it back first)
		if what:sub(1, 1) == "T" and ST.soi_sit then
			ST.soi_sit = false
			if SIT.SQUELCH_RADAR then to_export("F15SITQ,0,0,0") end
		end
		to_export("F15SITV," .. what)
		if log_n < 200 then log("weapon switch: " .. what) end
	end
	return true
end

function SetCommand(command, value)
	PGF.now = true
	if hmd_controls(command, value) then return end
	if acq_bind(command, value) then return end
	if wpn_bind(command, value) then return end
	-- binds come in as 6101-6115 (HOTAS) and 6121-6140 (display buttons):
	-- the F-15C does not pass 3xxx through from the controls; clicks still are 30xx
	if command >= 6101 and command <= 6120 or command == 6141 or command == 6142 then command = command - 3000
	elseif command >= 6121 and command <= 6140 then command = command - 3120 end
	-- the jet's electric power switch (a toggle; FC3 has no state for it)
	if PWR.cmd and command == PWR.cmd then
		if PWR.sw ~= nil then PWR.sw = not PWR.sw end
		if PWR.n_log < 10 then PWR.n_log = PWR.n_log + 1; log("electric power switch: " .. (PWR.sw and "on" or "off")) end
		return
	end
	-- the display's own knob and brightness rocker (work without power too)
	if command >= SIT_PANEL.MODE_CW and command <= SIT_PANEL.BRT_DN then
		if (value or 0) > 0 then
			if command == SIT_PANEL.MODE_CW then ST.mode = math.min(2, ST.mode + 1)
			elseif command == SIT_PANEL.MODE_CCW then ST.mode = math.max(0, ST.mode - 1)
			elseif command == SIT_PANEL.BRT_UP then ST.brt = math.min(SIT.BRT_STEPS, ST.brt + 1)
			else ST.brt = math.max(1, ST.brt - 1) end
		end
		return
	end
	-- v1.3 SIT lock: the jet's lock key while the SIT page has the cursor and
	-- a contact is hooked: the export slews the radar onto that contact and
	-- locks it (F15SITA,ST; the radar gets the cursor back). FC3 sees the key
	-- too; the export drops a lock that is not on the SIT contact.
	if SLEW.cmds and command == tonumber(SLEW.cmds.lock) then
		local L = SITLOCK.at
		if PWR.on and ST.soi_sit and ST.page == PG.SIT and L and now() - L.t < 1 then
			acq_send(string.format("ST,%.0f,%.0f,%.0f,%.1f,%.1f", L.x, L.y, L.z, L.vx, L.vz))
		end
		return
	end
	if slew_command(command, value) then return end
	-- no power: nothing of the add-on works; display off / starting up: its
	-- buttons and the page's HOTAS functions do nothing (radio, countermeasures
	-- and jettison binds still work while the jet has power)
	if not PWR.on then return end
	-- exterior light knobs (clicks): the jet's own light keys, pressed by the export
	if command == EXTLT_CMD.FORM or command == EXTLT_CMD.POS then
		if (value or 0) > 0 then to_export("F15SITK," .. (command == EXTLT_CMD.FORM and "acol_lt" or "nav_lt")) end
		return
	end
	-- front radio panel / IFF clicks
	if command >= RFP_CMD.CHAN_UP and command <= RFP_CMD.IP then rfp_command(command, value); return end
	-- SRS volume binds (UHF-1 / UHF-2 up / down)
	if command >= RAD_BIND.V1_UP and command <= RAD_BIND.V2_DN then
		if (value or 0) > 0 then
			rad_vol((command <= RAD_BIND.V1_DN) and 1 or 2, (command == RAD_BIND.V1_UP or command == RAD_BIND.V2_UP) and 1 or -1)
		end
		return
	end
	if command >= 3101 and command <= 3199 then
		local HS = SIT_HOTAS
		local page_fn = command == HS.CASTLE_UP or command == HS.CASTLE_DOWN or command == HS.CASTLE_LEFT or
			command == HS.CASTLE_RIGHT or command == HS.DCLT or command == HS.RNG_UP or command == HS.RNG_DN or
			command == HS.MARK or command == HS.MARK_DEL
		-- castle down: short = formation, held 1 s = declutter step (acq_tick)
		if command == HS.CASTLE_DOWN then
			if (value or 0) > 0 then
				if not CD.t then CD.t, CD.long = now(), false end
			elseif CD.t then
				if not CD.long and PWR.shown then hotas(command) end
				CD.t = nil
			end
			return
		end
		if (value or 0) > 0 and (PWR.shown or not page_fn) then hotas(command) end
		return
	end
	if not PWR.shown then return end
	local b = CMD2BTN[command]
	if not b or (value or 0) <= 0 then return end   -- act on press only
	local a = ACTIONS[ST.page] and ACTIONS[ST.page][b]
	if a then a() end
	if log_n < 60 then log("button " .. b) end
end

---------------------------------------------------------------------------
-- geometry
---------------------------------------------------------------------------
local G = {hdg = 0, k = 1, own_y = 0, ox = 0, oz = 0, c = 1, s = 0}
-- world offset (north, east, metres) -> page position relative to the ownship
-- (G.c / G.s: cos / sin of the heading, once per update; 1 / 0 north-up)
local function to_screen(dN, dE)
	local c, s, k = G.c, G.s, G.k
	return (dE * c - dN * s) * k, (dN * c + dE * s) * k
end
local function inside(sx, sy)
	return abs(sx + (G.own_x or 0)) <= SIT.BOX and abs(sy + G.own_y) <= SIT.BOX
end
-- clip a segment (relative to the ownship) to the box; nil if outside
-- (Liang-Barsky; no tables: it runs a few hundred times per update)
local function lb(p, q, t0, t1)
	if p == 0 then
		if q < 0 then return nil end
		return t0, t1
	end
	local r = q / p
	if p < 0 then
		if r > t1 then return nil elseif r > t0 then t0 = r end
	else
		if r < t0 then return nil elseif r < t1 then t1 = r end
	end
	return t0, t1
end
local function clip(x1, y1, x2, y2)
	local oy, ox = G.own_y, (G.own_x or 0)
	local B = SIT.BOX
	local ax, ay, bx, by = x1 + ox, y1 + oy, x2 + ox, y2 + oy
	-- both ends inside (the usual case): nothing to cut
	if abs(ax) <= B and abs(ay) <= B and abs(bx) <= B and abs(by) <= B then return x1, y1, x2, y2 end
	-- both beyond the same edge: nothing to draw
	if (ax < -B and bx < -B) or (ax > B and bx > B) or (ay < -B and by < -B) or (ay > B and by > B) then return nil end
	local dx, dy = bx - ax, by - ay
	local t0, t1 = 0, 1
	t0, t1 = lb(-dx, ax + B, t0, t1); if not t0 then return nil end
	t0, t1 = lb(dx, B - ax, t0, t1); if not t0 then return nil end
	t0, t1 = lb(-dy, ay + B, t0, t1); if not t0 then return nil end
	t0, t1 = lb(dy, B - ay, t0, t1); if not t0 then return nil end
	return ax + t0 * dx - ox, ay + t0 * dy - oy, ax + t1 * dx - ox, ay + t1 * dy - oy
end

local function brg_rng(dN, dE)
	local b = (floor(math.deg(atan2(dE, dN)) + 0.5) + 359) % 360 + 1
	return b, sqrt(dN * dN + dE * dE)
end

---------------------------------------------------------------------------
-- drawing
---------------------------------------------------------------------------
local CONTACT_COL = {[1] = 1, [2] = 2, [3] = 3, [4] = 1, [5] = 4, [6] = 1}   -- 1 green 2 red 3 yellow 4 blue

local IDENT = {[1] = "FRIEND", [2] = "HOSTILE", [3] = "UNKNOWN", [4] = "AWACS", [5] = "FLIGHT", [6] = "FRIEND"}
local TAKE, SKIP, NOMEM = {}, {}, {}
-- flight members (v0.9) and their contacts: each member takes the nearest
-- friendly / unknown contact within FLT_MATCH_M; any other such contact that
-- close is the same aircraft again (radar track + datalink report) and is
-- skipped. v1.3: both compared where they are NOW (contact and member moved
-- on along their velocity): a datalink contact can be seconds old (busy
-- missions reuse the last scan), the member's own position a second old, and
-- unmoved they missed each other - the helmet then showed the member twice
-- (its callsign and the contact's type on top of each other). A contact a
-- member took is never skipped (close formation, members in any order).
-- flag: the member field set to "has a contact" (shown / hm)
local function match_members(list, members, t, take, skip, flag)
	for k in pairs(take) do take[k] = nil end
	for k in pairs(skip) do skip[k] = nil end
	local R = SIT.FLT_MATCH_M
	local am = math.min(math.max(t - (feed.rx or t), 0), 20)
	for _, a in ipairs(members) do
		local axn, azn = a.x + (a.vx or 0) * am, a.z + (a.vz or 0) * am
		local best, bd = nil, R
		for i, c in ipairs(list) do
			local b = (c.code or 0) % 10
			if b ~= 2 and b ~= 4 then
				local age = math.min(math.max(t - (c.t or t), 0), c.mx or 20)
				local d = math.max(abs(c.x + (c.vx or 0) * age - axn), abs(c.z + (c.vz or 0) * age - azn))
				if d < R then
					skip[i] = true
					if d < bd and not take[i] then best, bd = i, d end
				end
			end
		end
		a[flag] = best ~= nil
		if best then take[best] = a end
	end
	for k in pairs(take) do skip[k] = nil end
end
local function draw_contacts(t, stale)
	local used = 0
	local list = EWR.merge(feed.list, t, stale)
	local members = stale and NOMEM or flt_members()
	-- flight members (v0.9): each takes the nearest friendly / unknown contact
	-- within FLT_MATCH_M; any other such contact that close is the same aircraft
	-- again (radar track + datalink report) and is not drawn. A member with
	-- no contact at all is drawn from its own position.
	match_members(list, members, t, TAKE, SKIP, "shown")
	-- hook: the contact nearest the cursor, within HOOK_R of it
	local hook, hook_d = nil, SIT.HOOK_R          -- (the hooked contact and its place, no table per update)
	local hk_x, hk_z, hk_sx, hk_sy, hk_code, hk_num
	do
		for ci, c in ipairs(list) do
			if used >= SIT.MAX_CONTACTS then break end
			local code = c.code or 0
			if SKIP[ci] then code = 0 end
			local own_radar = code >= 10
			local show = (own_radar and ST.rdr) or (code ~= 13 and ST.dl)
			if code == 15 or TAKE[ci] then show = true end          -- own flight always
			if code == 0 then show = false end
			if show then
				local age = math.min(math.max(t - (c.t or t), 0), c.mx or 20)
				local cx, cz = c.x + (c.vx or 0) * age, c.z + (c.vz or 0) * age
				-- a flight member: drawn as own flight (cyan), with its number
				local num = 0
				local mem = TAKE[ci]
				if mem then code, num = own_radar and 15 or 5, mem.num end
				local sx, sy = to_screen(cx - G.ox, cz - G.oz)
				if inside(sx, sy) then
					-- a contact only in the datalink while the DL layer is off,
					-- but held by the radar: draw it as a radar contact
					if not mem then
						if own_radar and not ST.dl then code = 13 end
						if not own_radar and not ST.dl then code = 0 end
					end
					if code > 0 then
						used = used + 1
						local h = HC[used]
						h.typ:set(code)
						h.x:set(sx)
						h.y:set(sy)
						local dx, dy = to_screen(c.vx or 0, c.vz or 0)
						h.hdg:set(atan2(-dx, dy))
						h.mov:set((((c.vx or 0) ^ 2 + (c.vz or 0) ^ 2) > 25) and 1 or 0)
						h.col:set(CONTACT_COL[code % 10] or 3)
						h.alt:set(floor((c.y or 0) / FT / 1000 + 0.5))
						h.num:set(num)
						if G.cur_sx then
							local dd = sqrt((sx - G.cur_sx) ^ 2 + (sy - G.cur_sy) ^ 2)
							if dd < hook_d then
								hook_d = dd
								hook, hk_x, hk_z, hk_sx, hk_sy, hk_code, hk_num = c, cx, cz, sx, sy, code, num
							end
						end
					end
				end
			end
		end
	end
	-- members with no contact: from their own position (F lines)
	for _, a in ipairs(members) do
		if not a.shown and used < SIT.MAX_CONTACTS then
			local sx, sy = to_screen(a.x - G.ox, a.z - G.oz)
			if inside(sx, sy) then
				used = used + 1
				local h = HC[used]
				h.typ:set(5); h.x:set(sx); h.y:set(sy)
				local dx, dy = to_screen(a.vx, a.vz)
				h.hdg:set(atan2(-dx, dy))
				h.mov:set(((a.vx ^ 2 + a.vz ^ 2) > 25) and 1 or 0)
				h.col:set(4); h.alt:set(floor(a.y / FT / 1000 + 0.5)); h.num:set(a.num)
			end
		end
	end
	for n = used + 1, SIT.MAX_CONTACTS do HC[n].typ:set(0) end
	-- hooked contact: data block (top left) and a cyan mark
	if hook then
		local c = hook
		local b, r = brg_rng(hk_x - G.ox, hk_z - G.oz)
		local v = sqrt((c.vx or 0) ^ 2 + (c.vz or 0) ^ 2)
		local id = IDENT[hk_code % 10] or "TRACK"
		if hk_num > 0 then id = "FLIGHT " .. hk_num end
		H.hk[1]:set(safe_text(id .. ((c.nm and c.nm ~= "") and ("  " .. c.nm:sub(1, 10)) or "")))
		H.hk[2]:set(string.format("%03d/%d NM", b, floor(r / NM + 0.5)))
		H.hk[3]:set(string.format("%dK  %d KT", floor((c.y or 0) / FT / 1000 + 0.5), floor(v * 1.94384 + 0.5)))
		local asp = "ASP ---"
		if v > 5 then
			local a = (math.deg(atan2(G.oz - hk_z, G.ox - hk_x) - atan2(c.vz, c.vx)) + 540) % 360 - 180
			asp = string.format("ASP %03d%s", floor(abs(a) + 0.5), a >= 0 and "R" or "L")
		end
		H.hk[4]:set(asp)
		H.hk_vis:set(1)
		H.hk_col:set(CONTACT_COL[hk_code % 10] or 3)
		H.hkm.x:set(hk_sx); H.hkm.y:set(hk_sy); H.hkm.vis:set(1)
		-- (v1.3 SIT lock: where the hooked contact is now, for the lock key)
		local L = SITLOCK.at or {}
		L.x, L.z, L.y, L.vx, L.vz, L.t = hk_x, hk_z, c.y or 0, c.vx or 0, c.vz or 0, t
		SITLOCK.at = L
	else
		H.hk_vis:set(0); H.hkm.vis:set(0)
		SITLOCK.at = nil
	end
end

local function draw_lock(t, stale)
	local L = (not stale) and feed.lock or nil
	if not L then H.lk.vis:set(0); H.lk.blk:set(0); H.pdt.vis:set(0); return end
	local age = math.min(math.max(t - L.t, 0), 5)
	local lx, lz = L.x + L.vx * age, L.z + L.vz * age
	local sx, sy = to_screen(lx - G.ox, lz - G.oz)
	H.lk.vis:set(inside(sx, sy) and 1 or 0)
	H.lk.x:set(sx); H.lk.y:set(sy)
	-- line from the ownship to the primary designated target
	local ax, ay, bx, by = clip(0, 0, sx, sy)
	if ax then
		-- (flashes with the fly-out line while a missile is in flight)
		H.pdt.vis:set((G.msl_fly and not G.msl_flash) and 0 or 1); H.pdt.ax:set(ax); H.pdt.ay:set(ay); H.pdt.bx:set(bx); H.pdt.by:set(by)
	else
		H.pdt.vis:set(0)
	end
	local dN, dE = lx - G.ox, lz - G.oz
	local b, r = brg_rng(dN, dE)
	-- aspect: angle between the target's course and the line target -> us
	local asp = "---"
	local v = sqrt(L.vx * L.vx + L.vz * L.vz)
	if v > 5 then
		local crs = atan2(L.vz, L.vx)
		local back = atan2(-dE, -dN)
		local a = (math.deg(back - crs) + 540) % 360 - 180
		asp = string.format("%03d%s", floor(abs(a) + 0.5), a >= 0 and "R" or "L")
	end
	H.lk.blk:set(1)
	H.lk.t1:set(string.format("%03d/%d", b, floor(r / NM + 0.5)))
	H.lk.t2:set(string.format("%dK", floor((L.y or 0) / FT / 1000 + 0.5)))
	H.lk.t3:set("ASP " .. asp)
end

-- the route in use: the loaded cartridge's, else the mission's (MSN). The
-- jet's active waypoint (mission route) also selects the cartridge's.
local function route_now() return ST.loaded.route or feed.wpts end
-- a cartridge route the jet also flies (Route Tool preset): every
-- cartridge point has a jet waypoint within 1 NM. map: jet index -> cartridge index
local LINK = {r = nil, w = nil, map = nil}
local function route_link()
	local r, w = ST.loaded.route, feed.wpts
	if not r then return nil end
	if LINK.r == r and LINK.w == w then return LINK.map end
	local map, hit = {}, 0
	for i, p in ipairs(r) do
		for j, q in ipairs(w or {}) do
			if not map[j] and (p.x - q.x) ^ 2 + (p.z - q.z) ^ 2 < 1852 * 1852 then map[j] = i; hit = hit + 1; break end
		end
	end
	LINK.r, LINK.w, LINK.map = r, w, (#r > 0 and hit == #r) and map or nil
	return LINK.map
end
-- the jet's active waypoint on the route the SIT shows
local function jet_active()
	local r = route_now()
	local a = feed.active or 0
	if r == feed.wpts then return a end
	local map = route_link()
	if map then return map[a] or 0 end
	return math.max(math.min(a, #r), #r > 0 and 1 or 0)
end
-- the SIT's active steerpoint: the jet's until WP+ / WP- (SIT page L1 / L2)
-- is pressed, then the SIT's own (the jet's waypoint is not touched);
-- back to the jet's when a cartridge (or MSN) is read
function active_now()
	local r = route_now()
	if not ST.sit_act then return jet_active() end
	if ST.sit_act > #r then ST.sit_act = #r end
	return ST.sit_act
end
function wp_step(dir)
	local r = route_now()
	if #r == 0 then return end
	local a = active_now()
	if a < 1 then a = (dir > 0) and 0 or 1 end
	ST.sit_act = (a - 1 + dir) % #r + 1
end
local ACT = {0, 0}
local function draw_route()
	G.act, G.act_txt = nil, ""
	local wpts, act = route_now(), active_now()
	local n = math.min(#wpts, SIT.MAX_WPTS)
	local px, py = nil, nil
	for i = 1, SIT.MAX_WPTS do
		local h = HW[i]
		local w = (ST.rte and ST.dcl < 2 and i <= n) and wpts[i] or nil
		if w then
			local sx, sy = to_screen(w.x - G.ox, w.z - G.oz)
			local active = (i == act)
			h.vis:set(inside(sx, sy) and (active and 2 or 1) or 0)
			h.x:set(sx); h.y:set(sy)
			h.num:set(floor(w.num or i))
			if px then
				local ax, ay, bx, by = clip(px, py, sx, sy)
				if ax then
					h.seg:set(1); h.ax:set(ax); h.ay:set(ay); h.bx:set(bx); h.by:set(by)
				else
					h.seg:set(0)
				end
			else
				h.seg:set(0)
			end
			px, py = sx, sy
			if active then
				ACT[1], ACT[2] = sx, sy
				G.act = ACT
				local b, r = brg_rng(w.x - G.ox, w.z - G.oz)
				G.act_txt = string.format("%03d-%d", b, floor(r / NM + 0.5))
			end
		else
			h.vis:set(0); h.seg:set(0)
		end
	end
end

local RING_C, RING_S = {}, {}
for j = 0, SIT.RING_SEGS do
	local a = TWO_PI * j / SIT.RING_SEGS
	RING_C[j], RING_S[j] = cos(a), sin(a)
end
local function draw_threats(stale)
	local used = 0
	if ST.thr and ST.dcl < 4 and not stale then
		for _, g in ipairs(feed.thr) do
			if used >= SIT.MAX_THREATS then break end
			used = used + 1
			local h = HG[used]
			local dN, dE = g.x - G.ox, g.z - G.oz
			local sx, sy = to_screen(dN, dE)
			h.vis:set(inside(sx, sy) and 1 or 0)
			h.x:set(sx); h.y:set(sy)
			h.txt:set(safe_text(g.lbl))
			local inring = g.ring > 0 and (dN * dN + dE * dE) < g.ring * g.ring
			h.ring:set(g.ring > 0 and (inring and 2 or 1) or 0)
			-- the ring's line only when some of it is on the SIT area: not when
			-- it lies all outside the area, nor when it goes all around it
			local draw = false
			if g.ring > 0 then
				local B, R = SIT.BOX, g.ring * G.k
				local cx, cy = abs(sx + (G.own_x or 0)), abs(sy + G.own_y)
				local nx, ny = math.max(cx - B, 0), math.max(cy - B, 0)
				draw = (nx * nx + ny * ny <= R * R) and ((cx + B) ^ 2 + (cy + B) ^ 2 >= R * R)
			end
			h.rv:set(draw and (inring and 2 or 1) or 0)
			if draw then
				local px, py = to_screen(dN + g.ring * RING_C[0], dE + g.ring * RING_S[0])
				for j = 1, SIT.RING_SEGS do
					local qx, qy = to_screen(dN + g.ring * RING_C[j], dE + g.ring * RING_S[j])
					local s = h.seg[j]
					local ax, ay, bx, by = clip(px, py, qx, qy)
					if ax then
						s.vis:set(1); s.ax:set(ax); s.ay:set(ay); s.bx:set(bx); s.by:set(by)
					else
						s.vis:set(0)
					end
					px, py = qx, qy
				end
			end
		end
	end
	for g = used + 1, SIT.MAX_THREATS do
		HG[g].vis:set(0); HG[g].ring:set(0); HG[g].rv:set(0)
	end
end

local function draw_scope()
	-- (scale: G.k)
	-- radar coverage: the edges of the radar's scan, out to its range scale
	local rd = feed.radar
	if (now() - feed.rx) > SIT.STALE_S then rd = nil end
	local fc = feed.cur
	if fc and now() - fc.t < 1 then rd = fc end          -- (same field names: on, az, size, dist)
	local half = rd and (SIT.RADAR_SIZE_HALF and rd.size or rd.size / 2) or 0
	for k = 1, 2 do
		local s = (k == 1) and -1 or 1
		local h = H.az[k]
		local ax = nil
		local ay, bx, by
		if rd and rd.on and ST.rdr and ST.dcl < 5 and (rd.dist or 0) > 0 then
			local b = G.hdg + (rd.az or 0) + s * half
			local x, y = to_screen(cos(b) * rd.dist, sin(b) * rd.dist)
			ax, ay, bx, by = clip(0, 0, x, y)
		end
		if ax then
			h.vis:set(1); h.ax:set(ax); h.ay:set(ay); h.bx:set(bx); h.by:set(by)
		else
			h.vis:set(0)
		end
	end
	-- the compass rose turns with the heading (heading-up)
	H.rot:set(ST.nup and 0 or G.hdg)
	-- north-up: the ownship symbol turns instead
	H.own_rot:set(ST.nup and -G.hdg or 0)
end

local function bull_now()
	if ST.loaded.bull then return ST.loaded.bull end
	local b = feed.bull
	return b and ((feed.coal == 1) and b.red or b.blue) or nil
end
local function draw_bull()
	local p = bull_now()
	if not p then
		H.be.vis:set(0); H.be.on:set(0); H.be.txt:set("")
		return
	end
	local sx, sy = to_screen(p[1] - G.ox, p[2] - G.oz)
	H.be.x:set(sx); H.be.y:set(sy)
	H.be.vis:set(inside(sx, sy) and 1 or 0)
	-- readout: the cursor from the bullseye (no cursor: own position from it)
	local cx, cz = G.cur_x or G.ox, G.cur_z or G.oz
	local brg, r = brg_rng(cx - p[1], cz - p[2])
	H.be.on:set(1)
	H.be.txt:set(string.format("%03d-%d", brg, floor(r / NM + 0.5)))
end

local INV_CL, INV_LETTER = {"a", "s", "m"}, {"A", "M", "S"}
local function draw_stores(stale)
	local s, cm = feed.stores, feed.cm
	if stale or not s or not cm then H.st_vis:set(0); H.master:set(""); return end
	H.st_vis:set(1)
	-- weapon inventory (v1.1): A AIM-120, M AIM-7, S AIM-9 - count + model
	-- letter of the selected one, else of the first loaded ("-": none
	-- left); G = gun rounds / 100. The selected one boxed.
	local cur = feed.sta and feed.sta[feed.cur_sta or 0]
	local cur_cl = cur and cur.n > 0 and store_class(cur.name)
	local sel = 0
	for k, cl in ipairs(INV_CL) do
		local n = s[cl] or 0
		local model = "-"
		if n > 0 then
			local nm = (cur_cl == cl) and cur.name or nil
			if not nm then
				for _, st in pairs(feed.sta or {}) do
					if st.n > 0 and store_class(st.name) == cl then nm = st.name; break end
				end
			end
			-- (what follows the number: AIM-120C -> C, AIM-7MH -> MH, AIM-9X -> X;
			-- at most 2 characters, else the last letter)
			local u = tostring(nm or ""):upper()
			local suf = u:match("AIM[%-_ ]?%d+%-?([%a%d]+)")
			model = (suf and suf ~= "" and suf:sub(1, 2)) or u:match("(%a)[^%a]*$") or "-"
		end
		local txt = INV_LETTER[k] .. n .. model
		H.inv[k]:set(txt)
		if not feed.gun and cur_cl == cl then sel = k * 10 + math.min(5, math.max(2, #txt)) end
	end
	local g = "G" .. floor((cm.gun or 0) / 100)
	H.inv[4]:set(g)
	if feed.gun then sel = 40 + math.min(4, math.max(2, #g)) end
	H.inv_sel:set(sel)
	H.chaff:set(cm.chaff or 0); H.flare:set(cm.flare or 0)
	H.master:set(safe_text(feed.master))
end

-- cursor: follows the VSD cursor (TDC). TDC y -1..1 = 0..range scale,
-- TDC x -1..1 = -+ the VSD's azimuth scale. Cyan readout = cursor from
-- the ownship (no cursor: active steerpoint), yellow = cursor from the bullseye
local function draw_cursor(stale)
	G.cur_x, G.cur_z, G.cur_sx, G.cur_sy = nil, nil, nil, nil
	if ST.soi_sit and ST.sc then
		-- SIT has the cursor: it moves on its own (TDC slew axis / binds)
		local dt = math.min(math.max(G.dt or 0.05, 0), 0.2)
		local rx, ry = SLEW.dz(SLEW.rx), SLEW.dz(SLEW.ry)
		-- SLEW_SCALE 1: crosses the SIT display as fast as the radar cursor
		-- crosses the radar display (about 0.93 of it per second at full stick)
		local spd = (SIT.SLEW_SCALE or 1) * 0.93 * 2 * SIT.BOX
		local px = (SLEW.kx + SLEW.dz(SLEW.ax) + rx) * spd * dt
		local py = (SLEW.ky + SLEW.dz(SLEW.ay) + ry) * spd * dt
		if px ~= 0 or py ~= 0 then
			-- page movement -> map movement (inverse of to_screen)
			local dE, dN
			if ST.nup then dE, dN = px, py
			else
				local c, s = cos(G.hdg), sin(G.hdg)
				dE, dN = px * c + py * s, py * c - px * s
			end
			ST.sc.n, ST.sc.e = ST.sc.n + dN / G.k, ST.sc.e + dE / G.k
		end
		local sx, sy = to_screen(ST.sc.n, ST.sc.e)
		-- keep it on the page
		local ax, ay = sx + (G.own_x or 0), sy + G.own_y
		local B = SIT.BOX - 0.03
		-- the range steps when the cursor is pushed into the top (out) or the
		-- bottom (in) edge, as the radar's range does
		if (ay > B and py > 0) or (ay < -B and py < 0) then
			local t = now()
			if t - (ST.bump_t or -10) > 0.7 then
				ST.bump_t = t
				local n = #SIT.RANGES_NM
				local r0 = ST.rng
				ST.rng = math.max(1, math.min(n, ST.rng + ((py > 0) and 1 or -1)))
				if ST.rng ~= r0 then ST.autor = false; ST.form = false; ST.exp = false end
			end
		end
		if abs(ax) > B or abs(ay) > B then
			ax, ay = math.max(-B, math.min(B, ax)), math.max(-B, math.min(B, ay))
			sx, sy = ax - (G.own_x or 0), ay - G.own_y
			local dE, dN
			if ST.nup then dE, dN = sx, sy
			else
				local c, s = cos(G.hdg), sin(G.hdg)
				dE, dN = sx * c + sy * s, sy * c - sx * s
			end
			ST.sc.n, ST.sc.e = dN / G.k, dE / G.k
		end
		G.cur_x, G.cur_z, G.cur_sx, G.cur_sy = G.ox + ST.sc.n, G.oz + ST.sc.e, sx, sy
		H.cur.x:set(sx); H.cur.y:set(sy); H.cur.vis:set(1); H.cur_sit:set(1)
		local brg, rr = brg_rng(ST.sc.n, ST.sc.e)
		H.stpt:set(string.format("%03d-%d", brg, floor(rr / NM + 0.5)))
		return
	end
	-- the 20 Hz cursor packet when it is fresh, else the once-a-second picture
	local fc = feed.cur
	local rd
	if fc and now() - fc.t < 1 then
		fc.scale_az = fc.saz            -- (the packet's names, as the picture's R line)
		rd = fc
	else rd = (not stale) and feed.radar or nil end
	if not rd or not rd.on or (rd.dist or 0) <= 0 then H.cur.vis:set(0); G.cur_s = nil; H.stpt:set(G.act_txt or ""); return end
	-- a little smoothing between packets (the window glides, no steps)
	local s = G.cur_s
	if s and abs(s.tx - rd.tx) < 0.3 and abs(s.ty - rd.ty) < 0.3 and s.dist == rd.dist then
		s.tx, s.ty = s.tx + (rd.tx - s.tx) * 0.6, s.ty + (rd.ty - s.ty) * 0.6
	else
		s = {tx = rd.tx, ty = rd.ty, dist = rd.dist}
		G.cur_s = s
	end
	local r = (s.ty + 1) / 2 * rd.dist
	local b = G.hdg + s.tx * rd.scale_az
	local cx, cz = G.ox + cos(b) * r, G.oz + sin(b) * r
	G.cur_x, G.cur_z = cx, cz
	local sx, sy = to_screen(cx - G.ox, cz - G.oz)
	G.cur_sx, G.cur_sy = sx, sy
	H.cur.x:set(sx); H.cur.y:set(sy)
	H.cur_sit:set(ST.soi_sit and 1 or 0)
	H.cur.vis:set(inside(sx, sy) and 1 or 0)
	local brg, rr = brg_rng(cx - G.ox, cz - G.oz)
	H.stpt:set(string.format("%03d-%d", brg, floor(rr / NM + 0.5)))
end

-- drawings (MENU: LINES): the loaded cartridge's .geo.txt, else the
-- mission's drawings of our side (MSN). 1 cyan (lines, areas), 2 red
-- (threat rings), 3 pink (suspected threat rings)
local GEO_C = {}
for j = 0, 24 do GEO_C[j] = {cos(TWO_PI * j / 24), sin(TWO_PI * j / 24)} end
-- (one piece: its two ends already on the page; n = pieces used so far)
local GEO = {n = 0, nl = 0}
local function geo_seg(ax, ay, bx, by, col)
	if GEO.n >= SIT.GEO_SEGS then return end
	local a1, a2, b1, b2 = clip(ax, ay, bx, by)
	if a1 then
		GEO.n = GEO.n + 1
		local h = H.geo[GEO.n]
		h.vis:set(col); h.ax:set(a1); h.ay:set(a2); h.bx:set(b1); h.by:set(b2)
	end
end
local function geo_label(x, z, txt, col)
	if GEO.nl >= SIT.GEO_LABELS or not txt or txt == "" then return end
	local sx, sy = to_screen(x - G.ox, z - G.oz)
	if not inside(sx, sy) then return end
	GEO.nl = GEO.nl + 1
	local h = H.gl[GEO.nl]
	h.x:set(sx); h.y:set(sy); h.vis:set(col); h.txt:set(safe_text(txt:upper():sub(1, 12)))
end
-- a shape's extent (metres), once: shapes far off the SIT area are skipped
local function geo_box(s)
	if s.bb then return s.bb end
	local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
	for j = 1, #s.x do
		local x, z = s.x[j], s.z[j]
		if x < x0 then x0 = x end; if x > x1 then x1 = x end
		if z < z0 then z0 = z end; if z > z1 then z1 = z end
	end
	if s.kw == "ring" then x0, x1, z0, z1 = x0 - s.r, x1 + s.r, z0 - s.r, z1 + s.r end
	s.bb = {x0, x1, z0, z1}
	return s.bb
end
local function draw_geo()
	local shapes = (ST.lines and ST.dcl < 2) and (ST.loaded.geo or feed.mgeo) or nil
	GEO.n, GEO.nl = 0, 0
	if shapes then
		-- the SIT area in metres around its centre (a circle around the square)
		local vr = SIT.BOX * 1.42 / G.k
		-- page centre (0,0) is -own_x, -own_y from the ownship on the page: back to metres
		local px, py = -(G.own_x or 0), -G.own_y
		local cN, cE = G.ox + (py * G.c - px * G.s) / G.k, G.oz + (px * G.c + py * G.s) / G.k
		for _, s in ipairs(shapes) do
			local bb = geo_box(s)
			local nx = math.max(bb[1] - cN, 0, cN - bb[2])
			local nz = math.max(bb[3] - cE, 0, cE - bb[4])
			if nx * nx + nz * nz <= vr * vr then
				if s.kw == "ring" then
					local col = s.dashed and 3 or 2
					local x0, z0, r = s.x[1], s.z[1], s.r
					local ax, ay = to_screen(x0 + r * GEO_C[0][1] - G.ox, z0 + r * GEO_C[0][2] - G.oz)
					for j = 1, 24 do
						local bx, by = to_screen(x0 + r * GEO_C[j][1] - G.ox, z0 + r * GEO_C[j][2] - G.oz)
						geo_seg(ax, ay, bx, by, col)
						ax, ay = bx, by
					end
					geo_label(x0, z0, s.name, col)
				else
					local fx, fy = to_screen(s.x[1] - G.ox, s.z[1] - G.oz)
					local ax, ay = fx, fy
					for j = 2, #s.x do
						local bx, by = to_screen(s.x[j] - G.ox, s.z[j] - G.oz)
						geo_seg(ax, ay, bx, by, 1)
						ax, ay = bx, by
					end
					if s.kw == "area" and #s.x > 2 then geo_seg(ax, ay, fx, fy, 1) end
					geo_label(s.x[1], s.z[1], s.name, 1)
				end
			end
		end
	end
	local n, nl = GEO.n, GEO.nl
	for j = n + 1, SIT.GEO_SEGS do H.geo[j].vis:set(0) end
	for b = 1, #H.gb do H.gb[b]:set((n >= (b - 1) * 16 + 1) and 1 or 0) end
	for k = nl + 1, SIT.GEO_LABELS do H.gl[k].vis:set(0) end
end

-- course line to the active steerpoint (MENU: CRS STR)
local function draw_crs()
	local h = H.crs_l
	local a = (ST.crs and ST.dcl < 2) and G.act or nil
	local ax, ay, bx, by = nil, nil, nil, nil
	if a then ax, ay, bx, by = clip(0, 0, a[1], a[2]) end
	if ax then
		h.vis:set(1); h.ax:set(ax); h.ay:set(ay); h.bx:set(bx); h.by:set(by)
	else
		h.vis:set(0)
	end
end

---------------------------------------------------------------------------
-- MENU pages
---------------------------------------------------------------------------
-- which pylon each export station is on. The export's station order is
-- not the jet's: matched by CLSID against the mission's pylons (hook), else
-- by store type (tanks 5 / 2 / 8, AIM-9 on the rails, AIM-120 / AIM-7 on
-- the fuselage first). A station keeps its pylon once found, so a station
-- that has fired (no name any more) stays where it was.
local FILL = {FUEL = {6, 2, 10}, SRM = {1, 11, 3, 9}, AMRM = {4, 8, 5, 7, 3, 9, 1, 11}, MRM = {5, 7, 4, 8, 3, 9}}
local category
local function slots()
	local map, used = feed.slot_map, {}
	if #feed.sta == 0 then return {}, {} end
	if feed.sta_n ~= #feed.sta then feed.sta_n = #feed.sta; feed.slot_map = {}; map = feed.slot_map end
	for _, n in pairs(map) do used[n] = true end
	local py = feed.pylons
	if py then
		for i, s in ipairs(feed.sta) do
			if not map[i] and s.cl ~= "" then
				for n = 1, #SIT.STATIONS do
					if not used[n] and py[n] == s.cl then map[i] = n; used[n] = true; break end
				end
			end
		end
	end
	for i, s in ipairs(feed.sta) do
		if not map[i] and s.n > 0 and s.name ~= "" then
			for _, n in ipairs(FILL[category(s.name)] or {}) do
				if not used[n] then map[i] = n; used[n] = true; break end
			end
		end
	end
	local out, of = {}, {}
	for i, n in pairs(map) do out[n] = feed.sta[i]; of[i] = n end
	return out, of
end


local MON = {"JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"}
-- store names (LoGetNameByType) -> PACS labels: AIM-120B -> 120B, AIM-9M -> 9M, tank -> FUEL
local function short_name(nm)
	nm = (nm or ""):upper()
	if nm == "" then return "" end
	if nm:find("FUEL") or nm:find("TANK") or nm:find("GAL") then return "FUEL" end
	local s = nm:match("AIM[%-_ ]?(%d+%a*)")
	if s then return s end
	s = nm:gsub("[^%w%-]", "")
	return s:sub(1, 6)
end
function category(nm)
	nm = (nm or ""):upper()
	if nm:find("120", 1, true) then return "AMRM" end
	if nm:find("AIM.?7") then return "MRM" end
	if nm:find("AIM.?9") then return "SRM" end
	if nm:find("FUEL") or nm:find("TANK") or nm:find("GAL") then return "FUEL" end
	return "STORE"
end
local function fmt_ll(v, pos, neg, degw)
	local hemi = (v >= 0) and pos or neg
	v = abs(v)
	local dg = floor(v)
	return string.format("%s %0" .. degw .. "d %06.3f", hemi, dg, (v - dg) * 60)
end
local function hms(s)
	s = math.max(0, floor(s))
	return string.format("%02d:%02d:%02d", floor(s / 3600) % 100, floor(s / 60) % 60, s % 60)
end
local function sd_val(name)
	local sd = sensors()
	local f = sd and sd[name]
	if not f then return nil end
	local ok, v = pcall(f)
	return ok and tonumber(v) or nil
end

local function page_armt(stale)
	local sl, of = slots()
	local cur = of[feed.cur_sta or 0] or 0
	for n = 1, #SIT.STATIONS do
		local s = sl[n]
		local h = H.sta[n]
		local nm = (s and s.n > 0) and short_name(s.name) or ""
		-- an empty wing pylon (2 / 8) still shows as PYLON
		if nm == "" and (n == 2 or n == 10) and feed.stores then nm = "PYLON" end
		h.txt:set(safe_text(nm))
		h.vis:set((nm == "") and 0 or ((n == cur and s and s.n > 0) and 2 or 1))
	end
	local s = sl[cur]
	local sel = (s and s.n > 0) and safe_text(category(s.name) .. " / " .. short_name(s.name)) or ""
	H.aa.sel:set(sel)
	H.aa.selvis:set(sel ~= "" and 1 or 0)
	local cm = feed.cm or {}
	H.aa.gun:set(cm.gun or 0); H.aa.chf:set(cm.chaff or 0); H.aa.flr:set(cm.flare or 0)
	local rd = (not stale) and feed.radar or nil
	H.aa.ics:set((rd and rd.ecm) and "ICS XMIT" or "ICS STBY")
	-- ICS bands: OFF (failed), JAM (jammer on), AUT (standing by in auto)
	local band = feed.fail.ECMFailure and "OFF" or ((rd and rd.ecm) and "JAM" or "AUT")
	for k = 1, 3 do H.aa_b[k]:set("B" .. k .. "  " .. band) end
	H.trng:set(ST.trng and 1 or 0); H.icsd:set(ST.icsd and 1 or 0)
end

local function page_jett()
	local sel, names = ST.jg[ST.jprog], {"L", "LC", "C", "RC", "R"}
	local list = {}
	for g = 1, 5 do
		H.jg[g]:set(sel[g] and 1 or 0)
		if sel[g] then list[#list + 1] = names[g] end
	end
	H.jprog:set(ST.jprog)
	local w = jett_what and jett_what() or nil
	H.jett:set("PROGRAM " .. ST.jprog .. ": " .. ((#list > 0) and table.concat(list, " ") or "NONE") ..
		((w == "tanks") and "  - TANKS" or (w == "weapons") and "  - ALL STORES" or ""))
end

local function page_load()
	local sl = slots()
	for n = 1, #SIT.STATIONS do
		local s = sl[n]
		local nm = (s and s.n > 0) and (s.name or "") or ""
		H.load[n]:set(string.format("STA %-3s %-14s %s", SIT.STATIONS[n], (nm ~= "") and nm:upper():sub(1, 14) or "----",
			(s and s.n > 0) and tostring(floor(s.n)) or ""))
	end
	local cm = feed.cm or {}
	H.load[#SIT.STATIONS + 1]:set(string.format("GUN   %d RDS  PGU-28", floor(cm.gun or 0)))
	H.load[#SIT.STATIONS + 2]:set(string.format("CHAFF %d   FLARE %d", floor(cm.chaff or 0), floor(cm.flare or 0)))
end

local function page_bit(t, stale)
	local testing = ST.bit_mode == 2 and (t - ST.ibit_t) < 6
	local bad = 0
	for n, row in ipairs(SIT.BIT_ROWS) do
		local nogo = false
		for k = 2, #row do if feed.fail[row[k]] then nogo = true end end
		if nogo then bad = bad + 1 end
		H.bit[n]:set(testing and 0 or (nogo and 2 or 1))
	end
	H.bit_mode:set(ST.bit_mode)
	if testing then H.bit_txt:set("IBIT IN PROGRESS")
	elseif stale then H.bit_txt:set((ST.bit_mode == 2 and "IBIT" or "CBIT") .. ": NO DATA")
	elseif bad == 0 then H.bit_txt:set((ST.bit_mode == 2 and "IBIT" or "CBIT") .. ": ALL GO")
	else H.bit_txt:set((ST.bit_mode == 2 and "IBIT" or "CBIT") .. ": " .. bad .. " NO GO") end
end

local function page_time(t)
	local tod = G.tod or 0
	local dt = feed.date
	local off = dt and SIT.UTC_OFFSET[dt.th]
	H.td[1]:set("LOCAL    " .. hms(tod % 86400))
	H.td[2]:set(off and ("ZULU     " .. hms((tod - off * 3600) % 86400) .. "Z") or "ZULU     --:--:--")
	local date_txt = "DATE     ----"
	if dt and dt.year > 0 then
		local ok, s = pcall(function()
			local d = os.date("*t", os.time({year = dt.year, month = dt.mon, day = dt.day + floor(tod / 86400), hour = 12}))
			return string.format("DATE     %02d %s %04d", d.day, MON[d.month] or "---", d.year)
		end)
		if ok and s then date_txt = s end
	end
	H.td[3]:set(date_txt)
	H.td[4]:set("ELAPSED  " .. hms(t))
	H.td[5]:set("MAP      " .. ((dt and dt.th ~= "") and dt.th:upper() or "----"))
	H.td[6]:set(off and string.format("UTC %+.1f H", off) or "")
	H.zulu:set(ST.zulu and 1 or 0)
end

-- RADIO (MENU, top 2): UHF-1 (mission comms) and UHF-2 (flight) side by
-- side, 20 preset channels each. Picking a channel tunes SRS (its UDP
-- command port, FREQUENCY_SET) - SRS tunes FC3 radios itself. Presets: the
-- cartridge's, else the mission's for this slot; a channel's frequency can
-- be changed here (EDIT), kept until a cartridge is loaded.
local RAD_MIN, RAD_MAX = 225, 399.975
local function rad_list(r)
	if ST.rad_lists and ST.rad_lists[r] then return ST.rad_lists[r] end
	local m = feed.radio and feed.radio.radios[r]
	local out = {}
	for k, s in ipairs(m or {}) do
		local f = tonumber(tostring(s):match("^([%d%.]+)"))
		out[k] = f and {f = f, n = ""} or nil
	end
	return out
end
local function rad_own(r)
	ST.rad_lists = ST.rad_lists or {}
	if not ST.rad_lists[r] then
		local src, cp = rad_list(r), {}
		for k = 1, 20 do if src[k] then cp[k] = {f = src[k].f, n = src[k].n} end end
		ST.rad_lists[r] = cp
	end
	return ST.rad_lists[r]
end
function srs_set(r, f)
	if not (udp and f) then return end
	local msg = string.format('{"RadioId":%d,"Frequency":%.3f,"Command":12}', r, f)
	pcall(function() udp:sendto(msg, "127.0.0.1", SIT.SRS_PORT) end)
	ST.rad_sent = ST.rad_sent or {}
	ST.rad_sent[r] = f
	if (ST.rad_n or 0) < 10 then ST.rad_n = (ST.rad_n or 0) + 1; log(string.format("SRS: radio %d -> %.3f", r, f)) end
end
-- volume: SRS SET_VOLUME (command 5, 0..1) for radio r. SRS does not report
-- its volume back: the page shows the last value sent from here.
local function srs_vol(r)
	if not udp then return end
	local msg = string.format('{"RadioId":%d,"Volume":%.2f,"Command":5}', r, ST.vol[r] / 100)
	pcall(function() udp:sendto(msg, "127.0.0.1", SIT.SRS_PORT) end)
	if (ST.rad_n or 0) < 10 then ST.rad_n = (ST.rad_n or 0) + 1; log(string.format("SRS: radio %d volume %d%%", r, ST.vol[r])) end
end
function rad_vol(r, dir)
	ST.vol[r] = math.max(0, math.min(100, ST.vol[r] + dir * (SIT.SRS_VOL_STEP or 5)))
	srs_vol(r)
end
-- start volume: sent a few seconds after the cockpit starts (SRS connected by then)
local VOL_T = {sent = false, t0 = nil}
-----------------------------------------------------------------------
-- v1.1: front UHF-1 radio panel (centre panel) and IFF MODE 3/A
-- UHF-1 mode (the panel's mode knob): 1 CHAN (the preset), 2 MAN (the
-- frequency knobs), 3 GUARD (243.000). IFF mode 3/A code: four octal
-- wheels, sent to SRS (TRANSPONDER_M3_CODE; SRS uses it when its IFF is
-- run from the overlay, as for FC3 aircraft); I/P = IDENT for 18 s.
-- Code and manual frequency kept in Saved Games\DCS\Config\F15SIT_rfp.txt
-----------------------------------------------------------------------
local RFP_FILE = "Config/F15SIT_rfp.txt"
local RFP = {ident_t = nil, loaded = false}
local function rfp_path()
	local ok, l = pcall(require, "lfs")
	return ok and l and (l.writedir() .. RFP_FILE) or nil
end
local function rfp_load()
	RFP.loaded = true
	ST.r1_mode, ST.r1_man, ST.m3 = ST.r1_mode or 1, ST.r1_man or 251.0, ST.m3 or {1, 2, 0, 0}
	local fn = rfp_path()
	local f = fn and io.open(fn, "r")
	if not f then return end
	for raw in f:lines() do
		local k, v = raw:match("^(%w+)=([%d%.]+)")
		if k == "M3" and #v == 4 then for i = 1, 4 do ST.m3[i] = math.min(7, tonumber(v:sub(i, i)) or 0) end
		elseif k == "MAN" and tonumber(v) then ST.r1_man = tonumber(v) end
	end
	f:close()
end
local function rfp_save()
	local fn = rfp_path()
	local f = fn and io.open(fn, "w")
	if not f then return end
	f:write("M3=" .. table.concat(ST.m3) .. "\nMAN=" .. string.format("%.3f", ST.r1_man) .. "\n")
	f:close()
end
local function srs_cmd(json)
	if not udp then return end
	pcall(function() udp:sendto(json, "127.0.0.1", SIT.SRS_PORT) end)
	if (ST.rad_n or 0) < 20 then ST.rad_n = (ST.rad_n or 0) + 1; log("SRS: " .. json) end
end
local function iff_send_m3()
	srs_cmd(string.format('{"Command":8,"Code":%d}', tonumber(table.concat(ST.m3)) or 0))
end
-- the frequency UHF-1 is on, by its mode
function rfp_freq()
	if not RFP.loaded then rfp_load() end
	if ST.r1_mode == 3 then return 243.0 end
	if ST.r1_mode == 2 then return ST.r1_man end
	local c = rad_list(1)[ST.rch[1]]
	return c and c.f or nil
end
function preset_tune(r, f)
	if r == 1 and (ST.r1_mode or 1) ~= 1 then return end    -- (UHF-1 on MAN / GUARD: the preset waits)
	srs_set(r, f)
end
local function man_step(df)
	if ST.r1_mode ~= 2 then ST.r1_man = rfp_freq() or ST.r1_man; ST.r1_mode = 2 end
	local f = ST.r1_man + df
	if f > 399.9875 then f = f - 175 elseif f < 224.9875 then f = f + 175 end
	ST.r1_man = floor(f / 0.025 + 0.5) * 0.025
	srs_set(1, ST.r1_man)
	rfp_save()
end
-- a click on the panel (pressed: value > 0)
function rfp_command(cmd, value)
	if (value or 0) <= 0 then return end
	if not RFP.loaded then rfp_load() end
	local C = RFP_CMD
	if cmd == C.CHAN_UP or cmd == C.CHAN_DN then rad_step(1, cmd == C.CHAN_UP and 1 or -1)
	elseif cmd == C.F1_UP or cmd == C.F1_DN then man_step(cmd == C.F1_UP and 10 or -10)
	elseif cmd == C.F2_UP or cmd == C.F2_DN then man_step(cmd == C.F2_UP and 1 or -1)
	elseif cmd == C.F3_UP or cmd == C.F3_DN then man_step(cmd == C.F3_UP and 0.025 or -0.025)
	elseif cmd == C.VOL_UP or cmd == C.VOL_DN then rad_vol(1, cmd == C.VOL_UP and 1 or -1)
	elseif cmd == C.MODE_CW or cmd == C.MODE_CCW then
		local m = math.max(1, math.min(3, ST.r1_mode + (cmd == C.MODE_CW and 1 or -1)))
		if m ~= ST.r1_mode then
			ST.r1_mode = m
			local f = rfp_freq()
			if f then srs_set(1, f) end
		end
	elseif cmd == C.IP then
		srs_cmd('{"Command":10,"Enabled":true}')
		RFP.ident_t = now()
	else
		for k = 1, 4 do
			if cmd == C["W" .. k .. "_UP"] or cmd == C["W" .. k .. "_DN"] then
				ST.m3[k] = (ST.m3[k] + (cmd == C["W" .. k .. "_UP"] and 1 or -1)) % 8
				iff_send_m3()
				rfp_save()
			end
		end
	end
end
-- the drums: CHAN, MAIN FREQ, MODE 3/A (numbers; -1 = blank)
local HR = {ch = {P("RFP_CH1"), P("RFP_CH2")}, f = {}, m = {}}
for k = 1, 6 do HR.f[k] = P("RFP_F" .. k) end
for k = 1, 4 do HR.m[k] = P("RFP_M" .. k) end
local function rfp_draw()
	if not RFP.loaded then rfp_load() end
	local ch = ST.rch[1] or 1
	HR.ch[1]:set(floor(ch / 10)); HR.ch[2]:set(ch % 10)
	local f = rfp_freq()
	local s = f and string.format("%07.3f", f) or nil
	local idx = {1, 2, 3, 5, 6, 7}
	for k = 1, 6 do HR.f[k]:set(s and (tonumber(s:sub(idx[k], idx[k])) or 0) or -1) end
	for k = 1, 4 do HR.m[k]:set(ST.m3[k]) end
end
function srs_vol_tick(t)
	if RFP.ident_t and t - RFP.ident_t > 18 then RFP.ident_t = nil; srs_cmd('{"Command":10,"Enabled":false}') end
	rfp_draw()
	if VOL_T.sent then return end
	VOL_T.t0 = VOL_T.t0 or t
	if t - VOL_T.t0 >= 3 then VOL_T.sent = true; srs_vol(1); srs_vol(2); if not RFP.loaded then rfp_load() end; iff_send_m3() end
end
function rad_step(r, dir)
	ST.rch[r] = (ST.rch[r] - 1 + dir) % 20 + 1
	local c = rad_list(r)[ST.rch[r]]
	if c then preset_tune(r, c.f) end
end
function rad_edit_key(k)
	local e = ST.redit
	if not e then return end
	if k == "L" then e.pos = math.max(1, e.pos - 1)
	elseif k == "R" then e.pos = math.min(6, e.pos + 1)
	elseif k == "+" or k == "-" then
		local dg = tonumber(e.dig:sub(e.pos, e.pos)) + ((k == "+") and 1 or -1)
		dg = dg % ((e.pos == 1) and 4 or 10)
		e.dig = e.dig:sub(1, e.pos - 1) .. dg .. e.dig:sub(e.pos + 1)
	elseif k == "E" then
		local f = tonumber(e.dig:sub(1, 3) .. "." .. e.dig:sub(4, 6))
		if not f or f < RAD_MIN or f > RAD_MAX then e.msg = "OUT OF RANGE 225-399.975"; return end
		local list = rad_own(e.r)
		list[e.ch] = {f = f, n = (list[e.ch] and list[e.ch].n) or ""}
		if ST.rch[e.r] == e.ch then preset_tune(e.r, f) end
		ST.redit = nil
	end
end
function rad_edit(r)
	if ST.redit and ST.redit.r == r then ST.redit = nil; return end
	local c = rad_list(r)[ST.rch[r]]
	ST.redit = {r = r, ch = ST.rch[r], pos = 1, dig = string.format("%07.3f", c and c.f or 251):gsub("%.", "")}
end
local function page_radio()
	for r = 1, 2 do
		local list = rad_list(r)
		for k = 1, 20 do
			local c = list[k]
			H.rad[r][k]:set(c and string.format("%02d %7.3f %s", k, c.f, (c.n or ""):upper():sub(1, 8)) or string.format("%02d   -.---", k))
		end
		H.rad_act[r]:set(ST.rch[r])
		H.rad_vol[r]:set(string.format("VOL %d", ST.vol[r]))
		local c = list[ST.rch[r]]
		if r == 1 and (ST.r1_mode or 1) ~= 1 then
			H.rad_cur[r]:set(string.format("%s %7.3f", ST.r1_mode == 2 and "MAN  " or "GUARD", rfp_freq()))
		else
			H.rad_cur[r]:set(c and string.format("CH%02d %7.3f", ST.rch[r], c.f) or string.format("CH%02d  NONE", ST.rch[r]))
		end
	end
	local e = ST.redit
	H.rad_edit:set(e and e.r or 0)
	if e then
		local s = e.dig:sub(1, 3) .. "." .. e.dig:sub(4, 6)
		H.rad_etxt:set(string.format("UHF-%d CH%02d  %s", e.r, e.ch, s))
		local col = 12 + e.pos + ((e.pos > 3) and 1 or 0)
		H.rad_ecar:set(string.rep(" ", col - 1) .. "^" .. string.rep(" ", 22 - col))
		H.rad_emsg:set(e.msg or "")
	else
		H.rad_etxt:set(""); H.rad_ecar:set(""); H.rad_emsg:set("")
	end
	H.rad_src:set((ST.rad_lists and (ST.rad_lists[1] or ST.rad_lists[2])) and "PRESETS: CARTRIDGE / EDITED" or (feed.radio and "PRESETS: MISSION" or "NO PRESETS YET"))
end

local function page_own()
	local o = feed.own
	local fuel = sd_val("getTotalFuelWeight")
	local alt = sd_val("getBarometricAltitude")
	local ias = sd_val("getIndicatedAirSpeed")
	local mach = sd_val("getMachNumber")
	local okm, mh = pcall(function() return sensors().getMagneticHeading() end)
	local rows = {
		"CALLSIGN " .. ((o and o.unit ~= "") and o.unit:sub(1, 18) or "----"),
		"PILOT    " .. ((o and o.pilot ~= "") and o.pilot:sub(1, 18) or "----"),
		"TN       " .. ((ST.loaded.tn and ST.loaded.tn:sub(1, 5)) or (o and string.format("%05o", (floor(o.id) % 32749 + floor(o.id / 32768) * 7 + 1) % 32768)) or "-----"),
		"LAT      " .. (o and fmt_ll(o.lat, "N", "S", 2) or "----"),
		"LON      " .. (o and fmt_ll(o.lon, "E", "W", 3) or "----"),
		"ALT      " .. (alt and string.format("%d FT", floor(alt / FT + 0.5)) or "----"),
		"HDG      " .. ((okm and mh) and string.format("%03d M", (floor(math.deg(mh) + 0.5) - 1) % 360 + 1) or "----"),
		"IAS      " .. (ias and string.format("%d KT", floor(ias * 1.94384 + 0.5)) or "----") ..
			(mach and string.format("   M %.2f", mach) or ""),
		"FUEL     " .. (fuel and string.format("%.1f K LB", fuel * 2.20462 / 1000) or "----"),
		"BULL     " .. ((H.be.on:get() or 0) > 0 and "" or "----"),
		"STPT     " .. "",
	}
	local b = bull_now()
	if b then
		local brg, r = brg_rng(G.ox - b[1], G.oz - b[2])
		rows[10] = string.format("BULL     %03d/%d", brg, floor(r / NM + 0.5))
	end
	local w = route_now()[active_now()]
	if w then
		local brg, r = brg_rng(w.x - G.ox, w.z - G.oz)
		rows[11] = string.format("STPT %-3d %03d/%d", floor(w.num or 0), brg, floor(r / NM + 0.5))
	else
		rows[11] = "STPT     ----"
	end
	for n = 1, #H.own do H.own[n]:set(safe_text(rows[n] or "")) end
end

local function page_flt()
	local sl, sel = slots_now(), ST.fsel
	-- L1..L5: friendly aircraft, their slot number in front, boxed = picked
	local cand = flt_candidates()
	local pages = math.max(1, math.ceil(#cand / 5))
	if ST.flt_page >= pages then ST.flt_page = pages - 1 end
	for k = 1, 5 do
		local a = cand[ST.flt_page * 5 + k]
		local n = a and slot_of(a.unit)
		H.fc[k].txt:set(a and safe_text((n and tostring(n) or "-") .. " " .. a.unit:sub(1, 13) .. (a.human and "*" or "")) or "")
		H.fc[k].on:set((a and sel and sel.c == a.unit) and 1 or 0)
	end
	H.fc_pg:set(#cand == 0 and "NO FRIENDLIES" or safe_text(string.format("PAGE %d/%d", ST.flt_page + 1, pages)))
	-- R1..R4: the slots
	for k = 1, 4 do
		local v, h = sl[k], H.fs[k]
		h.own:set(v == "OWN" and 1 or 0)
		h.sel:set((sel and sel.s == k) and 1 or 0)
		h.empty:set(v and 0 or 1)
		if v == "OWN" then
			local nm = own_name()
			h.n:set(safe_text(nm ~= "" and nm:sub(1, 18) or "OWNSHIP"))
			local alt, ias = sd_val("getBarometricAltitude"), sd_val("getIndicatedAirSpeed")
			h.d:set(safe_text("OWNSHIP   " .. (alt and string.format("%dK", floor(alt / FT / 1000 + 0.5)) or "") ..
				(ias and string.format("   %d KIAS", floor(ias * 1.94384 + 0.5)) or "")))
		elseif v then
			h.n:set(safe_text(v:sub(1, 18)))
			local a = flt_find(v)
			if a then
				local b, r = brg_rng(a.x - G.ox, a.z - G.oz)
				local gs = sqrt(a.vx * a.vx + a.vz * a.vz) * 1.94384
				h.d:set(safe_text(string.format("%03d/%d NM   %dK   %d KT", b, floor(r / NM + 0.5), floor(a.y / FT / 1000 + 0.5), floor(gs + 0.5))))
			else
				h.d:set("NOT ON THE DATALINK")
			end
		else
			h.n:set("EMPTY"); h.d:set("")
		end
	end
	H.fmode:set(ST.slot_man and 0 or 1)
	local hint
	if sel and sel.c then hint = safe_text(sel.c:sub(1, 14) .. ": PRESS A SLOT")
	elseif sel and sel.s then hint = "SLOT " .. sel.s .. ": SLOT OR AIRCRAFT, CLR"
	elseif ST.fhint and now() - (ST.fhint_t or -10) < 3 then hint = ST.fhint
	else hint = "PICK AN AIRCRAFT, THEN A SLOT" end
	H.fhint:set(hint)
end

local function draw_pages(t, stale)
	H.cmd:set("CMD" .. SIT.CMD_PROGRAMS[ST.cmd])
	H.pf:set(SIT.PF_MESSAGES[ST.pf])
	H.crs:set(ST.crs and 1 or 0)
	H.ics_fail:set(feed.fail.ECMFailure and 1 or 0)
	local pg = ST.page
	-- the MENU pages' texts 5 times a second (they hardly change); at once
	-- after a button press or a page change
	if not PGF.now and pg == PGF.last and tick % 4 ~= 0 then return end
	PGF.now, PGF.last = false, pg
	if pg == PG.DTM then
		H.dtm_cart:set(safe_text(string.format("CARTRIDGE %s  (%d/%d)", dtm_name(ST.cart):upper():sub(1, 16), ST.cart, #(ST.carts or {}) + 1)))
		H.dtm_loaded:set(safe_text("LOADED " .. tostring(ST.loaded.name):upper():sub(1, 16)))
	elseif pg == PG.ARMT then page_armt(stale)
	elseif pg == PG.JETT then page_jett()
	elseif pg == PG.LOAD then page_load()
	elseif pg == PG.BIT then page_bit(t, stale)
	elseif pg == PG.TIME then page_time(t)
	elseif pg == PG.OWN then page_own()
	elseif pg == PG.FLT then page_flt()
	elseif pg == PG.CMDS then page_cmds()
	elseif pg == PG.RADIO then page_radio() end
end

-- formation: smallest range step that shows every own-flight member
local function form_range()
	local far = 0
	for _, c in ipairs(feed.list) do
		if (c.code or 0) % 10 == 5 then
			local d = sqrt((c.x - G.ox) ^ 2 + (c.z - G.oz) ^ 2)
			if d > far then far = d end
		end
	end
	if far <= 0 then return nil end
	for i, r in ipairs(SIT.RANGES_NM) do
		if r * NM >= far * 1.15 then return i end
	end
	return #SIT.RANGES_NM
end

---------------------------------------------------------------------------
-- every text parameter must hold a string before the page is drawn: the
-- page prints them with "%s", and DCS crashes (access violation in
-- ceStringPoly) on a parameter that is still the number 0
local function init_texts()
	for _, k in ipairs({"time", "status", "stpt", "master", "net", "dtm"}) do H[k]:set("") end
	H.be.txt:set("")
	for _, h in ipairs(ALL_TEXT) do h:set("") end
	H.lk.t1:set(""); H.lk.t2:set(""); H.lk.t3:set("")
	for g = 1, SIT.MAX_THREATS do HG[g].txt:set("") end
end
init_texts()        -- at load already, before the first frame

function post_initialize()
	init_texts()
	log("=== F-15C SIT 1.3, aircraft " .. tostring(get_aircraft_type and get_aircraft_type()))
	for name, cmd in pairs(SIT_CMD) do dev:listen_command(cmd) end
	for name, cmd in pairs(SIT_HOTAS) do dev:listen_command(cmd) end
	for name, cmd in pairs(SIT_PANEL) do dev:listen_command(cmd) end
	for cmd = 3110, 3115 do dev:listen_command(cmd) end
	for cmd = 6101, 6120 do dev:listen_command(cmd) end
	dev:listen_command(6141); dev:listen_command(6142)   -- mark / delete mark   -- bound HOTAS (see SetCommand)
	for cmd = 6121, 6140 do dev:listen_command(cmd) end   -- bound display buttons
	for _, cmd in pairs(HMD_PANEL) do dev:listen_command(cmd) end   -- JHMCS knob (clicks)
	for _, cmd in pairs(HMD_BIND) do dev:listen_command(cmd) end    -- JHMCS binds
	for _, cmd in pairs(ACQ_BIND) do dev:listen_command(cmd) end    -- auto acq switch, helmet acquisition
	for _, cmd in pairs(WPN_BIND) do dev:listen_command(cmd) end    -- weapon select switch, missile reject
	for _, cmd in pairs(TGT_BIND) do dev:listen_command(cmd) end    -- target step, unlock
	for _, cmd in pairs(RAD_BIND) do dev:listen_command(cmd) end    -- SRS volume
	for _, cmd in pairs(RFP_CMD) do dev:listen_command(cmd) end     -- front radio panel, IFF
	for _, cmd in pairs(EXTLT_CMD) do dev:listen_command(cmd) end   -- exterior light knobs
	-- the jet's radar slew commands (numbers from Logs\f15sit_icmd.lua, written
	-- by the add-on's block in the F-15C's controls file): do they reach us?
	pcall(function()
		local l = require("lfs")
		local f = loadfile(l.writedir() .. "Logs/f15sit_icmd.lua")
		local c = f and f()
		if type(c) == "table" then
			SLEW.cmds = c
			local s = {}
			for _, k in ipairs({"sel_h", "sel_v", "axis_h", "axis_v", "axis_h_abs", "axis_v_abs", "zoom_in", "zoom_out", "lock"}) do
				if tonumber(c[k]) then dev:listen_command(c[k]); s[#s + 1] = k .. "=" .. c[k] end
			end
			log("listening to the radar slew commands: " .. table.concat(s, " "))
		else
			log("no Logs/f15sit_icmd.lua: radar slew commands not known")
		end
	end)
	-- the jet's electric power switch: its number from the controls block, else the usual one
	PWR.cmd = (SLEW.cmds and tonumber(SLEW.cmds.power)) or SIT.POWER_CMD
	if PWR.cmd then dev:listen_command(PWR.cmd) end
	open_udp()
	pcall(flt_load)
	-- Options > Special > F-15C SIT: timing and debug logs
	pcall(function()
		local l = require("lfs")
		local f = loadfile(l.writedir() .. "Config/options.lua")
		if not f then return end
		local env = {}
		setfenv(f, env)
		f()
		local p = env.options and env.options.plugins and env.options.plugins["f15c_sit"]
		PF.on = type(p) == "table" and p.f15c_sit_logs == true
	end)
	if PF.on then log("timing log on: Logs/f15sit_perf.log") end
	log("UDP " .. udp_state .. " on " .. SIT.PORT)
end

-- countermeasure programs / jettison: asked of the export (it presses
-- the jet's keys); see F15SIT_Export.lua
function to_export(msg)
	if udp then pcall(function() udp:sendto(msg, "127.0.0.1", 42890) end) end
end
local function cmd_dispense()
	local name = SIT.CMD_PROGRAMS[ST.cmd]
	local p = (ST.cmd_def and ST.cmd_def[name]) or SIT.CMD_DEF[name]
	if not p then return end
	to_export(string.format("F15SITX,%d,%d,%.2f,%d", p[1], p[2], p[3], p[4]))
	ST.cmd_t = now()
end
-- combat jettison: FC3 jettisons either all stores or the fuel tanks, so a
-- program whose loaded stations hold only tanks drops the tanks, any other
-- drops everything
local JETT_STA = {{1, 2, 3}, {4, 5}, {6}, {7, 8}, {9, 10, 11}}
jett_what = function()
	local sl = slots()
	local sel, any, only_tanks = ST.jg[ST.jprog], false, true
	for g = 1, 5 do
		if sel[g] then
			for _, n in ipairs(JETT_STA[g]) do
				local s = sl[n]
				if s and s.n > 0 then any = true; if category(s.name) ~= "FUEL" then only_tanks = false end end
			end
		end
	end
	if not any then return nil end
	return only_tanks and "tanks" or "weapons"
end
-- castle switch (after the real jet, redflagsim.com F-15C MPCD docs):
--   up     VSD has the cursor: SIT takes it (SIT page shown); SIT has it: back to the VSD
--   right  VSD: A/A page; SIT: decenter
--   left   A/A page: back to SIT; SIT: EXP (10 NM around the cursor)
--   down   SIT: formation (F5); held 1 s: declutter step
hotas = function(cmd)
	local HS = SIT_HOTAS
	if cmd == HS.CASTLE_UP then
		ST.soi_sit = not ST.soi_sit
		if ST.soi_sit then
			ST.page = PG.SIT
			-- the SIT cursor starts where the radar cursor is (else 10 NM ahead)
			if G.cur_x then ST.sc = {n = G.cur_x - G.ox, e = G.cur_z - G.oz}
			else ST.sc = {n = cos(G.hdg) * 10 * NM, e = sin(G.hdg) * 10 * NM} end
		end
		if SIT.SQUELCH_RADAR then
			to_export(ST.soi_sit and "F15SITQ,1" or string.format("F15SITQ,0,%.4f,%.4f", SLEW.raw_h or 0, SLEW.raw_v or 0))
			ST.q_t = now()
		end
		log("castle up: SIT cursor " .. (ST.soi_sit and "on" or "off"))
	elseif cmd == HS.CASTLE_RIGHT then
		if ST.soi_sit then ST.center = not ST.center; ST.exp = false
		else ST.page = PG.ARMT end
	elseif cmd == HS.CASTLE_LEFT then
		if ST.page == PG.ARMT then ST.page = PG.SIT
		elseif ST.soi_sit then ST.exp = not ST.exp; ST.form = false end
	elseif cmd == HS.CASTLE_DOWN then
		if ST.soi_sit then ST.form = not ST.form; ST.exp = false end
	elseif cmd == HS.DCLT then
		dcl_step()
	elseif cmd == HS.MARK then
		-- a mark at the cursor (SIT or radar cursor), else under us
		local x, z = G.cur_x or G.ox, G.cur_z or G.oz
		ST.mark_n = (ST.mark_n or 0) % 99 + 1
		table.insert(ST.marks, 1, {x = x, z = z, n = ST.mark_n})
		while #ST.marks > SIT.MAX_MARKS do table.remove(ST.marks) end
		log(string.format("mark %d at %.0f %.0f", ST.mark_n, x, z))
	elseif cmd == HS.MARK_DEL then
		-- the mark nearest the cursor (within HOOK_R on the page), else the newest
		local best, bd = nil, SIT.HOOK_R
		if G.cur_sx then
			for i, m in ipairs(ST.marks) do
				local sx, sy = to_screen(m.x - G.ox, m.z - G.oz)
				local dd = sqrt((sx - G.cur_sx) ^ 2 + (sy - G.cur_sy) ^ 2)
				if dd < bd then best, bd = i, dd end
			end
		end
		table.remove(ST.marks, best or 1)
	elseif cmd == HS.RNG_UP then sit_range(1)
	elseif cmd == HS.RNG_DN then sit_range(-1)
	elseif cmd == HS.UHF1_UP then rad_step(1, -1)
	elseif cmd == HS.UHF1_DN then rad_step(1, 1)
	elseif cmd == HS.UHF2_UP then rad_step(2, -1)
	elseif cmd == HS.UHF2_DN then rad_step(2, 1)
	elseif cmd == HS.CMD_DISPENSE then
		cmd_dispense()
	elseif cmd == HS.CMD_NEXT then
		ST.cmd = ST.cmd % #SIT.CMD_PROGRAMS + 1
	elseif cmd == HS.CBT_JETT then
		local w = jett_what()
		if w then to_export("F15SITJ," .. w); ST.jett_t, ST.jett_w = now(), w end
	else
		return false
	end
	return true
end


-- own missiles in flight: missile, line to its target, time to impact
local function draw_missiles(t)
	local list = (feed.msl and t - (feed.msl_t or -10) < 3) and feed.msl or {}
	local el = t - (feed.msl_t or t)
	-- (the fly-out line flashes; the line to the locked target with it while
	-- a missile flies: draw_lock reads G.msl_fly / G.msl_flash)
	local fs = SIT.MSL_FLASH_S or 0.5
	local flash_on = fs <= 0 or floor(t / fs) % 2 == 0
	G.msl_fly, G.msl_flash = false, flash_on
	for k = 1, SIT.MAX_MSL do
		local h, m = H.msl[k], list[k]
		local mv, tv, lv = 0, 0, 0
		local mx, my, tx, ty
		if m and m.tg and m.tx then
			tx, ty = to_screen(m.tx - G.ox, m.tz - G.oz)
			if inside(tx, ty) then
				h.tx:set(tx); h.ty:set(ty); tv = 1
				local s = (m.tti >= 0) and string.format("%s %d", m.typ, math.max(0, floor(m.tti - el + 0.5))) or m.typ
				h.txt:set(safe_text(s))
			end
		end
		if m and m.m and m.mx then
			mx, my = to_screen(m.mx - G.ox, m.mz - G.oz)
			-- at the missile: a circle; an AIM-120 inside the MPRF range of its
			-- target (its own seeker has it): an X
			local sym = 1
			if m.typ == "A" and m.tg and m.tx then
				local dd = sqrt((m.mx - m.tx) ^ 2 + (m.mz - m.tz) ^ 2)
				if dd <= (SIT.MSL_MPRF_NM or 7) * NM then sym = 2 end
			end
			h.sym:set(sym)
			if inside(mx, my) then h.x:set(mx); h.y:set(my); mv = 1 end
		end
		h.vis:set(mv); h.tvis:set(tv)
		if mx and tv == 1 then
			G.msl_fly = true
			if flash_on then
				local a1, a2, b1, b2 = clip(mx, my, tx, ty)
				if a1 then h.l.ax:set(a1); h.l.ay:set(a2); h.l.bx:set(b1); h.l.by:set(b2); lv = 1 end
			end
		end
		h.l.vis:set(lv)
	end
end
-- mark points: an x with its number and bearing / range from us
local function draw_marks()
	for k = 1, SIT.MAX_MARKS do
		local h, m = H.mk[k], ST.marks[k]
		local vis = 0
		if m then
			local sx, sy = to_screen(m.x - G.ox, m.z - G.oz)
			if inside(sx, sy) then
				vis = 1
				h.x:set(sx); h.y:set(sy)
				local b, r = brg_rng(m.x - G.ox, m.z - G.oz)
				h.txt:set((ST.dcl >= 3) and ("M" .. m.n) or string.format("M%d %03d/%d", m.n, b, floor(r / NM + 0.5)))
			end
		end
		h.vis:set(vis)
	end
end

-- power and the display's knob: dark without power or with the knob at OFF,
-- a short start-up when it comes on; the brightness cover. Returns true while
-- the page is up.
local function power_tick(t)
	local rl, rr = sd_val("getEngineLeftRPM"), sd_val("getEngineRightRPM")
	local rpm = nil
	if rl or rr then
		rpm = math.max(rl or 0, rr or 0)
		if rpm > 0.3 and rpm <= 1.5 then rpm = rpm * 100 end      -- (in case it comes as a fraction)
	end
	if PWR.sw == nil then
		-- at the start: engines running (hot / air start) = power on; no RPM
		-- from the jet at all = always on (the display never goes dark)
		PWR.sw = (rpm == nil) or rpm >= SIT.RPM_ON
		log(string.format("power at start: engines %s, %s", rpm and string.format("%.0f %%", rpm) or "(no RPM)",
			PWR.sw and "on" or "off (cold start): dark until the electric power switch or an engine"))
	end
	local on = PWR.sw or (rpm ~= nil and rpm >= SIT.RPM_ON)
	PWR.on = on
	H.jpwr:set(on and 1 or 0)            -- (for the helmet display)
	local disp = on and ST.mode > 0
	-- coming on (power, or the knob out of OFF): start-up, then the DTM page
	if disp and not PWR.disp then PWR.boot_t = t; ST.page = PG.DTM; PGF.now = true end
	PWR.disp = disp
	-- start-up: 1 dark, 2 test pattern, 3 "GO", 0 over
	local phase = 0
	local el = (disp and PWR.boot_t) and (t - PWR.boot_t) or nil
	if el and el >= 0 and el < SIT.BOOT_S then
		phase = (el < 0.35) and 1 or (el < SIT.BOOT_S - 0.8) and 2 or 3
	end
	PWR.shown = disp and phase == 0
	H.boot:set(disp and phase or 0)
	local rd = PWR.shown and 1 or 0
	if rd ~= PWR.ready then PWR.ready = rd; READY:set(rd) end
	-- brightness: a black see-through cover over the screen, 0 (none) .. 19
	local eff = (ST.brt / SIT.BRT_STEPS) * ((ST.mode == 1) and SIT.NIGHT_K or 1)
	H.dim:set(disp and math.max(0, math.min(19, floor((1 - eff) * 20 + 0.5))) or 0)
	return PWR.shown
end

-- JHMCS: the radar lock and jet power for the helmet device (HMD/hmd_device.lua),
-- as cockpit parameters: world position (x north, z east, y up, metres),
-- velocity (m/s), the model time of the report, 1/0 valid
-- (HLK_*: the SIT page's own lock symbol already uses LK_*)
local LKP = {x = P("HLK_X"), z = P("HLK_Z"), y = P("HLK_Y"), vx = P("HLK_VX"), vz = P("HLK_VZ"),
	t = P("HLK_T"), on = P("HLK_ON")}
local function publish_lock(t)
	local L = feed.lock
	if L and t - L.t <= 3 and t >= L.t then
		LKP.x:set(L.x); LKP.z:set(L.z); LKP.y:set(L.y or 0)
		LKP.vx:set(L.vx or 0); LKP.vz:set(L.vz or 0); LKP.t:set(L.t); LKP.on:set(1)
	else
		LKP.on:set(0)
	end
end

-- JHMCS: master mode, weapon, steerpoint, the lock's identity and the
-- datalink picture for the helmet device (HMD/hmd_device.lua):
--   HMST 1 A/A, 2 NAV, 0 other
--   HWPN_K 0 none, 1 radar missile, 2 AIM-9, 3 gun; HWPN_T "A4C" (letter, count,
--     model: A = AIM-120, M = AIM-7, S = AIM-9, as the real JHMCS); HWPN_N rounds
--   HWP_ON / X / Z the active steerpoint
--   HLK_ID 1 friendly, 2 hostile, 0 unknown; HLK_RA / RM / RP / RT envelope (m)
--   HCN contacts, HC<n>_K kind (1 friendly, 2 flight member, 3 hostile,
--     4 unknown, 5 SAM), X Z Y VX VZ (m, m/s), T report time, L name
local HM = {mst = P("HMST"), wk = P("HWPN_K"), wt = PT("HWPN_T"), wn = P("HWPN_N"),
	wp_on = P("HWP_ON"), wp_x = P("HWP_X"), wp_z = P("HWP_Z"),
	id = P("HLK_ID"), ra = P("HLK_RA"), rm = P("HLK_RM"), rp = P("HLK_RP"), rt = P("HLK_RT"),
	n = P("HCN"), c = {}}
local HMC_MAX = 48
for n = 1, HMC_MAX do
	local p = "HC" .. n .. "_"
	HM.c[n] = {k = P(p .. "K"), x = P(p .. "X"), z = P(p .. "Z"), y = P(p .. "Y"), vx = P(p .. "VX"), vz = P(p .. "VZ"),
		t = P(p .. "T"), l = PT(p .. "L")}
end
HM.n:set(0)
local HM_KIND = {[1] = 1, [2] = 3, [3] = 4, [4] = 1, [5] = 2, [6] = 1}
local HM_LETTER = {a = "A", s = "M", m = "S"}
-- a short name: letters and digits, upper case, at most n characters
local function short(s, n)
	s = tostring(s or ""):upper():gsub("[^%w]", "")
	return s:sub(1, n)
end
local HM_TAKE, HM_SKIP = {}, {}
local function publish_hmd(t)
	if H.jpwr.v ~= 1 then return end
	local stale = (t - feed.rx) > SIT.STALE_S
	-- master mode
	local m = feed.master
	HM.mst:set(m == "A/A" and 1 or (m == "NAV" and 2 or 0))
	-- selected weapon
	local s = feed.sta and feed.sta[feed.cur_sta or 0]
	local cl = s and s.n > 0 and store_class(s.name)
	if feed.gun then
		-- (gun mode: FC3 keeps the last missile station selected)
		HM.wk:set(3); HM.wn:set(feed.cm and feed.cm.gun or 0)
	elseif cl then
		-- (count: all missiles of that kind, model: the selected one's)
		local cnt = feed.stores and feed.stores[cl] or 0
		local model = s.name:upper():match("(%a)[^%a]*$") or ""
		HM.wk:set(cl == "m" and 2 or 1)
		HM.wt:set(HM_LETTER[cl] .. cnt .. model)
	elseif m == "A/A" then
		HM.wk:set(3); HM.wn:set(feed.cm and feed.cm.gun or 0)
	else
		HM.wk:set(0)
	end
	-- steerpoint
	local w = (feed.active or 0) > 0 and feed.wpts and feed.wpts[feed.active]
	if w then HM.wp_on:set(1); HM.wp_x:set(w.x); HM.wp_z:set(w.z) else HM.wp_on:set(0) end
	-- the lock: envelope and identity (the contact on it)
	local list = EWR.merge(feed.list, t, stale)
	local L = feed.lock
	if L then
		HM.ra:set(L.ra or 0); HM.rm:set(L.rm or 0); HM.rp:set(L.rp or 0); HM.rt:set(L.rt or 0)
		local id, bd = 0, 1500
		for _, c in ipairs(list) do
			local d = math.max(abs(c.x - L.x), abs(c.z - L.z))
			if d < bd then
				bd = d
				local b = (c.code or 0) % 10
				id = (b == 2) and 2 or ((b == 1 or b == 4 or b == 5 or b == 6) and 1 or 0)
			end
		end
		HM.id:set(id)
	end
	-- contacts: flight members take their contact (as on the SIT page)
	local members = stale and NOMEM or flt_members()
	match_members(list, members, t, HM_TAKE, HM_SKIP, "hm")
	local n = 0
	local function put(k, x, z, y, vx, vz, tt, l)
		if n >= HMC_MAX then return end
		n = n + 1
		local o = HM.c[n]
		o.k:set(k); o.x:set(x); o.z:set(z); o.y:set(y or 0); o.vx:set(vx or 0); o.vz:set(vz or 0); o.t:set(tt or t)
		-- (a SAM's number stays a bare number for the helmet: it shows it in a number field)
		o.l:set(k == 5 and tostring(l or "") or safe_text(l))
	end
	local function callsign(a) return short(a.unit:match("^%a+") or a.unit, 3) .. (a.num or "") end
	-- v1.3: contacts and SAM sites only out to the range set on the SIT page
	-- (in a big mission the helmet showed every contact of the picture, at any
	-- distance). Own flight members are always shown.
	local lim = SIT.HMD_SIT_RANGE ~= false and G.rng_m or nil
	local lim2 = lim and lim * lim
	local function near(x, z) return not lim2 or (x - G.ox) ^ 2 + (z - G.oz) ^ 2 <= lim2 end
	for i, c in ipairs(list) do
		local k = HM_KIND[(c.code or 0) % 10]
		if k and not HM_SKIP[i] and (HM_TAKE[i] or near(c.x, c.z)) then
			local mem = HM_TAKE[i]
			if mem then put(2, c.x, c.z, c.y, c.vx, c.vz, c.t, callsign(mem))
			else put(k, c.x, c.z, c.y, c.vx, c.vz, c.t, (k <= 2) and short(c.nm, 4) or "") end
		end
	end
	for _, a in ipairs(members) do
		if not a.hm then put(2, a.x, a.z, a.y, a.vx, a.vz, feed.rx, callsign(a)) end
	end
	if not stale then
		for _, g in ipairs(feed.thr or {}) do
			-- (SAM sites only: early-warning radars have no ring)
			if (g.ring or 0) > 0 and near(g.x, g.z) then put(5, g.x, g.z, g.y, 0, 0, t, short((tostring(g.lbl):gsub("^SA%-?", "")), 4)) end
		end
	end
	HM.n:set(n)
end

local function update_body()
	tick = tick + 1
	read_udp()
	local t = now()
	hmd_controls_tick(t)
	acq_tick(t)
	srs_vol_tick(t)
	local sd = sensors()
	if not sd then return end

	local okp, ox, _, oz = pcall(sd.getSelfCoordinates)
	local okh, h = pcall(sd.getHeading)
	if not okp or not ox then return end
	G.ox, G.oz = ox, oz
	if EWR.pending then
		EWR.on_packet(EWR.pending, t, ox, oz); EWR.pending = nil
		if EWR.n <= 3 then log("EWR report " .. EWR.n .. ": " .. #(EWR.fr or {}) .. " friendly, " .. #(EWR.hs or {}) .. " hostile") end
	end
	G.hdg = (okh and h) and ((-h) % TWO_PI) or 0         -- true heading, clockwise from north
	-- (for the helmet device: nothing to do while it is switched off in Options > Special)
	if HMD.ENABLED ~= false then
		pcall(publish_lock, t)
		local ok, err = pcall(publish_hmd, t)
		if not ok and not G.hm_err then G.hm_err = true; log("hmd publish: " .. tostring(err)) end
	end
	-- no power / display off / starting up: nothing to draw, no cursor, no scan
	if not power_tick(t) then
		if ST.soi_sit then
			ST.soi_sit = false
			to_export(string.format("F15SITQ,0,%.4f,%.4f", SLEW.raw_h or 0, SLEW.raw_v or 0))
		end
		if ST.pic_need ~= 0 or t - (ST.pic_t or -10) >= 1 or t < (ST.pic_t or 0) then
			ST.pic_need, ST.pic_t = 0, t
			to_export("F15SITG,0")
		end
		return
	end
	if ST.nup then G.c, G.s = 1, 0 else G.c, G.s = cos(G.hdg), sin(G.hdg) end

	-- FORM: fixed 5 NM around the formation, shown as "F5";
	-- EXP: 10 NM around the cursor ("E10"), the ownship moves off centre
	-- the range shown = ownship to the top edge of the SIT area; centred and
	-- decentred have their own steps (decentred: 7, 15, 30, 60 ...)
	local RL = ST.center and SIT.RANGES_NM or SIT.RANGES_DC_NM
	if ST.autor and feed.cur and feed.cur.dist and feed.cur.dist > 0 then
		local vsd = feed.cur.dist / NM
		local k = #RL
		for i = #RL, 1, -1 do if RL[i] >= vsd - 0.5 then k = i end end
		ST.rng = k
	end
	local rng = math.min(ST.rng, #RL)
	if ST.form then RL = SIT.RANGES_NM; rng = 1 end   -- formation: fixed F5
	G.own_x, G.own_y = 0, ST.center and SIT.CENTER_Y or SIT.DECENTER_Y
	G.k = (SIT.BOX - G.own_y) / (RL[rng] * NM)
	if ST.exp then
		G.k = SIT.BOX / (SIT.EXP_NM * NM)
		local cx, cz = G.cur_x or G.ox, G.cur_z or G.oz
		local sx, sy = to_screen(G.ox - cx, G.oz - cz)
		G.own_x, G.own_y = sx, sy
	end

	local stale = (t - feed.rx) > SIT.STALE_S
	G.dt = t - (G.last_t or t)
	G.last_t = t
	-- SIT has the cursor: the export keeps the TDC slew at ~0 (told twice a
	-- second); leaving the SIT page gives the cursor back to the radar
	if ST.soi_sit and ST.page ~= PG.SIT then
		ST.soi_sit = false; log("SIT page left: cursor back to the radar")
		to_export(string.format("F15SITQ,0,%.4f,%.4f", SLEW.raw_h or 0, SLEW.raw_v or 0))
	end
	if ST.soi_sit and SIT.SQUELCH_RADAR and t - (ST.q_t or -10) >= 0.5 then ST.q_t = t; to_export("F15SITQ,1") end
	-- the datalink picture is only shown on these pages: off them the export
	-- skips DCS's world scan (several ms on a busy server). Told on every
	-- change and once a second.
	local need = (ST.page == PG.SIT or ST.page == PG.FLT or ST.page == PG.SETS) and 1 or 0
	if need ~= ST.pic_need or t - (ST.pic_t or -10) >= 1 or t < (ST.pic_t or 0) then
		ST.pic_need, ST.pic_t = need, t
		to_export("F15SITG," .. need)
	end

	H.own_y:set(G.own_y)
	H.own_x:set(G.own_x)
	H.center:set(ST.exp and 2 or (ST.center and 1 or 0))     -- (2: EXP, no rose)
	H.own_vis:set(inside(0, 0) and 1 or 0)
	H.rng:set(RL[rng])
	G.rng_m = RL[rng] * NM                 -- (the helmet shows contacts out to this range)
	H.rng_mode:set((ST.form or ST.exp) and 1 or 0)
	H.rngt:set(ST.exp and ("E" .. SIT.EXP_NM) or (ST.form and ("F" .. RL[1])) or "")
	H.page:set(ST.page)
	H.dclt:set(ST.dcl >= 3 and 1 or 0); if G.dcl_n ~= ST.dcl then G.dcl_n = ST.dcl; H.dcl_lv:set("DCLT " .. ST.dcl .. " " .. SIT.DCL_NAMES[ST.dcl]) end; H.dcl_pop:set((now() - (ST.dcl_t or -10) < 2.5) and 1 or 0); H.lines:set(ST.lines and 1 or 0); H.fch:set(ST.fch)
	if t - ST.ipf_t < 3 then H.net:set("IPF RESET")
	elseif t - ST.net_t < 2 then H.net:set("NET ENTRY: IN PROGRESS")
	elseif t - ST.net_t < 4 then H.net:set("NET ENTRY: COARSE")
	else H.net:set(stale and "NET ENTRY: NONE" or "NET ENTRY: FINE") end
	if ST.dtm_msg ~= "" and t - ST.dtm_t < 2.5 then H.dtm:set(ST.dtm_msg)
	elseif t - ST.dtm_t < 12 then H.dtm:set(ST.dtm_done)
	else H.dtm:set("") end
	H.autor:set(ST.autor and 1 or 0)
	H.dl:set(ST.dl and 1 or 0)
	H.rte:set(ST.rte and 1 or 0); H.thr:set(ST.thr and 1 or 0)

	local tod = (get_absolute_model_time and get_absolute_model_time()) or t
	local off = feed.date and SIT.UTC_OFFSET[feed.date.th]
	local zt = (ST.zulu and off) and (tod - off * 3600) or nil
	local sec = floor(zt or tod)
	if sec ~= G.t_sec or (zt ~= nil) ~= G.t_z then
		G.t_sec, G.t_z = sec, zt ~= nil
		if zt then
			H.time:set(string.format("%02d:%02d:%02dZ", floor(zt / 3600) % 24, floor(zt / 60) % 60, sec % 60))
		else
			H.time:set(string.format("%02d:%02d:%02d", floor(tod / 3600) % 24, floor(tod / 60) % 60, sec % 60))
		end
	end
	G.tod = tod

	local s = feed.status or 0
	local ewr = EWR.fresh(t) and (stale or s % 2 == 0)
	-- nothing at all from the export script since the cockpit started: the
	-- Export.lua line is missing or broken (or the server blocks export).
	-- Said on the status line and once in the log.
	G.t_start = G.t_start or t
	if t < G.t_start then G.t_start = t end
	local no_exp = not feed.exp_t and t - G.t_start >= SIT.NO_EXPORT_S
	if no_exp and not G.no_exp_logged then
		G.no_exp_logged = true
		log("no data from Scripts\\F15SIT_Export.lua after " .. SIT.NO_EXPORT_S .. " s: check that Saved Games\\DCS\\Scripts\\Export.lua"
			.. " has the F15SIT_Export.lua line and that no line above it errors (dcs.log), or the server blocks export."
			.. " Without it: no stores pages, no helmet view, no datalink picture")
	elseif feed.exp_t and G.no_exp_logged and not G.exp_late_logged then
		G.exp_late_logged = true
		log("export data arrived (late)")
	end
	if no_exp and not ewr then
		H.status:set("NO EXPORT DATA")
	elseif ewr then
		H.status:set("DL EWR REPORTS")
	elseif stale then
		H.status:set(udp and "NO DL" or "NO LINK SOCKET")
	elseif s % 2 == 0 then
		H.status:set("DL OFF (SERVER)")
	elseif s ~= G.st_s then
		G.st_s = s
		local a, f = floor(s / 2) % 2 == 1, floor(s / 8) % 2 == 1
		G.st_txt = "DL " .. ((a and f) and "AWACS F2F" or a and "AWACS" or f and "F2F" or "OWN")
		H.status:set(G.st_txt)
	else
		H.status:set(G.st_txt)
	end

	-- the SIT scope only while the SIT page is on screen (v0.9)
	if ST.page == PG.SIT then
		draw_scope()
		draw_route()
		draw_cursor(stale)
		draw_geo()
		draw_threats(stale)
		draw_contacts(t, stale)
		draw_missiles(t)
		draw_marks()
		draw_lock(t, stale)
		draw_crs()
		draw_bull()
		draw_stores(stale)
	end
	draw_pages(t, stale)
end

need_to_be_closed = false

-- timing log (Options > Special > F-15C SIT: timing and debug logs, off by
-- default), Logs\f15sit_perf.log: every 30 s the average and worst time of
-- one update and the Lua memory used (os.clock: 1 ms steps)
function update()
	if not PF.on then
		local ok, err = pcall(update_body)
		if not ok and log_n < 60 then log("update error: " .. tostring(err)) end
		return
	end
	local c0 = os.clock()
	local ok, err = pcall(update_body)
	if not ok and log_n < 60 then log("update error: " .. tostring(err)) end
	local dt = os.clock() - c0
	PF.n, PF.sum = PF.n + 1, PF.sum + dt
	if ST.page == PG.SIT then PF.sn, PF.ssum = (PF.sn or 0) + 1, (PF.ssum or 0) + dt end
	if dt > PF.max then PF.max = dt end
	local t = os.clock()
	PF.t = PF.t or t
	if t - PF.t >= 30 and PF.blocks < 200 then
		PF.blocks = PF.blocks + 1
		pcall(function()
			local l = require("lfs")
			-- (kept over respawns: appended, a header per flight; started anew past 200 KB)
			local path = l.writedir() .. "Logs/f15sit_perf.log"
			-- (file size from lfs: the cockpit's io has no working seek)
			local size = 0
			pcall(function() size = tonumber(l.attributes(path, "size")) or 0 end)
			local f = io.open(path, (size > 200000) and "w" or "a")
			if f then
				if PF.blocks == 1 then f:write("=== flight " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n") end
				local sn = PF.sn or 0
				f:write(string.format("%s  updates %d  avg %.3f ms  worst %.1f ms  on SIT %d%% (avg %s ms there)  page %d  Lua mem %.0f KB\n",
					os.date("%H:%M:%S"), PF.n, PF.sum / math.max(PF.n, 1) * 1000, PF.max * 1000, floor(100 * sn / math.max(PF.n, 1) + 0.5),
					sn > 0 and string.format("%.3f", (PF.ssum or 0) / sn * 1000) or "-", ST.page, collectgarbage("count")))
				f:close()
			end
		end)
		PF.n, PF.sum, PF.max, PF.t, PF.sn, PF.ssum = 0, 0, 0, t, 0, 0
	end
end
