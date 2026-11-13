F-15C SIT (WW) 1.0 - SIT page for the Flaming Cliffs F-15C
==========================================================

Adds a working SIT (tactical situation) page and its menu pages to the
lower-left MPCD of the Flaming Cliffs F-15C, modelled on the real jet.

Install
-------
1. This folder goes to  Saved Games\DCS\Mods\tech\F-15C SIT (WW)\
2. Close DCS, run INSTALL.bat (in this folder). It
   - copies Scripts\F15SIT_Export.lua and Scripts\Hooks\F15SIT_hook.lua
     into Saved Games\DCS\Scripts
   - adds one line to Saved Games\DCS\Scripts\Export.lua
   - adds the add-on's controls to the F-15C's controls
     (Options > Controls > F-15C, category "F-15C SIT")
3. After every DCS update or repair: run INSTALL.bat again. DCS puts its own
   controls files back and the add-on's controls disappear until you do.
   Your own key assignments are kept and come back with them.

Uninstall
---------
UNINSTALL.bat takes the controls, the Export.lua line and the scripts out
again. Then delete this folder.

The display
-----------
- Power: the display is dark until the jet has power (electric power switch
  or an engine running), then runs a short self test and opens on the DTM
  page. Hot and air starts begin on the SIT page.
- Below the display: OFF / NIGHT / DAY knob (left click toward OFF, right
  click toward DAY) and the BRT rocker (left click brighter, right click
  dimmer). All 20 display buttons are clickable.
- SIT page: own radar contacts and scan, datalink picture (AWACS / EWR,
  flight members, datalink fighters), threat rings, route and active
  steerpoint, bullseye, mission drawings, own missiles in flight with time
  to impact, mark points, hooked-contact data. Range and centre / decentre
  as on the real page; AUTO range follows the radar.
- SIT SETTINGS (SIT left 5 "SET"): datalink status, DL / route / threat
  rings / lines on or off, course line, declutter, auto range.
- MENU pages: A/A (stores, chaff / flares, ICS), CMDS programs, combat
  jettison, weapon load, time / date, own data, flight data (pick your flight
  members), RADIO, DTM cartridges.

Controls (Options > Controls > F-15C, category "F-15C SIT")
---------------------------------------------------------
- Castle switch up / down / left / right: up gives the cursor to the SIT
  page (and back to the radar), right = decenter, left = EXP, down = F5
- SIT Cursor keys and axes (the jet's TDC slew also moves the SIT cursor
  while the SIT page has it), SIT Range Increase / Decrease (the radar's
  zoom keys also work while the SIT page has the cursor), SIT Declutter
- SIT Mark Point / Delete Mark Point
- CMD Dispense / Next program, Combat Jettison
- UHF-1 / UHF-2 Channel Up / Down (SRS)
- the 20 MPCD buttons

Radios (SRS)
------------
The RADIO page shows UHF-1 (mission) and UHF-2 (flight) with 20 presets each
(the mission's, or a DTM cartridge's). Picking a channel tunes SRS (its UDP
command port, 9040 by default - SRS client setting). Channel frequencies can
be changed on the page.

DTM Planner
-----------
DTM Planner\F-15C DTM Planner.html (open it in a browser): route, bullseye,
drawings, radio presets and CMDS programs as cartridges, loaded in the jet on
the DTM page.

Options > Special > F-15C SIT
-----------------------------
- F-15C SIT add-on: off = the stock F-15C, nothing of the add-on runs
- Datalink: off = own radar only on the SIT (no AWACS / flight contacts,
  no EWR reports); everything else stays on
- Timing and debug logs: for testing only (off by default)

Multiplayer
-----------
The datalink picture needs the server to allow object export. Servers that
block it still send EWR picture reports as text messages: those are drawn on
the SIT page instead.

Logs (Saved Games\DCS\Logs): f15sit_device.log, f15sit_export.log, f15sit_hook.log
