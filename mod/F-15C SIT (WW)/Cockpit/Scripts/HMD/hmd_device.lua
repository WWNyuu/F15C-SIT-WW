-----------------------------------------------------------------------
-- F-15C SIT (WW): JHMCS helmet device. Runs at 100 Hz: everything placed
-- in the world follows the view.
--   in:  the view's direction from the export (commands 6201-6206), the
--        jet's own data (get_base_data), and from the SIT device as cockpit
--        parameters: power (JPWR), radar lock + launch envelope (HLK_*),
--        master mode (HMST), selected weapon (HWPN_*), steerpoint (HWP_*),
--        datalink contacts and SAMs (HC<n>_*)
--   out: the helmet display's parameters F15SIT_HMD_* (HMD/hmd_head.lua)
-----------------------------------------------------------------------
dofile(LockOn_Options.script_path .. "HMD/hmd_config.lua")
dofile(LockOn_Options.script_path .. "HMD/hmd_options.lua")     -- (Options > Special: size)
local dev = GetSelf()
local STEP = 0.01                -- (100 Hz)
make_default_activity(STEP)

local NM, FT, KT = 1852.0, 0.3048, 1.94384
local TWO_PI = 2 * math.pi
local sin, cos, sqrt, atan2, floor, abs = math.sin, math.cos, math.sqrt, math.atan2, math.floor, math.abs
local min, max, deg, rad = math.min, math.max, math.deg, math.rad
local KR = 17.4533 * (HMD.SCALE or 1) / 1000          -- one layout degree, in radians on the display
local FOV_T = math.tan(rad(HMD.FOV_DEG or 10))         -- visor field radius (flat projection)
local EDGE_T = math.tan(rad(HMD.EDGE_DEG or HMD.FOV_DEG or 10))   -- where flight members outside it are kept
local MAXC = HMD.MAX_CONTACTS or 16

local function now() return get_model_time and get_model_time() or 0 end

local log_n = 0
local function log(msg)
	if log_n > 60 then return end
	log_n = log_n + 1
	pcall(function()
		local lfs = require("lfs")
		local f = io.open(lfs.writedir() .. "Logs/f15sit_hmd.log", log_n == 1 and "w" or "a")
		if f then f:write(os.date("%H:%M:%S ") .. tostring(msg) .. "\n"); f:close() end
	end)
end

-- parameters, written only when the value changes
local PH = {}
PH.__index = PH
function PH:set(v) if v ~= self.v then self.v = v; self.h:set(v) end end
local function P(n) return setmetatable({h = get_param_handle("F15SIT_HMD_" .. n)}, PH) end
-- text parameter: a string from the start (a number in a "%s" field crashes DCS)
local function PT(n) local p = P(n); p:set(""); return p end
local function safe(v) v = tostring(v or ""); if tonumber(v) then v = "'" .. v end; return v end
local function IN(n) return get_param_handle("F15SIT_" .. n) end
local function num(h) return tonumber(h:get()) or 0 end
-- (a text that looks like a number, "10", comes back as a number)
local function str(h)
	local v = h:get()
	if type(v) == "number" then return (v == floor(v)) and string.format("%d", v) or tostring(v) end
	return type(v) == "string" and v or ""
end

