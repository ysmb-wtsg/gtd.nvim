local Popup = require("nui.popup")
local Input = require("nui.input")
local Menu = require("nui.menu")
local event = require("nui.utils.autocmd").event
local tasks = require("gtd.storage")

local M = {}
local popup
local task_list = {}
local selected_task_index = nil
local mode = "inbox"
local category_starts = {}
local category_order = {}

local function is_open()
	return popup and popup._.mounted
end

local function close()
	if is_open() then
		tasks.save(task_list)
		selected_task_index = nil
		popup:unmount()
		popup = nil
	end
end

local function get_existing_categories()
	local set = {}
	for _, task in ipairs(task_list) do
		if task.category and task.category ~= "" then
			set[task.category] = true
		end
	end
	local list = {}
	for name in pairs(set) do
		table.insert(list, name)
	end
	table.sort(list)
	return list
end

local function select_or_input_category(callback)
	local options = {}
	for _, name in ipairs(get_existing_categories()) do
		table.insert(options, Menu.item(name))
	end
	table.insert(options, Menu.item("[Create new category...]"))

	local menu = Menu({
		position = { row = 5, col = "50%" },
		size = { width = 40, height = 10 },
		border = { style = "single", text = { top = " Select Category ", top_align = "center" } },
	}, {
		lines = options,
		on_submit = function(item)
			if item.text == "[Create new category...]" then
				Input({
					position = { row = 5, col = "50%" },
					size = { width = 40 },
					border = { style = "single", text = { top = " New Category ", top_align = "center" } },
				}, {
					prompt = "> ",
					on_submit = function(new_cat)
						callback(new_cat)
					end,
				}):mount()
			else
				callback(item.text)
			end
		end,
	})

	menu:mount()
end

local function render()
	if not is_open() then
		return
	end
	vim.api.nvim_buf_set_option(popup.bufnr, "modifiable", true)

	local lines = {}
	local line_map = {}
	local count = 0

	local menu = mode == "inbox" and "[INBOX] | DONE" or "INBOX | [DONE]"
	popup.border:set_text("top", " " .. menu .. " ")

	local items = {}
	for i, task in ipairs(task_list) do
		local include = (mode == "inbox" and not task.done) or (mode == "done" and task.done)
		if include then
			table.insert(items, { task = task, index = i })
		end
	end

	local task_width = 30
	local due_width = 12
	local cat_width = 20
	local spacer = 2

	for _, item in ipairs(items) do
		local text = item.task.text or ""
		local due = item.task.due or "-"
		local category = item.task.category or "-"

		-- truncate with "…" if too long
		local function truncate(s, width)
			local w = vim.fn.strdisplaywidth(s)
			if w <= width then
				return s .. string.rep(" ", width - w)
			else
				return vim.fn.strcharpart(s, 0, width - 1) .. "…"
			end
		end

		local text_disp = truncate(text, task_width)
		local due_disp = truncate(due, due_width)
		local cat_disp = truncate(category, cat_width)

		local line_fmt = "%s%s%s%s%s"
		local prefix = (selected_task_index == item.index) and "> " or "  "
		local line = string.format(
			line_fmt,
			prefix .. text_disp,
			string.rep(" ", spacer),
			due_disp,
			string.rep(" ", spacer),
			cat_disp
		)

		count = count + 1
		table.insert(lines, line)
		line_map[count] = item.index
	end

	vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(popup.bufnr, "modifiable", false)

	M.line_map = line_map
end

local function refresh_lines(task)
	local lines = {
		"**Title**    : " .. (task.text or ""),
		"**Category** : " .. (task.category or ""),
		"**Due**      : " .. (task.due or ""),
		"**Done**     : " .. (task.done and "Yes" or "No"),
		"",
		"---",
		"**Memo:**",
		"",
	}
	for _, line in ipairs(vim.split(task.memo or "", "\n")) do
		table.insert(lines, line)
	end
	return lines
end

