-- F-15C SIT (WW): JHMCS head display (HELMET type, no anchors)
dofile(LockOn_Options.common_script_path .. "devices_defs.lua")
indicator_type = indicator_types.HELMET
purposes       = {render_purpose.GENERAL}
page_subsets   = {LockOn_Options.script_path .. "HMD/hmd_head.lua"}
pages          = {{1}}
init_pageID    = 1
use_parser     = false