local O = {
	on = P("ON"), aa = P("AA"), nav = P("NAV"), cross = P("CROSS"), zero = P("ZERO"), one = P("ONE"),
	ac_hdg = P("ACHDG"), ias = P("IAS"), alt_hi = P("ALT_HI"), alt_lo = P("ALT_LO"),
	align_on = P("ALIGN_ON"), align = PT("ALIGN"),
	wpn_k = P("WPN_K"), wpn_t = PT("WPN_T"), wpn_n = P("WPN_N"), mach = P("M"), g = P("G"),
	lk = P("LK"), rng = P("RNG"), asp = PT("ASP"),
	wp_on = P("WP_ON"), wp_r = P("WP_R"), wp_ttg = P("WP_TTG"),
	att_on = P("ATT_ON"), roll = P("ROLL"),
	cmd_on = P("CMD_ON"), cmd_x = P("CMD_X"),
	dlz_on = P("DLZ_ON"), dlz_sc = P("DLZ_SC"), dlz_rmf = P("DLZ_RMF"), dlz_rtf = P("DLZ_RTF"), vc = P("VC"),
	ase_k = P("ASE_K"), ase_dx = P("ASE_DX"), ase_dy = P("ASE_DY"), asp_on = P("ASP_ON"), asp_a = P("ASP_A"),
	brt = P("BRT"),
	td_on = P("TD_ON"), td_x = P("TD_X"), td_y = P("TD_Y"), shoot = P("SHOOT"), td_a = PT("TD_A"), td_id = P("TD_ID"),
	tll_on = P("TLL_ON"), tll_a = P("TLL_A"), tle_x = P("TLE_X"), tle_y = P("TLE_Y"), tll_d = P("TLL_D"),
}
O.zero:set(0); O.one:set(1); O.on:set(0); O.cross:set(HMD.CROSS and 1 or 0)
local MK = {}
for _, m in ipairs({"DLZ_RA", "DLZ_RP", "DLZ_RT", "DLZ_RM", "DLZ_TG"}) do MK[m] = {on = P(m .. "_ON"), y = P(m)} end
local TK, TL = {}, {}
for k = 1, 21 do TK[k] = {on = P("TK" .. k .. "_ON"), x = P("TK" .. k .. "_X"), l = P("TK" .. k .. "_L")} end
for k = 1, 5 do TL[k] = {on = P("TL" .. k .. "_ON"), x = P("TL" .. k .. "_X"), v = P("TL" .. k .. "_V")} end
local C = {}
for n = 1, MAXC do
	local p = "C" .. n .. "_"
	C[n] = {on = P(p .. "ON"), x = P(p .. "X"), y = P(p .. "Y"), k = P(p .. "K"), l = PT(p .. "L"), r = P(p .. "R"),
		nn = P(p .. "N")}
	C[n].on:set(0)
end

-- from the SIT device
local I = {
	jpwr = IN("JPWR"), mst = IN("HMST"),
	hpwr = IN("HPWR"), hbrt = IN("HBRT"), mute = IN("HMUTE"),
	lk_on = IN("HLK_ON"), lk_x = IN("HLK_X"), lk_z = IN("HLK_Z"), lk_y = IN("HLK_Y"),
	lk_vx = IN("HLK_VX"), lk_vz = IN("HLK_VZ"), lk_t = IN("HLK_T"), lk_id = IN("HLK_ID"),
	ra = IN("HLK_RA"), rm = IN("HLK_RM"), rp = IN("HLK_RP"), rt = IN("HLK_RT"),
	wk = IN("HWPN_K"), wt = IN("HWPN_T"), wn = IN("HWPN_N"),
	wp_on = IN("HWP_ON"), wp_x = IN("HWP_X"), wp_z = IN("HWP_Z"),
	hcn = IN("HCN"),
}
local HC = {}
for n = 1, 48 do
	local p = "HC" .. n .. "_"
	HC[n] = {k = IN(p .. "K"), x = IN(p .. "X"), z = IN(p .. "Z"), y = IN(p .. "Y"),
		vx = IN(p .. "VX"), vz = IN(p .. "VZ"), t = IN(p .. "T"), l = IN(p .. "L")}
end

-- the jet's own data
local SD = nil
local function sd()
	if SD then return SD end
	local ok, d = pcall(get_base_data)
	if ok and d then SD = d end
	return SD
end
local function call(name)
	local d = sd()
	local f = d and d[name]
	if not f then return nil end
	local ok, a, b, c = pcall(f)
	if not ok then return nil end
	return a, b, c
end

-- where the pilot looks: the view's forward and up vectors in the world
-- (x north, y up, z east), from the export every frame
local LOOK = {fx = nil, fy = nil, fz = nil, ux = nil, uy = nil, uz = nil, t = nil, n = 0,
	ts = nil,                              -- the model time of the sample (from the export, 6207)
	vf = {0, 0, 0}, vu = {0, 0, 0},       -- how fast forward / up change (per second), smoothed
	pf = nil, pu = nil, pt = nil}          -- the previous sample
