-----------------------------------------------
-- F-15C SIT (WW) 1.0
-- Bolt-on SIT display for the Flaming Cliffs F-15C.
-- Hooks into the F-15C the same way KRN MODS' MiG-29A(M)
-- Cockpit Modernization hooks into the MiG-29: add_plugin_systems().
-----------------------------------------------

declare_plugin("f15c_sit",
{
	installed        = true,
	dirName          = current_mod_path,
	displayName      = _("F-15C SIT (WW)"),
	shortName        = "f15c_sit",
	fileMenuName     = "f15c_sit",
	version = "1.0.0",
	state            = "installed",
	developerName    = "nyuu",
	info             = "SIT page for the Flaming Cliffs F-15C",
	binaries         = {},
	load_immediately = true,
	Options =
	{
		{
			name   = _("F-15C SIT"),
			nameId = "f15c_sit",
			dir    = "Options",
		},
	},
})

mount_vfs_texture_path(current_mod_path .. "/Textures")
mount_vfs_model_path  (current_mod_path .. "/Shapes")

-- Adds this mod's Cockpit/Scripts (device_init.lua etc.) to the F-15C's
-- own cockpit. "F-15C" is the unit type name from the F-15C's entry.lua.
-- The checkbox in Options > Special > F-15C SIT switches it on/off.
add_plugin_systems('f15c_sit', '*', current_mod_path .. '/Cockpit/Scripts/',
{
	["F-15C"] = { enable_options_key_for_unit = "f15c_sit_enabled" },
})

plugin_done()
