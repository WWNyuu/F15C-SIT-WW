F-15C SIT (WW) 1.1 - SIT page and JHMCS for the Flaming Cliffs F-15C
=====================================================================

All controls, what they do and where to bind them:
F-15C SIT Controls Guide.pdf (in this folder).

New in 1.1
----------
- JHMCS helmet display with its own cockpit panel
- Real F-15C style HOTAS: auto acq switch (helmet acquisition, long range
  boresight, vertical scan, return to search), Supersearch, boresight,
  weapon select switch (GUN / SRM / MRM), missile reject, target step and
  unlock, castle down hold for declutter
- SIT contacts and the acquisition mode stay visible through the HUD
- Weapon inventory line with missile models (e.g. A4C M2MH S2M G9)
- Own radar: TWS tracks and STT locks follow the target accurately
- Missile in flight: flashing fly-out line, missile circle that turns into an
  X at 7 NM from the target (AIM-120, MPRF), smaller magenta time to impact
- Gun mode shown on the helmet; SIT page export to a second monitor

Adds a working SIT (tactical situation) page and its menu pages to the
lower-left MPCD of the Flaming Cliffs F-15C, modelled on the real jet, plus a JHMCS
helmet display with its own cockpit panel.

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

JHMCS helmet display (new in 1.1)
---------------------------------
- Green helmet symbology that follows your head: heading tape (look
  heading, aircraft heading under the caret), IAS, altitude, Mach, G,
  selected weapon / gun rounds, NAV steerpoint range.
- A/A: locked target box with range, altitude, shoot cue and launch zone,
  a locator line pointing to the target when it is off the display, and
  datalink / flight member contacts. Contacts outside the display are
  pinned at the edge (20 degrees).
- It blanks where you look down into the cockpit; through the HUD only the
  datalink contacts and the acquisition mode stay.
- Helmet panel: left console, behind the caution lights. ON / OFF switch
  and a brightness knob (scroll). Hot and air starts begin ON, full bright.
- Works in VR (drawn on the helmet, the same picture in both eyes).

Monitor export
--------------
The SIT page can go to a second monitor: name a viewport F15C_SIT in your
monitor setup file (Saved Games\DCS\Config\MonitorSetup\...), or use
RIGHT_MFCD as a fallback. Without either nothing changes.

Controls (Options > Controls > F-15C, category "F-15C SIT")
---------------------------------------------------------
- Castle switch up / down / left / right: up gives the cursor to the SIT
  page (and back to the radar), right = decenter, left = EXP, down = F5
  (hold down 1 s = declutter step)
- Auto Acq Switch: forward short = helmet acquisition (radar locks where
  you look; without the helmet: FC3 boresight), forward hold 1 s = long
  range boresight (follows the helmet), aft = vertical scan, depress =
  return to search
- Supersearch (nose, 20 deg, 10 NM) and Boresight: own switches
- Weapon Select Switch forward / center / aft = GUN / SRM / MRM, Missile
  Reject Switch = next missile type of the same kind
- Target Step (TWS: next tracked target), Unlock Target (STT: back to
  search, TWS: drop the primary track)
- SIT Cursor keys and axes (the jet's TDC slew also moves the SIT cursor
  while the SIT page has it), SIT Range Increase / Decrease (the radar's
  zoom keys also work while the SIT page has the cursor), SIT Declutter
- SIT Mark Point / Delete Mark Point
- CMD Dispense / Next program, Combat Jettison
- UHF-1 / UHF-2 Channel Up / Down (SRS)
- the 20 MPCD buttons
- HMD Power ON/OFF (mutes the helmet display without moving the switch),
  HMD Brightness Increase / Decrease, HMD Symbology ON/OFF

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
  no EWR reports); everything else stays on. FC3 gives the add-on only the
  targets you lock (STT, or the tracks in TWS) and the odd search contact,
  so with the datalink off lock targets to see them on the SIT
- JHMCS helmet display: off = no helmet display at all
- HMD size, %: 50 to 200, scales the helmet symbology
- Timing and debug logs: for testing only (off by default)

Multiplayer
-----------
The datalink picture needs the server to allow object export. Servers that
block it still send EWR picture reports as text messages: those are drawn on
the SIT page instead.

Logs (Saved Games\DCS\Logs): f15sit_device.log, f15sit_export.log, f15sit_hook.log,
f15sit_acq.log (auto acquisition), f15sit_wpn.log (weapon switches, target step)