for c = 6201, 6207 do dev:listen_command(c) end
-- a new view sample: its rate of change against the last one (for the prediction)
local function look_sample()
	local ts = LOOK.ts or now()
	local f, u = {LOOK.fx, LOOK.fy, LOOK.fz}, {LOOK.ux, LOOK.uy, LOOK.uz}
	if LOOK.pf and LOOK.pt then
		local dt = ts - LOOK.pt
		if dt > 0.002 and dt < 0.2 then
			for i = 1, 3 do
				LOOK.vf[i] = 0.5 * LOOK.vf[i] + 0.5 * (f[i] - LOOK.pf[i]) / dt
				LOOK.vu[i] = 0.5 * LOOK.vu[i] + 0.5 * (u[i] - LOOK.pu[i]) / dt
			end
		elseif dt >= 0.2 then
			LOOK.vf, LOOK.vu = {0, 0, 0}, {0, 0, 0}
		end
	end
	LOOK.pf, LOOK.pu, LOOK.pt, LOOK.st = f, u, ts, ts
end
function SetCommand(command, value)
	if command == 6207 then LOOK.ts = value
	elseif command == 6201 then LOOK.fx = value
	elseif command == 6202 then LOOK.fy = value
	elseif command == 6203 then LOOK.fz = value
	elseif command == 6204 then LOOK.ux = value
	elseif command == 6205 then LOOK.uy = value
	elseif command == 6206 then LOOK.uz = value; LOOK.t = now()
		if HMD.VIEW_PREDICT ~= false then look_sample() end    -- (only the prediction needs the rate)
		if LOOK.n == 0 then LOOK.n = 1; log("look direction arriving") end
	end
end

local function dot3(a, x, y, z) return a[1] * x + a[2] * y + a[3] * z end
local function wrap180(a) return (a + 540) % 360 - 180 end
local function hdg360(r)
	local d = floor(deg(r % TWO_PI) + 0.5) % 360
	return d == 0 and 360 or d
end

-- view axes (world N, U, E): forward, up, right; the jet's axes likewise
local VF, VU, VR = {1, 0, 0}, {0, 1, 0}, {0, 0, 1}
local BF, BU, BR = {1, 0, 0}, {0, 1, 0}, {0, 0, 1}
-- on the view: flat projection (right/fwd, up/fwd); c = forward distance
local function view(dN, dU, dE)
	return dot3(VR, dN, dU, dE), dot3(VU, dN, dU, dE), dot3(VF, dN, dU, dE)
end
local function inside(rx, uy, c)
	if c <= 0 then return nil end
	local x, y = rx / c, uy / c
	if x * x + y * y > FOV_T * FOV_T then return nil end
	return x, y
end

local ST = {on_t = nil, was_on = false, first = true}
local CL = {}                 -- contacts this step (reused)
for n = 1, 48 do CL[n] = {} end
local function by_range(a, b) return a.rng < b.rng end
local EDGE2 = EDGE_T * EDGE_T
local DLZ_SCALES = {10, 20, 40, 80, 160}

-- the SIT device's data and the slower flight data: read at 20 Hz (the SIT
-- device writes them at 20 Hz; reading 48 contacts at 100 Hz cost five
-- times as much for nothing). The view and the jet's attitude stay at 100 Hz.
local IN_STEP = 0.05
local F = {t = nil, wt = ""}
local CC, CN = {}, 0          -- the contacts (world data, name)
for n = 1, 48 do CC[n] = {} end
local function read_inputs()
	F.mst = num(I.mst)
	F.wk = num(I.wk)
	if F.wk == 1 or F.wk == 2 then F.wt = safe(str(I.wt)) end
	F.wn = num(I.wn)
	F.wp_on = num(I.wp_on) == 1; F.wp_x, F.wp_z = num(I.wp_x), num(I.wp_z)
	F.lk_on, F.lk_t = num(I.lk_on) == 1, num(I.lk_t)
	F.lk_x, F.lk_z, F.lk_y, F.lk_vx, F.lk_vz = num(I.lk_x), num(I.lk_z), num(I.lk_y), num(I.lk_vx), num(I.lk_vz)
	F.lk_id = num(I.lk_id)
	F.ra, F.rm, F.rp, F.rt = num(I.ra) / NM, num(I.rm) / NM, num(I.rp) / NM, num(I.rt) / NM
	F.ias, F.alt, F.mach, F.g = call("getIndicatedAirSpeed"), call("getBarometricAltitude"), call("getMachNumber"),
		call("getVerticalAcceleration")
	F.svx, F.svy, F.svz = call("getSelfVelocity")
	CN = 0
	if HMD.CONTACTS then
		for n = 1, min(num(I.hcn), 48) do
			local s = HC[n]
			local k = num(s.k)
			if k > 0 and (k ~= 5 or HMD.SAMS) then
				CN = CN + 1
				local c = CC[CN]
				c.k, c.x, c.z, c.y, c.vx, c.vz, c.t = k, num(s.x), num(s.z), num(s.y), num(s.vx), num(s.vz), num(s.t)
				c.l = str(s.l)
			end
		end
	end
