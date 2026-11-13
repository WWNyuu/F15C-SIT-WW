-- F-15C SIT (WW): the add-on's model.
-- Loads Shapes/F15C_SIT.edm into the cockpit, the way KRN's
-- mainpanel_init.lua loads UFCP.edm with shape_name = "UFCP".

shape_name = "F15C_SIT"

local controllers = LoRegisterPanelControls()

need_to_be_closed = true -- close lua state after initialization
