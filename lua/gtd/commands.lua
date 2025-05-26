local M = {}
local ui = require("gtd.ui")

function M.setup()
	vim.api.nvim_create_user_command("GtdOpen", function()
		ui.open()
	end, {})
end

return M
