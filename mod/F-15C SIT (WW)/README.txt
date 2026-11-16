F-15C SIT (WW) 1.3 - SIT page and JHMCS for the Flaming Cliffs F-15C
=====================================================================

All controls, what they do and where to bind them:
F-15C SIT Controls Guide.pdf (in this folder).

New in 1.3
----------
- SIT radar lock: castle up (SIT has the cursor), put the cursor on a
  contact, press your radar lock key - the radar slews onto that contact
  and locks it (only what the radar can see: inside its +-60 deg and range;
  gives up after 15 s)
- Helmet shows contacts and SAM rings only out to the SIT page's range
  (own flight members always); sit_config.lua SIT.HMD_SIT_RANGE = false
  for the old behaviour
- Flight members no longer shown twice on the helmet (member and its
  datalink contact are matched where both are now)
- EXP mode: the compass rose no longer spills past the display; the
  ownship symbol hides when EXP is far from it
- Cleaner text in VR: MFD font with heavier strokes, radio / IFF digits,
  both without the ghost edges and block noise at a distance
- "NO EXPORT DATA" on the SIT status line (and a line in the device log)
  when the export script sends nothing - Export.lua line missing or blocked
- The installer puts its Export.lua line at the TOP, so another tool's
  broken line above it cannot stop it (older installs: run INSTALL.bat)
- Removed an unused RWR packet from the export script

New in 1.2
----------
- Front UHF-1 radio panel (centre panel, under the HUD) works: channel
  knob, the three frequency knobs (MAN), volume (SRS) and the CHAN / MAN /
  GUARD knob; the CHAN and MAIN FREQ windows show the radio
- IFF MODE 3/A wheels set the SRS transponder code, I/P = IDENT
- SRS volume for UHF-1 / UHF-2: RADIO page and binds, 5 % steps
- FLIGHT DATA page redesigned: four slots, put any aircraft (and yourself)
  in any slot
- SIT page WP+ / WP- (left 1 / 2): step the SIT's steerpoint
- DTM cartridges become Route Tool presets ("F-15C DTC: <name>"): pick one
  before you spawn and the jet flies the cartridge's route (HUD steering)
- Exterior lights panel: FORMATION knob = anti-collision lights, POSITION
  knob = navigation lights (click)

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
   - adds one line at the top of Saved Games\DCS\Scripts\Export.lua (so a
     broken line of another tool above it cannot stop it)
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
  jettison, weapon load, time / date, own data, flight data, RADIO, DTM
  cartridges.
- SIT page left 1 / 2: WP+ / WP- step the SIT's highlighted steerpoint (the
  jet's own waypoint, and the HUD, stay). Until pressed, and again after a
  DTM READ, the SIT follows the jet's waypoint.
- FLIGHT DATA (MENU, right 3): left L1..L5 the friendly aircraft on the
  datalink (their slot number in front, * = player), right R1..R4 your
  flight as four cards (number, callsign, bearing / range, altitude,
  speed; yours green). Pick an aircraft, then a slot (or a slot, then an
  aircraft); a slot, then another slot swaps them. CLR empties the picked
  slot, AUTO (boxed while on) puts your group in callsign order, you at
  your own number. UP / DN page the list. Kept for the next flight.

Front radio panel and IFF (new in 1.2)
--------------------------------------
Centre panel, under the HUD. ED's knobs can not be turned from a mod: they
stay still, the numbers in the windows show the radio.
- CHAN knob: left click up, right click down through UHF-1's 20 presets
- The three frequency knobs: 10 MHz / 1 MHz / 25 kHz steps (left click up,
  right click down); switches UHF-1 to MAN (225.000 - 399.975)
- Mode knob: CHAN (the preset) / MAN (the frequency knobs) / GUARD (243.000)
- VOL: SRS volume of UHF-1
- IFF MODE 3/A: click the thumbwheel left of each digit (left click down,
  right click up); the code goes to SRS (its IFF run from the SRS overlay,
  as for Flaming Cliffs jets). I/P: IDENT for 18 s. Code and manual
  frequency are kept for the next flight.
- Exterior lights panel (left console): FORMATION knob = anti-collision
  lights on / off, POSITION knob = navigation lights on / off

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
- UHF-1 / UHF-2 Channel Up / Down (SRS), UHF-1 / UHF-2 Volume Up / Down (SRS)
- the 20 MPCD buttons
- HMD Power ON/OFF (mutes the helmet display without moving the switch),
  HMD Brightness Increase / Decrease, HMD Symbology ON/OFF

Radios (SRS)
------------
The RADIO page shows UHF-1 (mission) and UHF-2 (flight) with 20 presets each
(the mission's, or a DTM cartridge's). Picking a channel tunes SRS (its UDP
command port, 9040 by default - SRS client setting). Channel frequencies can
be changed on the page. VOL + / - (left 3 / 4 UHF-1, right 3 / 4 UHF-2) and
the volume binds set SRS's volume in 5 % steps (both radios start at 80 %).

DTM Planner
-----------
DTM Planner\F-15C DTM Planner.html (open it in a browser): route, bullseye,
drawings, radio presets and CMDS programs as cartridges, loaded in the jet on
the DTM page. Save them into Saved Games\DCS\DTC\F-15C (NAME.dtc and
NAME.geo.txt).
The jet's own steerpoints (HUD steering) come from the mission at spawn.
Every cartridge is also a Route Tool preset "F-15C DTC: NAME" (the add-on
keeps Saved Games\DCS\Config\RouteToolPresets up to date; your own presets
stay): before you spawn, open the Route Tool on the F10 map, pick it and
tick USE THIS ROUTE ON NEXT SPAWN. Cartridges saved before 1.2: save them
again from the planner once.

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
