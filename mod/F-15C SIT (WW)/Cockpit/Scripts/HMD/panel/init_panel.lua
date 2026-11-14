-- F-15C SIT (WW): JHMCS control panel, plate markings (anchors HMDP_*)
dofile(LockOn_Options.common_script_path .. "devices_defs.lua")
indicator_type = indicator_types.COMMON
purposes       = {render_purpose.GENERAL}
page_subsets   = {LockOn_Options.script_path .. "HMD/panel/panel_page.lua"}
pages          = {{1}}
init_pageID    = 1
