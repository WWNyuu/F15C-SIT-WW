local DbOption = require('Options.DbOption')
local Range    = DbOption.Range

return {
	f15c_sit_enabled  = DbOption.new():setValue(true):checkbox(),
	f15c_sit_datalink = DbOption.new():setValue(true):checkbox(),
	f15c_sit_logs     = DbOption.new():setValue(false):checkbox(),
	-- JHMCS helmet display: on/off, size in percent (as ED's MiG-29 TDC slider)
	f15c_sit_hmd      = DbOption.new():setValue(true):checkbox(),
	f15c_sit_hmd_size = DbOption.new():setValue(100):slider(Range(50, 200)),
}
