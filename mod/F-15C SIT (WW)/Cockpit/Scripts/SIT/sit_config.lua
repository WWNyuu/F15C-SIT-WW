-----------------------------------------------------------------------
-- F-15C SIT (WW): shared settings for the device and the page
-----------------------------------------------------------------------
SIT = SIT or {}

SIT.RANGES_NM     = {5, 10, 20, 40, 80, 160}   -- centred range steps (NM, ownship to the top edge of the SIT)
SIT.RANGES_DC_NM  = {7, 15, 30, 60, 120, 240}  -- decentred range steps (same step number as centred: 40 <-> 60)
SIT.RANGE_DEFAULT = 4                          -- 40 NM

SIT.MAX_CONTACTS  = 40      -- must match max_contacts in F15SIT_Export.lua
SIT.MAX_WPTS      = 20
SIT.MAX_THREATS   = 12
SIT.RING_SEGS     = 24      -- segments of a threat ring

-- page layout (page units: the screen runs from -1 to +1; the glass
-- opening of the stock display ends at about +-0.81)
SIT.EDGE          = 0.81    -- glass edge
SIT.BOX           = 0.76    -- symbols are hidden outside this square (labels live outside it)
SIT.CENTER_Y      = 0.0     -- centred: ownship in the middle ...
SIT.CENTER_R      = 0.65    -- ... compass rose radius = selected range
SIT.DECENTER_Y    = -0.51   -- decentred: ownship low (about 12 NM behind on the 40 scale) ...
SIT.HALF_RING     = true    -- centred: thin solid ring at half range (manual); false = off
SIT.ROSE_R        = 0.20    -- decentred: small compass rose around the ownship
-- radar coverage (cyan lines): scan centre / width / range from the radar
-- (LoGetSightingSystemInfo in the export). RADAR_SIZE_HALF: the scan width
-- the radar reports is the half width (+-); false = full width
SIT.RADAR_SIZE_HALF = false   -- v0.5: DCS reports the full width (2.094 = 120 deg)

-- page font: "texture" = the add-on's stroke font (Textures/IndicationTextures/
-- f15sit_font.dds), "arial" = DCS's Arial
SIT.FONT_STYLE    = "texture"
SIT.FONT_SCALE    = 1.0     -- all text bigger / smaller
SIT.FONT_WIDTH    = 1.0     -- letter width (lower = narrower)
SIT.FONT_CELL_W   = 68      -- texture: glyph cell width (px of 128)
SIT.FONT_CAP      = 77 / 128  -- texture: capital height / cell height

-- controller gain: DCS moves elements by controllers (moving symbols,
-- route / threat lines) in METRES on the screen, while the drawn shapes use
-- page units (-1..1). So the gain = metres per page unit = the screen's
-- half-size: 0.0606 m glass + 0.014 m margin (Blender script SCREEN_MARGIN).
-- Measured in v0.3.4 (1/30 put the N/E/S/W letters at 47 % of their place).
SIT.G             = 0.0742
SIT.PORT          = 42889   -- UDP from Scripts\F15SIT_Export.lua
SIT.STALE_S       = 8       -- datalink picture older than this = NO DL
SIT.UPDATE        = 0.05    -- device update step (s)

-- contact codes (from the export, same as the MiG-29 add-on):
--   1 friendly  2 hostile  3 unknown  4 AWACS  5 own flight  6 datalink fighter
--   +10 = the own radar holds it (solid symbol); 13 = own radar only

-- MPCD pages
SIT.PG = {SIT = 1, MENU = 2, DTM = 3, ARMT = 4, JETT = 5, LOAD = 6, BIT = 7, TIME = 8, OWN = 9, FLT = 10, WPN = 11, CMDS = 12, SETS = 13, RADIO = 14}

-- DCS F-15C weapon stations 1..11 (LoGetPayloadInfo order) and their names
SIT.STATIONS = {"2A", "2", "2B", "3", "4", "5", "6", "7", "8B", "8", "8A"}

-- BIT page rows: name, failure flags (LoGetMCPState) that make it NO GO
SIT.BIT_ROWS = {
	{"CC"},
	{"RADAR", "RadarFailure"},
	{"TEWS", "RWSFailure"},
	{"ICS", "ECMFailure"},
	{"HUD", "HUDFailure"},
	{"MPCD/VSD", "MFDFailure"},
	{"GUN", "CannonFailure"},
	{"L ENGINE", "LeftEngineFailure"},
	{"R ENGINE", "RightEngineFailure"},
	{"HYDRAULICS", "HydraulicsFailure"},
	{"CAS", "ACSFailure"},
	{"AUTOPILOT", "AutopilotFailure"},
	{"FUEL", "FuelTankDamage", "LeftMainPumpFailure", "RightMainPumpFailure", "LeftWingPumpFailure", "RightWingPumpFailure"},
	{"GEAR", "GearFailure", "StuckGear"},
}

