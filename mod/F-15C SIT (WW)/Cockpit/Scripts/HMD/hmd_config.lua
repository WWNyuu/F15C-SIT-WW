-----------------------------------------------------------------------
-- F-15C SIT (WW): JHMCS settings (helmet device and helmet display)
-- Angles in degrees. Layout after the F-15C JHMCS windows (unclassified
-- flight manual, figures A1-156 / A1-157): the visor shows a 20 deg circle.
-----------------------------------------------------------------------
HMD = HMD or {}

HMD.FOV_DEG      = 25      -- world symbols (contacts, TD box) within this many degrees of the view;
                           -- beyond it the locator line (the real JHMCS: a 20 deg circle)
HMD.EDGE_DEG     = 20      -- flight members never beyond this circle (farther out: kept on it)
HMD.SCALE        = 1.44    -- the whole fixed layout and its text bigger / smaller (1.0 = the real
                           -- 20 deg circle; Options > Special "HMD size" multiplies this)
HMD.TEXT         = 0.016   -- text size (stroke font, glyph cell height)

-- HUD blanking: looking through the HUD hides the helmet symbology, as in
-- the real jet. The HUD's field, in degrees from the jet's nose
-- (azimuth +-HUD_AZ, elevation HUD_EL_LO .. HUD_EL_HI)
HMD.HUD_BLANK    = true
-- ...except the datalink contacts (and the acquisition mode), which stay
-- through the HUD: FC3's HUD has no SIT contacts of its own
HMD.HUD_CONTACTS = true
HMD.HUD_AZ       = 10
HMD.HUD_EL_LO    = -40     -- (down into the cockpit: no sliver between the HUD and the glare shield)
HMD.HUD_EL_HI    = 6

-- datalink (SIT) contacts on the helmet: up to this many, nearest first
HMD.CONTACTS     = true
HMD.MAX_CONTACTS = 16
HMD.SAMS         = true    -- surveillance SAMs (the SIT page's threat rings)

-- radar gimbal limit, for the locator line's "degrees before breaklock"
HMD.GIMBAL_DEG   = 60

-- power-up: helmet alignment messages (window H1)
HMD.ALIGN_MSG    = true
HMD.CROSS        = false   -- an aiming cross in the centre (not in the manual's figures)

-- colour: the real JHMCS is green. Solid drawing keeps it green on a bright
-- sky; ADDITIVE = true blends it into the background (looks pale / cyan)
HMD.COLOR        = {26, 174, 26, 255}    -- (pure green, 15 % darker again: softer against the sky)
HMD.ADDITIVE     = false


-- cockpit blanking, as the real JHMCS: blank while looking into the cockpit.
-- The cockpit's edge (glare shield ahead, canopy rail beside and behind),
-- measured in the sim: {degrees left/right of the nose, degrees below the
-- nose line}, both sides alike, blended between the points
HMD.CKPT_BLANK   = true
HMD.CKPT_EDGE    = {
	{0, -15}, {20, -18}, {30, -22}, {40, -28}, {50, -31}, {65, -45},
	{90, -47}, {110, -43}, {180, -42},
}

-- controls: the panel on the left console (power switch, brightness knob)
-- Start positions in a new jet:
HMD.PWR_START    = true    -- power switch ON
HMD.BRT_START    = 1.0     -- brightness knob 0..1
HMD.BRT_MIN      = 0.06    -- brightness with the knob all the way down (up = 1.0)

-- the view's direction (from the export) is a frame or two old when the
-- helmet draws: predict it from how fast the head turns (less lag and
-- jitter of the world symbols, most of all in VR). VIEW_LEAD: seconds more
HMD.VIEW_PREDICT = false   -- (off: steadier in VR, as before)
HMD.VIEW_LEAD    = 0.0

-- (the values above were just set again: Options > Special must be applied
-- to them again too, hmd_options.lua, even in a Lua state that read them before)
HMD.OPTIONS_READ = nil
