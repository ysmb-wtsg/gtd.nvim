local M = {}
local path = vim.fn.stdpath("data") .. "/gtd.nvim.json"

local function file_exists()
	local f = io.open(path, "r")
	if f then
		f:close()
		return true
	end
	return false
end

function M.load()
	if not file_exists() then
		return {}
	end
	local f = io.open(path, "r")
	local content = f:read("*a")
	f:close()
	return vim.fn.json_decode(content)
end

function M.save(data)
	local f = io.open(path, "w")
	f:write(vim.fn.json_encode(data))
	f:close()
end

return M
