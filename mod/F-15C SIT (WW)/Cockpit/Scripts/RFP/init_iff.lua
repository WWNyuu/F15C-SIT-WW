-- F-15C SIT (WW): IFF MODE 3/A window, our own digits over ED's (anchors IFF_C / IFF_B / IFF_R)
dofile(LockOn_Options.common_script_path .. "devices_defs.lua")
indicator_type = indicator_types.COMMON
purposes       = {render_purpose.GENERAL}
page_subsets   = {LockOn_Options.script_path .. "RFP/iff_page.lua"}
pages          = {{1}}
init_pageID    = 1
