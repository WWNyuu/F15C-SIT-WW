-- F-15C SIT (WW): SIT page indicator
dofile(LockOn_Options.common_script_path .. "devices_defs.lua")

indicator_type = indicator_types.COMMON
purposes       = {render_purpose.GENERAL}

BASE = 1
page_subsets = {
	[BASE] = LockOn_Options.script_path .. "SIT/indicator/sit_page.lua",
}
pages        = {{BASE}}
init_pageID  = 1
