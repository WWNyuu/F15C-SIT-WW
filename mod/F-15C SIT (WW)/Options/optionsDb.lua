local DbOption = require('Options.DbOption')

return {
	f15c_sit_enabled  = DbOption.new():setValue(true):checkbox(),
	f15c_sit_datalink = DbOption.new():setValue(true):checkbox(),
	f15c_sit_logs     = DbOption.new():setValue(false):checkbox(),
}
