-- F-15C SIT (WW) BINDS BEGIN (F-15C SIT add-on: these lines are the add-on's, its installer puts them in and takes them out)
do
	-- the jet's command numbers, for the add-on's export script (countermeasure
	-- programs and combat jettison press these "keys")
	pcall(function()
		local l = require("lfs")
		local f = io.open(l.writedir() .. "Logs/f15sit_icmd.lua", "w")
		if f then
			f:write("return {chaff = " .. tostring(iCommandPlaneDropChaffOnce) .. ", flare = " .. tostring(iCommandPlaneDropFlareOnce) ..
				", snar = " .. tostring(iCommandPlaneDropSnar) .. ", jett = " .. tostring(iCommandPlaneJettisonWeapons) ..
				", tanks = " .. tostring(iCommandPlaneJettisonFuelTanks) ..
				-- radar cursor (TDC) slew: keys, the key-up stop, axes
				", left = " .. tostring(iCommandPlaneRadarLeft) .. ", right = " .. tostring(iCommandPlaneRadarRight) ..
				", up = " .. tostring(iCommandPlaneRadarUp) .. ", down = " .. tostring(iCommandPlaneRadarDown) ..
				", stop = " .. tostring(iCommandPlaneRadarStop) ..
				", axis_h = " .. tostring(iCommandPlaneRadarHorizontal) .. ", axis_v = " .. tostring(iCommandPlaneRadarVertical) ..
				", axis_h_abs = " .. tostring(iCommandPlaneRadarHorizontalAbs) .. ", axis_v_abs = " .. tostring(iCommandPlaneRadarVerticalAbs) ..
				-- "TDC Slew Horizontal / Vertical" (the pilot's slew axis)
				", sel_h = " .. tostring(iCommandPlaneSelecterHorizontalAbs) .. ", sel_v = " .. tostring(iCommandPlaneSelecterVerticalAbs) ..
				", zoom_in = " .. tostring(iCommandPlaneZoomIn) .. ", zoom_out = " .. tostring(iCommandPlaneZoomOut) ..
				", power = " .. tostring(iCommandPowerOnOff) .. "}\n")
			f:close()
		end
	end)
end
join(res.keyCommands, {
{down = 6101, value_down = 1, name = _('Castle Switch - Up (SIT / VSD cursor)'), category = _('F-15C SIT')},
{down = 6102, value_down = 1, name = _('Castle Switch - Down (SIT: Formation F5)'), category = _('F-15C SIT')},
{down = 6103, value_down = 1, name = _('Castle Switch - Left (SIT: EXP / A/A: back to SIT)'), category = _('F-15C SIT')},
{down = 6104, value_down = 1, name = _('Castle Switch - Right (SIT: Decenter / VSD: A/A page)'), category = _('F-15C SIT')},
{down = 6105, value_down = 1, name = _('CMD - Dispense selected program'), category = _('F-15C SIT')},
{down = 6106, value_down = 1, name = _('CMD - Next program'), category = _('F-15C SIT')},
{down = 6107, value_down = 1, name = _('Combat Jettison (CBT JETT program)'), category = _('F-15C SIT')},
{down = 6108, value_down = 1, name = _('SIT Declutter (step)'), category = _('F-15C SIT')},
{down = 6109, value_down = 1, name = _('SIT Range Increase'), category = _('F-15C SIT')},
{down = 6120, value_down = 1, name = _('SIT Range Decrease'), category = _('F-15C SIT')},
{down = 6141, value_down = 1, name = _('SIT Mark Point (at the cursor)'), category = _('F-15C SIT')},
{down = 6142, value_down = 1, name = _('SIT Delete Mark Point (at the cursor / newest)'), category = _('F-15C SIT')},
{down = 6116, value_down = 1, name = _('UHF-1 (mission) Channel Up - SRS'), category = _('F-15C SIT')},
{down = 6117, value_down = 1, name = _('UHF-1 (mission) Channel Down - SRS'), category = _('F-15C SIT')},
{down = 6118, value_down = 1, name = _('UHF-2 (flight) Channel Up - SRS'), category = _('F-15C SIT')},
{down = 6119, value_down = 1, name = _('UHF-2 (flight) Channel Down - SRS'), category = _('F-15C SIT')},
{down = 6110, up = 6110, value_down = 1, value_up = 0, name = _('SIT Cursor - Left'), category = _('F-15C SIT')},
{down = 6111, up = 6111, value_down = 1, value_up = 0, name = _('SIT Cursor - Right'), category = _('F-15C SIT')},
{down = 6112, up = 6112, value_down = 1, value_up = 0, name = _('SIT Cursor - Up'), category = _('F-15C SIT')},
{down = 6113, up = 6113, value_down = 1, value_up = 0, name = _('SIT Cursor - Down'), category = _('F-15C SIT')},
{down = 6121, value_down = 1, value_up = 0, up = 6121, name = _('MPCD Lower Left - Top 1'), category = _('F-15C SIT')},
{down = 6122, value_down = 1, value_up = 0, up = 6122, name = _('MPCD Lower Left - Top 2'), category = _('F-15C SIT')},
{down = 6123, value_down = 1, value_up = 0, up = 6123, name = _('MPCD Lower Left - Top 3'), category = _('F-15C SIT')},
{down = 6124, value_down = 1, value_up = 0, up = 6124, name = _('MPCD Lower Left - Top 4'), category = _('F-15C SIT')},
{down = 6125, value_down = 1, value_up = 0, up = 6125, name = _('MPCD Lower Left - Top 5'), category = _('F-15C SIT')},
{down = 6126, value_down = 1, value_up = 0, up = 6126, name = _('MPCD Lower Left - Bottom 1'), category = _('F-15C SIT')},
{down = 6127, value_down = 1, value_up = 0, up = 6127, name = _('MPCD Lower Left - Bottom 2'), category = _('F-15C SIT')},
{down = 6128, value_down = 1, value_up = 0, up = 6128, name = _('MPCD Lower Left - Bottom 3'), category = _('F-15C SIT')},
{down = 6129, value_down = 1, value_up = 0, up = 6129, name = _('MPCD Lower Left - Bottom 4'), category = _('F-15C SIT')},
{down = 6130, value_down = 1, value_up = 0, up = 6130, name = _('MPCD Lower Left - Bottom 5'), category = _('F-15C SIT')},
{down = 6131, value_down = 1, value_up = 0, up = 6131, name = _('MPCD Lower Left - Left 1'), category = _('F-15C SIT')},
{down = 6132, value_down = 1, value_up = 0, up = 6132, name = _('MPCD Lower Left - Left 2'), category = _('F-15C SIT')},
{down = 6133, value_down = 1, value_up = 0, up = 6133, name = _('MPCD Lower Left - Left 3'), category = _('F-15C SIT')},
{down = 6134, value_down = 1, value_up = 0, up = 6134, name = _('MPCD Lower Left - Left 4'), category = _('F-15C SIT')},
{down = 6135, value_down = 1, value_up = 0, up = 6135, name = _('MPCD Lower Left - Left 5'), category = _('F-15C SIT')},
{down = 6136, value_down = 1, value_up = 0, up = 6136, name = _('MPCD Lower Left - Right 1'), category = _('F-15C SIT')},
{down = 6137, value_down = 1, value_up = 0, up = 6137, name = _('MPCD Lower Left - Right 2'), category = _('F-15C SIT')},
{down = 6138, value_down = 1, value_up = 0, up = 6138, name = _('MPCD Lower Left - Right 3'), category = _('F-15C SIT')},
{down = 6139, value_down = 1, value_up = 0, up = 6139, name = _('MPCD Lower Left - Right 4'), category = _('F-15C SIT')},
{down = 6140, value_down = 1, value_up = 0, up = 6140, name = _('MPCD Lower Left - Right 5'), category = _('F-15C SIT')},
})
if res.axisCommands then
	join(res.axisCommands, {
	{action = 6114, name = _('SIT Cursor - Horizontal (axis)'), category = _('F-15C SIT')},
	{action = 6115, name = _('SIT Cursor - Vertical (axis)'), category = _('F-15C SIT')},
	})
end
-- F-15C SIT (WW) BINDS END