function M.open()
	mode = "inbox"
	task_list = tasks.load()

	popup = Popup({
		enter = true,
		focusable = true,
		border = {
			style = "rounded",
			text = { top = "", top_align = "center" },
		},
		position = "50%",
		size = { width = 70, height = 25 },
		buf_options = {
			modifiable = false,
			readonly = false,
		},
	})

	popup:mount()
	render()

	local first_cat = category_order[1]
	if first_cat and category_starts[first_cat] then
		vim.schedule(function()
			vim.api.nvim_win_set_cursor(0, { category_starts[first_cat], 0 })
		end)
	end

	popup:on(event.BufLeave, function()
		close()
	end)

	local function map(key, fn)
		vim.keymap.set("n", key, fn, {
			buffer = popup.bufnr,
			noremap = true,
			silent = true,
			nowait = true,
		})
	end

	map("q", function()
		close()
	end)

	map("<Tab>", function()
		mode = (mode == "inbox") and "done" or "inbox"
		selected_task_index = nil
		render()
	end)

	map("a", function()
		if mode ~= "inbox" then
			return
		end
		local today = os.date("%Y-%m-%d")
		local task = {
			text = "",
			category = "",
			due = today,
			done = false,
			memo = "",
		}

		Input({
			position = { row = 5, col = "50%" },
			size = { width = 50 },
			border = { style = "single", text = { top = " Task Title ", top_align = "center" } },
		}, {
			prompt = "Title: ",
			on_submit = function(title)
				task.text = title

				select_or_input_category(function(category)
					task.category = category

					Input({
						position = { row = 5, col = "50%" },
						size = { width = 50 },
						border = { style = "single", text = { top = " Due Date ", top_align = "center" } },
					}, {
						default_value = today,
						prompt = "Due (YYYY-MM-DD): ",
						on_submit = function(due)
							task.due = due
							table.insert(task_list, task)
							render()
						end,
					}):mount()
				end)
			end,
		}):mount()
	end)

	map("i", function()
		local line = vim.fn.line(".")
		local index = M.line_map[line]
		local task = task_list[index]
		if not task then
			return
		end

		local function refresh_lines()
			local lines = {
				"Title    : " .. (task.text or ""),
				"Category : " .. (task.category or ""),
				"Due      : " .. (task.due or ""),
				"Memo:",
				"",
				"---",
			}
			for _, line in ipairs(vim.split(task.memo or "", "\n")) do
				table.insert(lines, line)
			end
			return lines
		end

		local info_lines = refresh_lines()

		local info_popup = Popup({
			enter = true, -- フォーカス必要
			focusable = true,
			border = {
				style = "single",
				text = { top = " Task Info ", top_align = "center" },
			},
			position = { row = 8, col = "50%" },
			size = { width = 50, height = #info_lines + 2 },
			buf_options = {
				modifiable = true,
			},
		})

		info_popup:mount()
		vim.api.nvim_buf_set_lines(info_popup.bufnr, 0, -1, false, info_lines)
		vim.api.nvim_buf_set_option(info_popup.bufnr, "modifiable", false)
		vim.api.nvim_buf_set_option(info_popup.bufnr, "filetype", "markdown")
		vim.api.nvim_buf_set_option(info_popup.bufnr, "conceallevel", 2)
		vim.api.nvim_buf_set_option(info_popup.bufnr, "concealcursor", "n")

		-- 編集処理
		vim.keymap.set("n", "e", function()
			local current_line = vim.fn.line(".")
			local prop = ({
				[1] = "text",
				[2] = "category",
				[3] = "due",
				[4] = "memo",
			})[current_line]

			if not prop then
				return
			end

			if prop == "done" then
				task.done = not task.done
				tasks.save(task_list)
				vim.api.nvim_buf_set_option(info_popup.bufnr, "modifiable", true)
				vim.api.nvim_buf_set_lines(info_popup.bufnr, 0, -1, false, refresh_lines())
				vim.api.nvim_buf_set_option(info_popup.bufnr, "modifiable", false)
				return
			end

			if prop == "memo" then
				local edit_popup = Popup({
					enter = true,
					focusable = true,
					border = {
						style = "rounded",
						text = { top = " Edit Memo ", top_align = "center" },
					},
					position = { row = 5, col = "50%" },
					size = { width = 60, height = 10 },
					buf_options = {
						modifiable = true,
					},
				})
				edit_popup:mount()

				-- 初期メモの内容をセット
				local memo_lines = vim.split(task.memo or "", "\n")
				vim.api.nvim_buf_set_lines(edit_popup.bufnr, 0, -1, false, memo_lines)

				-- 書き込み後 Enter で保存、qでキャンセル
				vim.keymap.set("n", "<CR>", function()
					local new_lines = vim.api.nvim_buf_get_lines(edit_popup.bufnr, 0, -1, false)
					task.memo = table.concat(new_lines, "\n")
					tasks.save(task_list)
					edit_popup:unmount()
					vim.api.nvim_buf_set_option(info_popup.bufnr, "modifiable", true)
					vim.api.nvim_buf_set_lines(info_popup.bufnr, 0, -1, false, refresh_lines())
					vim.api.nvim_buf_set_option(info_popup.bufnr, "modifiable", false)
				end, { buffer = edit_popup.bufnr })

				vim.keymap.set("n", "q", function()
					edit_popup:unmount()
				end, { buffer = edit_popup.bufnr })
				return
			end

			local default = task[prop] or ""
			Input({
				position = { row = 10, col = "50%" },
				size = { width = 50 },
				border = {
					style = "single",
					text = { top = " Edit " .. prop:gsub("^%l", string.upper), top_align = "center" },
				},
			}, {
				default_value = default,
				on_submit = function(new_val)
					task[prop] = new_val
					tasks.save(task_list)
					vim.api.nvim_buf_set_option(info_popup.bufnr, "modifiable", true)
					vim.api.nvim_buf_set_lines(info_popup.bufnr, 0, -1, false, refresh_lines())
					vim.api.nvim_buf_set_option(info_popup.bufnr, "modifiable", false)
				end,
			}):mount()
		end, { buffer = info_popup.bufnr })

		-- プロパティ見出しの行番号（refresh_lines の構成と一致）
		local property_lines = { 1, 2, 3, 4 } -- Title, Category, Due, Memo

		-- j: 次のプロパティに移動（本文には進まない）
		vim.keymap.set("n", "j", function()
			local current = vim.fn.line(".")
			for _, line in ipairs(property_lines) do
				if line > current then
					vim.api.nvim_win_set_cursor(info_popup.winid, { line, 0 })
					break
				end
			end
		end, { buffer = info_popup.bufnr })

		-- k: 前のプロパティに戻る
		vim.keymap.set("n", "k", function()
			local current = vim.fn.line(".")
			for i = #property_lines, 1, -1 do
				if property_lines[i] < current then
					vim.api.nvim_win_set_cursor(info_popup.winid, { property_lines[i], 0 })
					break
				end
			end
		end, { buffer = info_popup.bufnr })

		-- h / l を無効化
		vim.keymap.set("n", "h", function() end, { buffer = info_popup.bufnr })
		vim.keymap.set("n", "l", function() end, { buffer = info_popup.bufnr })

		-- q で閉じる
		vim.keymap.set("n", "q", function()
			info_popup:unmount()
			vim.api.nvim_set_current_win(popup.winid)
			render()
		end, { buffer = info_popup.bufnr })
	end)

	map("dd", function()
		if mode ~= "inbox" then
			return
		end
		local line = vim.fn.line(".")
		local index = M.line_map[line]
		if index then
			table.remove(task_list, index)
			render()
		end
	end)

	map("<CR>", function()
		local line = vim.fn.line(".")
		local index = M.line_map[line]
		if index then
			task_list[index].done = not task_list[index].done
			tasks.save(task_list)
			task_list = tasks.load()
			selected_task_index = nil
			render()
		end
	end)

	map("<Space>", function()
		local line = vim.fn.line(".")
		local index = M.line_map[line]
		if selected_task_index == index then
			selected_task_index = nil
		else
			selected_task_index = index
		end
		render()
	end)

	map("j", function()
		local cursor = vim.fn.line(".")
		local max_line = vim.api.nvim_buf_line_count(popup.bufnr)

		if selected_task_index then
			-- 並び替えモード
			if selected_task_index < #task_list then
				local i = selected_task_index
				selected_task_index = i + 1
				task_list[i], task_list[i + 1] = task_list[i + 1], task_list[i]
				render()
				for line, index in pairs(M.line_map) do
					if index == selected_task_index then
						vim.api.nvim_win_set_cursor(0, { line, 0 })
						break
					end
				end
			end
		else
			-- 通常フォーカス移動モード
			for l = cursor + 1, max_line do
				local index = M.line_map[l]
				if index then
					vim.api.nvim_win_set_cursor(0, { l, 0 })
					break
				end
			end
		end
	end)

	map("k", function()
		local cursor = vim.fn.line(".")
		if selected_task_index then
			-- 並び替えモード
			if selected_task_index > 1 then
				local i = selected_task_index
				selected_task_index = i - 1
				task_list[i], task_list[i - 1] = task_list[i - 1], task_list[i]
				render()
				for line, index in pairs(M.line_map) do
					if index == selected_task_index then
						vim.api.nvim_win_set_cursor(0, { line, 0 })
						break
					end
				end
			end
		else
			-- 通常フォーカス移動モード
			for l = cursor - 1, 1, -1 do
				local index = M.line_map[l]
				if index then
					vim.api.nvim_win_set_cursor(0, { l, 0 })
					break
				end
			end
		end
	end)

	map("R", function()
		if mode ~= "done" then
			return
		end

		Input({
			position = { row = 10, col = "50%" },
			size = { width = 50 },
			border = {
				style = "single",
				text = { top = " Confirm ", top_align = "center" },
			},
		}, {
			default_value = "y",
			prompt = "Clear all DONE tasks? [y/N]: ",
			on_submit = function(value)
				if value == "y" or value == "Y" or value == "" then
					local new_list = {}
					for _, task in ipairs(task_list) do
						if not task.done then
							table.insert(new_list, task)
						end
					end
					task_list = new_list
					tasks.save(task_list)
					selected_task_index = nil
					render()
				else
					vim.notify("Cancelled", vim.log.levels.INFO)
				end
			end,
		}):mount()
	end)

	map("g?", function()
		local lines = { "[KEYBINDINGS]", "" }

		-- 共通
		vim.list_extend(lines, {
			"q       : Close UI",
			"Tab     : Switch between INBOX / DONE",
			"j / k   : Move cursor",
			"i       : Show task details",
			"<Space> : Select task for moving",
			"g?      : Show this help",
		})

		if mode == "inbox" then
			vim.list_extend(lines, {
				"",
				"[INBOX]",
				"a       : Add new task",
				"dd      : Delete selected task",
				"<CR>    : Mark as done",
			})
		elseif mode == "done" then
			vim.list_extend(lines, {
				"",
				"[DONE]",
				"<CR>    : Mark as not done",
				"R       : Clear all DONE tasks",
			})
		end

		local help_popup = Popup({
			enter = true,
			focusable = true,
			border = {
				style = "rounded",
				text = { top = " Help (" .. mode:upper() .. ") ", top_align = "center" },
			},
			position = { row = 5, col = "50%" },
			size = { width = 60, height = #lines + 2 },
			buf_options = {
				modifiable = true,
			},
		})

		help_popup:mount()
		vim.api.nvim_buf_set_lines(help_popup.bufnr, 0, -1, false, lines)
		vim.api.nvim_buf_set_option(help_popup.bufnr, "modifiable", false)

		vim.keymap.set("n", "q", function()
			help_popup:unmount()
		end, { buffer = help_popup.bufnr })
	end)
end

return M
