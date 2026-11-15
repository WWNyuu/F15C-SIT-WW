-- F-15C SIT (WW): front UHF-1 radio panel and IFF MODE 3/A window, our
-- own number drums over ED's (anchors RFP_C / RFP_B / RFP_R)
dofile(LockOn_Options.common_script_path .. "devices_defs.lua")
indicator_type = indicator_types.COMMON
purposes       = {render_purpose.GENERAL}
page_subsets   = {LockOn_Options.script_path .. "RFP/rfp_page.lua"}
pages          = {{1}}
init_pageID    = 1