-- Zulu time: map (mission theatre) -> hours ahead of UTC of its mission time
SIT.UTC_OFFSET = {
	Caucasus = 4, PersianGulf = 4, Syria = 3, Nevada = -8, MarianaIslands = 10, MarianasWWII = 10,
	Normandy = 1, TheChannel = 1, Falklands = -3, SinaiMap = 2, Kola = 3, Afghanistan = 4.5,
	Iraq = 3, GermanyCW = 1,
}
SIT.ZULU_DEFAULT  = true    -- SIT / MENU time in Zulu (where the map's offset is known)

-- ARMT page choices
SIT.CMD_PROGRAMS  = {"PFM", "PRG1", "PRG2", "PRG3", "PRG4", "PRG5"}
SIT.PF_MESSAGES   = {"GLOBAL", "NONAVY", "NOSI", "WFO", "GNDPRI", "AIRGND"}

-- drawings on SIT (cartridge .geo.txt / mission drawings, MENU: LINES)
SIT.GEO_SEGS      = 160     -- line pieces
SIT.GEO_LABELS    = 12      -- names
SIT.EXP_NM        = 10      -- EXP: range around the cursor
SIT.HOOK_R        = 0.07    -- a contact this close to the cursor (page units) is hooked

-- countermeasure programs (HOTAS "CMD dispense" runs the selected one):
-- {chaff, flares, interval s, cycles}. A cartridge can bring its own.
SIT.CMD_DEF = {
	PFM  = {1, 1, 0.5, 2},
	PRG1 = {1, 0, 0.5, 4},
	PRG2 = {0, 2, 0.3, 3},
	PRG3 = {2, 2, 0.5, 3},
	PRG4 = {4, 0, 0.25, 2},
	PRG5 = {0, 4, 0.25, 2},
}
-- a friendly / unknown contact this close (m) to a flight member is that
-- member (radar track and datalink report of one aircraft drawn once)
SIT.FLT_MATCH_M   = 150

-- SIT cursor (castle up): speed of the TDC slew / SIT cursor binds
SIT.SLEW_SCALE    = 1.0     -- SIT cursor speed: 1 = as fast across the SIT display as the radar cursor across the radar display; 2 = twice that
SIT.SLEW_DEADZONE = 0.08
SIT.SLEW_INVERT_Y = false   -- true if up/down on the slew comes out reversed
-- while SIT has the cursor: the radar's TDC slew is held at ~0 by the export
-- (the radar cursor stays where it is)
SIT.SQUELCH_RADAR = true

-- declutter steps (keybind "SIT Declutter" / SIT SETTINGS right 2)
SIT.DCL_NAMES = {"FULL", "NO LINES", "NO DATA", "NO RINGS", "MIN"}

-- EWR picture reports (server text messages) drawn when there is no datalink
-- picture (export blocked or off): on/off, kept for, moved along for (s)
SIT.EWR_ON        = true
SIT.EWR_KEEP_S    = 180
SIT.EWR_EXTRAP_S  = 120

-- SRS: its UDP command port (SRS client setting, default 9040). The RADIO
-- page tunes SRS's UHF-1 (radio 1) / UHF-2 (radio 2) to the picked channel.
SIT.SRS_PORT = 9040

-- own missiles in flight shown at once (export: F15SITW), mark points kept
-- power: the display comes on with the jet's power (electric power switch,
-- or an engine running), after a short start-up of BOOT_S seconds. The
-- MPCD's knob (OFF / NIGHT / DAY) and BRT rocker are clickable below it.
--   POWER_CMD   FC3's electric power switch command (Logs\f15sit_icmd.lua has
--               the number when the controls block knows it; else this)
--   RPM_ON      engine RPM (%) that counts as power without the switch
--   BRT_STEPS   brightness steps of the rocker; NIGHT = NIGHT_K of DAY
SIT.BOOT_S    = 2.8
SIT.POWER_CMD = 315
SIT.RPM_ON    = 50
SIT.BRT_STEPS = 10
SIT.NIGHT_K   = 0.35
SIT.MAX_MSL   = 4
SIT.MAX_MARKS = 8