end
-- a launch envelope mark on the scale (hidden off the scale)
local function dlz_mark(m, r, sc, L)
	if r > 0 and r <= sc then MK[m].on:set(1); MK[m].y:set(r / sc * L) else MK[m].on:set(0) end
end

local function hide_lock()
	O.lk:set(0); O.td_on:set(0); O.tll_on:set(0); O.ase_k:set(0); O.dlz_on:set(0); O.att_on:set(1)
end

local function update_hmd()
	local d = sd()
	if not d then return end
	local t = now()
	-- the panel: power switch, brightness knob (0..1); the symbology off bind
	local bm = HMD.BRT_MIN or 0.06
	O.brt:set(bm + (1 - bm) * min(max(num(I.hbrt), 0), 1))
	-- powered (jet power, knob on): the alignment messages start then
	local powered = num(I.jpwr) == 1 and num(I.hpwr) == 1
	if not powered then ST.was_on = false elseif not ST.was_on then ST.was_on, ST.on_t = true, t end
	if not (powered and num(I.mute) ~= 1) then
		O.on:set(0)
		return
	end

	local ox, oy, oz = call("getSelfCoordinates")
	local h, th, ph = call("getHeading"), call("getPitch"), call("getRoll")
	if not (ox and h and th and ph) then
		if ST.first then ST.first = false; log("own data missing") end
		O.on:set(0); return
	end
	local psi = (-h) % TWO_PI                     -- true heading, clockwise from north
	-- the jet's axes in the world (N, U, E)
	-- (BF / BU / BR: forward, up, right; tables reused, no garbage at 100 Hz)
	local cp, sp, ct, st, cr, sr = cos(psi), sin(psi), cos(th), sin(th), cos(ph), sin(ph)
	local u1, u2, u3 = -st * cp, ct, -st * sp           -- up before the roll
	local r1, r3 = -sp, cp                              -- right before the roll (no vertical part)
	BF[1], BF[2], BF[3] = ct * cp, st, ct * sp
	BU[1], BU[2], BU[3] = u1 * cr + r1 * sr, u2 * cr, u3 * cr + r3 * sr
	BR[1], BR[2], BR[3] = r1 * cr - u1 * sr, -u2 * sr, r3 * cr - u3 * sr

	-- the view: from the export, else straight ahead along the jet
	local look = LOOK.t and t - LOOK.t < 3 and LOOK.fx and LOOK.ux
	if look then
		VF[1], VF[2], VF[3] = LOOK.fx, LOOK.fy, LOOK.fz
		VU[1], VU[2], VU[3] = LOOK.ux, LOOK.uy, LOOK.uz
		-- predicted to now (the sample is a frame or two old: without this
		-- the symbols lag and jitter while the head turns), at most 50 ms
		if HMD.VIEW_PREDICT ~= false and LOOK.st then
			local d = min(max(t - LOOK.st + (HMD.VIEW_LEAD or 0), 0), 0.05)
			for i = 1, 3 do VF[i] = VF[i] + LOOK.vf[i] * d; VU[i] = VU[i] + LOOK.vu[i] * d end
			-- back to unit length, up square to forward
			local lf = sqrt(VF[1] ^ 2 + VF[2] ^ 2 + VF[3] ^ 2)
			if lf > 0 then for i = 1, 3 do VF[i] = VF[i] / lf end end
			local k = VU[1] * VF[1] + VU[2] * VF[2] + VU[3] * VF[3]
			for i = 1, 3 do VU[i] = VU[i] - k * VF[i] end
			local lu = sqrt(VU[1] ^ 2 + VU[2] ^ 2 + VU[3] ^ 2)
			if lu > 0 then for i = 1, 3 do VU[i] = VU[i] / lu end end
		end
		VR[1] = VF[2] * VU[3] - VF[3] * VU[2]
		VR[2] = VF[3] * VU[1] - VF[1] * VU[3]
		VR[3] = VF[1] * VU[2] - VF[2] * VU[1]
	else
		for i = 1, 3 do VF[i], VU[i], VR[i] = BF[i], BU[i], BR[i] end
	end
	-- line of sight in the jet's frame: off-boresight angle, HUD blanking
	local lf, lu, lr = dot3(BF, VF[1], VF[2], VF[3]), dot3(BU, VF[1], VF[2], VF[3]), dot3(BR, VF[1], VF[2], VF[3])
	local l_az, l_el = deg(atan2(lr, lf)), deg(atan2(lu, sqrt(lf * lf + lr * lr)))
	local in_hud = HMD.HUD_BLANK and abs(l_az) < HMD.HUD_AZ and l_el > HMD.HUD_EL_LO and l_el < HMD.HUD_EL_HI
	if in_hud and HMD.HUD_CONTACTS == false then O.on:set(0); return end
	-- cockpit blanking: looking down into the cockpit (below the glare
	-- shield ahead, below the canopy rail to the sides)
	if HMD.CKPT_BLANK and HMD.CKPT_EDGE then
		local E, a = HMD.CKPT_EDGE, abs(l_az)
		local lim = E[#E][2]
		for i = 1, #E - 1 do
			if a <= E[i + 1][1] then
				local f = (a - E[i][1]) / max(E[i + 1][1] - E[i][1], 1e-6)
				lim = E[i][2] + (E[i + 1][2] - E[i][2]) * f
				break
			end
		end
		if l_el < lim then O.on:set(0); return end
	end
	-- (2: through the HUD, only the contacts and the acquisition mode are drawn)
	O.on:set(in_hud and 2 or 1)
	-- (at once when the display comes back: the timer is old by then)
	if not F.t or t - F.t >= IN_STEP or t < F.t then F.t = t; read_inputs() end

	-- alignment messages after power-up (window H1)
	local ta = t - (ST.on_t or t)
	if HMD.ALIGN_MSG and ta < 6 then
		O.align_on:set(1); O.align:set(ta < 3.5 and "ALIGNING" or "ALIGN OK")
	else
		O.align_on:set(0)
	end

	-- master mode: 1 A/A, else the NAV display
	local aa = F.mst == 1
	O.aa:set(aa and 1 or 0); O.nav:set(aa and 0 or 1)

	-- flight data
	local svx, svy, svz = F.svx, F.svy, F.svz
	O.ias:set(floor((F.ias or 0) * KT + 0.5))
	local af = floor((F.alt or 0) / FT / 10 + 0.5) * 10
	O.alt_hi:set(af >= 1000 and floor(af / 1000) or 0)
	O.alt_lo:set(af % 1000)
	O.mach:set(floor((F.mach or 0) * 100 + 0.5) / 100)
	O.g:set(floor((F.g or 1) * 10 + 0.5) / 10)
	O.ac_hdg:set(hdg360(psi))
	O.roll:set(ph)

	-- weapon (window 10): 1 MRM, 2 SRM, 3 gun
	local wk = F.wk
	O.wpn_k:set(wk)
	if wk == 1 or wk == 2 then O.wpn_t:set(F.wt) end
	if wk == 3 then O.wpn_n:set(F.wn) end

	-- heading tape on the helmet heading (all modes), steerpoint (NAV)
	local hd = deg(atan2(VF[3], VF[1])) % 360
	local kx = 4.5 * KR / 20
	local t0 = math.ceil((hd - 20) / 2) * 2
	for k = 1, 21 do
		local a = t0 + 2 * (k - 1)
		local s = TK[k]
		if a <= hd + 20 then
			s.on:set(1); s.x:set((a - hd) * kx); s.l:set((floor(a + 0.5) % 10 == 0) and 1 or 0)
		else s.on:set(0) end
	end
	local l0 = math.ceil((hd - 20) / 10) * 10
	for k = 1, 5 do
		local a = l0 + 10 * (k - 1)
		local s = TL[k]
		if a <= hd + 20 then
			s.on:set(1); s.x:set((a - hd) * kx)
			local v = floor(((a % 360) + 0.5) / 10) % 36
			s.v:set(v == 0 and 36 or v)
		else s.on:set(0) end
	end
	if F.wp_on then
		local dN, dE = F.wp_x - ox, F.wp_z - oz
		local dist = sqrt(dN * dN + dE * dE)
		O.wp_on:set(1); O.wp_r:set(floor(dist / NM * 10 + 0.5) / 10)
		local gs = sqrt((svx or 0) ^ 2 + (svz or 0) ^ 2)
		local ttg = gs > 30 and dist / gs / 60 or -1
		O.wp_ttg:set(ttg >= 0 and ttg < 999 and floor(ttg + 0.5) or -1)
		local diff = wrap180(deg(atan2(dE, dN)) - hd)
		O.cmd_on:set(aa and 0 or 1); O.cmd_x:set(max(-20.5, min(20.5, diff)) * kx)
	else
		O.wp_on:set(0); O.cmd_on:set(0)
	end

	-- the radar lock, predicted to now
	local lock = F.lk_on
	local age = t - F.lk_t
	if not lock or age < 0 or age > 3 then
		hide_lock()
	else
		local vx, vz = F.lk_vx, F.lk_vz
		local tx, tz, ty = F.lk_x + vx * age, F.lk_z + vz * age, F.lk_y
		local dN, dE, dU = tx - ox, tz - oz, ty - oy
		local rng = sqrt(dN * dN + dE * dE + dU * dU)
		local rnm = rng / NM
		O.lk:set(aa and 1 or 0)
		O.rng:set(floor(rnm * 10 + 0.5) / 10)
		-- closure
		local vc = 0
		if svx and rng > 1 then
			vc = -((vx - svx) * dN + (0 - (svy or 0)) * dU + (vz - (svz or 0)) * dE) / rng * KT
		end
		O.vc:set(floor(vc + 0.5))
		-- aspect (0 = tail, 180 = head-on), R / L = which side of the target we see
		local v = sqrt(vx * vx + vz * vz)
		local asp, side = nil, 1
		if v > 5 then
			local a = wrap180(deg(atan2(-dE, -dN) - atan2(vz, vx)))
			side = a >= 0 and 1 or -1
			asp = 180 - abs(a)
			if asp >= 175 then O.asp:set("H")
			elseif asp <= 5 then O.asp:set("T")
			else O.asp:set(string.format("%d%s", floor(asp / 10 + 0.5), side > 0 and "R" or "L")) end
		else
			O.asp:set("")
		end
		-- target in the jet's frame: off the nose
		local bf, bu, br = dot3(BF, dN, dU, dE), dot3(BU, dN, dU, dE), dot3(BR, dN, dU, dE)
		local t_az, t_el = deg(atan2(br, bf)), deg(atan2(bu, sqrt(bf * bf + br * br)))
		local off = deg(math.acos(max(-1, min(1, bf / max(rng, 1)))))
		-- ID, shoot cue, altitude
		O.td_id:set(F.lk_id)
		local ra, rm, rp, rt = F.ra, F.rm, F.rp, F.rt
		O.shoot:set((rp > 0 and rnm < rp and rnm > rm) and 1 or 0)
		local hh = floor(ty / FT / 100 + 0.5)
		O.td_a:set(string.format("%d %d", floor(hh / 10), hh % 10))
		-- TD box in the visor's field, else the locator line
		local rx, uy, c = view(dN, dU, dE)
		local x, y = inside(rx, uy, c)
		if x then
			O.td_x:set(x); O.td_y:set(y); O.td_on:set(1); O.tll_on:set(0)
		else
			O.td_on:set(0)
			local a = atan2(uy, rx)
			O.tll_a:set(a); O.tle_x:set(5.8 * KR * cos(a)); O.tle_y:set(5.8 * KR * sin(a))
			O.tll_d:set(max(0, floor((HMD.GIMBAL_DEG or 60) - off + 0.5)))
			O.tll_on:set(1)
		end
		-- launch envelope and ASE: missiles in A/A
		if aa and ra > 0 and (wk == 1 or wk == 2) then
			local sc, need = 160, max(rnm * 1.1, ra)
			for i = 1, #DLZ_SCALES do if DLZ_SCALES[i] >= need then sc = DLZ_SCALES[i]; break end end
			O.dlz_on:set(1); O.dlz_sc:set(sc)
			local L = 5.1 * KR
			dlz_mark("DLZ_RA", ra, sc, L); dlz_mark("DLZ_RP", rp, sc, L); dlz_mark("DLZ_RT", rt, sc, L)
			dlz_mark("DLZ_RM", rm, sc, L); dlz_mark("DLZ_TG", min(rnm, sc), sc, L)
			O.dlz_rmf:set(rm / sc); O.dlz_rtf:set(rt > 0 and rt / sc or -1)
			-- ASE: dashed for radar missiles, solid for AIM-9; the dot = the
			-- target off the nose (the circle's edge = 30 deg)
			O.ase_k:set(wk)
			local R, full = 2.4 * KR, 30
			local dx, dy = t_az / full * R, t_el / full * R
			local m = sqrt(dx * dx + dy * dy)
			if m > R * 1.1 then dx, dy = dx / m * R * 1.1, dy / m * R * 1.1 end
			O.ase_dx:set(dx); O.ase_dy:set(dy)
			if asp then O.asp_on:set(1); O.asp_a:set(side * rad(asp)) else O.asp_on:set(0) end
			O.att_on:set(0)
		else
			O.dlz_on:set(0); O.ase_k:set(0); O.att_on:set(1)
		end
	end

	-- datalink contacts and SAMs in the visor's field (flight members: at
	-- the edge when outside), nearest first
	local nc = 0
	local lx, lz = nil, nil
	if lock and age >= 0 and age <= 3 then lx, lz = F.lk_x, F.lk_z end
	for n = 1, CN do
		local s = CC[n]
		local k = s.k
		local a = min(max(t - s.t, 0), 20)
		local dN, dE, dU = s.x + s.vx * a - ox, s.z + s.vz * a - oz, s.y - oy
		local rng = sqrt(dN * dN + dE * dE + dU * dU)
		-- (the locked target has its TD box)
		local same = lx and k ~= 5 and abs(s.x - lx) < 600 and abs(s.z - lz) < 600
		if rng > 50 and not same then
			local rx, uy, c = view(dN, dU, dE)
			local x, y = inside(rx, uy, c)
			-- flight members: never beyond the EDGE_DEG circle (outside it,
			-- or outside the field, they sit on it in their direction)
			if k == 2 and (not x or x * x + y * y > EDGE2) then
				local m = sqrt(rx * rx + uy * uy)
				if m > 0 then x, y = rx / m * EDGE_T, uy / m * EDGE_T else x = nil end
			end
			if x then
				nc = nc + 1
				local e = CL[nc]
				e.x, e.y, e.k, e.rng, e.l = x, y, k, rng, s.l
			end
		end
	end
	-- more than fit: the nearest (a full sort only then)
	if nc > MAXC then
		for n = nc + 1, #CL do CL[n].rng = 1e12 end
		table.sort(CL, by_range)
	end
	for n = 1, MAXC do
		local o = C[n]
		local e = CL[n]
		if n <= nc then
			local l = e.l
			o.x:set(e.x); o.y:set(e.y)
			-- (a SAM's number goes to a number field: a number in a text field crashes DCS)
			if e.k == 5 and tonumber(l) then o.k:set(5); o.nn:set(tonumber(l))
			elseif e.k == 5 then o.k:set(6); o.l:set(safe(l))
			else o.k:set(e.k); o.l:set(safe(l)) end
			o.r:set(floor(e.rng / NM * 10 + 0.5) / 10)
			o.on:set(1)
		else
			o.on:set(0)
		end
	end
end

function update()
	local ok, err = pcall(update_hmd)
	if not ok then log("update error: " .. tostring(err)) end
end

function post_initialize()
	log("=== F-15C SIT JHMCS device")
end

need_to_be_closed = false
