local M = {}

local baseConfig = require("aibou.config")

local state = {
	buf_content = {}, ---@type table<integer, string>
	diff_sizes = {}, ---@type integer[]
	chat = {}, ---@type table<integer, table>
}

---@param x integer[]
---@param p number percentile (0-1)
---@return integer
local function find_percentile(x, p)
	local n = #x
	if n == 0 then
		return 0
	end
	table.sort(x)
	local k = math.max(math.floor(p * n), 1)
	return x[k]
end

---@param chat table CodeCompanionChat
---@param diff string
---@param visible boolean | nil
---@return nil
local function send_diff(chat, diff, visible)
	chat:add_message({
		role = "user",
		-- triple backticks should be fine as diff won't start with a backtick
		content = "```diff\n" .. diff .. "\n```",
	}, { visible = visible })
	if visible then
		chat.ui:render(chat.context, chat.messages, {})
	end
	chat:submit()
end

---@param buf integer
---@return string, string | nil
local function get_buf_data(buf)
	local content = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
	local old = state.buf_content[buf]
	if old ~= content then
		local diff = vim.diff(old, content, { result_type = "unified" })
		if type(diff) == "string" then
			return content, diff
		end
		error("diff is not a string") -- should be unreachable as it happens when result_type is indices
	end
	return content, nil
end

---@param buf integer
---@param chat table CodeCompanionChat
---@return nil
local function create_autocmd(buf, chat)
	local augroup = vim.api.nvim_create_augroup("atusy-codecompanion-navi-" .. buf, {})
	local local_state = { nth_change = 0, stat = false }
	state.buf_content[buf] = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")

	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "TextChangedP", "BufWritePre" }, {
		group = augroup,
		buffer = buf,
		callback = function(ctx)
			local nth_change = local_state.nth_change + 1
			local_state.nth_change = nth_change

			-- stat
			if not local_state.stat then
				local delay = 1000
				local content = state.buf_content[buf]
				vim.defer_fn(function()
					local new_content = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
					local diff = vim.diff(content, new_content, { result_type = "unified" })
					table.insert(state.diff_sizes, 1, #diff / delay)
					if #state.diff_sizes > 1000 then
						table.remove(state.diff_sizes, 1001)
					end
					local_state.stat = false
				end, delay)
			end

			-- chat
			local base_delay = ctx.event == "BufWritePre" and 0 or 3000
			vim.defer_fn(function()
				-- cleanup if the buffer is deleted
				if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_valid(chat.bufnr) then
					state.buf_content[buf] = nil
					vim.api.nvim_del_augroup_by_id(augroup)
					return
				end

				-- if new defer function is added, skip the old one
				if nth_change ~= local_state.nth_change then
					return
				end

				local content, diff = get_buf_data(buf)

				-- do nothing if no diff (e.g., by undo)
				if not diff then
					return
				end

				-- if the diff is large, immediately send it
				local threshold = #state.diff_sizes < 10 and 0 or find_percentile(state.diff_sizes, 0.5) * base_delay
				if #diff > threshold then
					state.buf_content[buf] = content
					send_diff(chat, diff)
					return
				end

				-- if the diff is small, wait if the user adds more changes
				vim.defer_fn(function()
					if nth_change == local_state.nth_change then
						state.buf_content[buf] = content
						send_diff(chat, diff)
					end
				end, 5000)
			end, base_delay)
		end,
	})

	for _, b in ipairs({ buf, chat.bufnr }) do
		vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
			group = augroup,
			buffer = b,
			callback = function()
				state.buf_content[buf] = nil
				vim.api.nvim_del_augroup_by_id(augroup)
				return true
			end,
		})
	end
end

---@param buf integer
---@param config AibouConfig
---@return CodeCompanion.ChatArgs
local function configure_chat(buf, config)
	local user_config = (config.codecompanion or {}).chat_args or {}
	local default_config = {
		messages = {
			{
				role = "system",
				content = config.system_prompt or baseConfig.system_prompt,
				opts = { visible = false },
			},
			{
				role = "user",
				content = config.user_prompt or ("#lsp\n#buffer\n\n" .. baseConfig.user_prompt),
				opts = { visible = true },
			},
		},
		context = require("codecompanion.utils.context").get(buf, {}),
		opts = { ignore_system_prompts = true },
	}
	return vim.tbl_deep_extend("force", default_config, user_config)
end

---@param buf integer
---@return table CodeCompanionChat
---@param config AibouConfig
local function open_chat(buf, config)
	local opened_chat = state.chat[buf]
	if opened_chat and vim.api.nvim_buf_is_valid(opened_chat.bufnr) then
		if not opened_chat.ui:is_visible() then
			opened_chat.ui:open()
		end
		return opened_chat
	end

	local chat = require("codecompanion.strategies.chat").new(configure_chat(buf, config))
	chat:submit()
	state.chat[buf] = chat
	return chat
end

---@param config AibouConfig?
function M.start(config)
	local buf = vim.api.nvim_get_current_buf()
	local chat = open_chat(buf, config or {})
	create_autocmd(buf, chat)
end

return M
