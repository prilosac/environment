-- Run with isolated XDG directories and the Tree-sitter checkout as the first argument:
-- nvim --headless -u NONE -l tests/nvim.lua /path/to/nvim-treesitter
-- Requires Tree-sitter CLI, a C compiler, curl, tar, and network access for parsers.
local repo = vim.fn.getcwd()
vim.opt.rtp:prepend(repo .. "/.config/nvim")
vim.opt.rtp:append(assert(arg[1], "Pass a current nvim-treesitter checkout"))
vim.fn.mkdir(vim.fn.stdpath("data") .. "/lazy/lazy.nvim", "p")

-- Load the real config but only initialize the plugin under test.
local specs
package.loaded.lazy = {
	setup = function(value)
		specs = value
	end,
}
local function load_specs()
	dofile(repo .. "/.config/nvim/init.lua")
	local fzf, treesitter
	for _, spec in ipairs(specs) do
		if type(spec) == "table" then
			if spec[1] == "nvim-treesitter/nvim-treesitter" then
				treesitter = spec
			end
			if spec[1] == "nvim-telescope/telescope.nvim" then
				for _, dependency in ipairs(spec.dependencies) do
					if type(dependency) == "table" and dependency[1] == "nvim-telescope/telescope-fzf-native.nvim" then
						fzf = dependency
					end
				end
			end
		end
	end
	return assert(fzf), assert(treesitter)
end

local has, executable = vim.fn.has, vim.fn.executable
for _, case in ipairs({
	{ windows = true, tools = { make = true, gcc = true }, build = "make", enabled = true },
	{ windows = true, tools = { ["mingw32-make"] = true, gcc = true }, build = "mingw32-make", enabled = true },
	{ windows = true, tools = { make = true }, enabled = false },
	{ windows = true, tools = { gcc = true }, enabled = false },
	{ windows = false, tools = { make = true }, build = "make", enabled = true },
	{ windows = false, tools = {}, enabled = false },
}) do
	vim.fn.has = function(feature)
		if feature == "win32" then
			return case.windows and 1 or 0
		end
		return has(feature)
	end
	vim.fn.executable = function(tool)
		return case.tools[tool] and 1 or 0
	end
	local fzf = load_specs()
	assert(fzf.cond() == case.enabled, "Wrong native matcher availability")
	if case.enabled then
		assert(fzf.build == case.build, "Wrong Make executable")
	end
end
vim.fn.has, vim.fn.executable = has, executable

local _, spec = load_specs()
spec.config()
local ts = require("nvim-treesitter")
local initial =
	{ "bash", "c", "diff", "html", "lua", "luadoc", "markdown", "markdown_inline", "query", "vim", "vimdoc" }
assert(
	vim.wait(180000, function()
		local installed = ts.get_installed("parsers")
		for _, lang in ipairs(initial) do
			if not vim.list_contains(installed, lang) then
				return false
			end
		end
		return true
	end, 100),
	"Configured parsers were not installed"
)

local function open(filetype, lines)
	local buf = vim.api.nvim_create_buf(true, false)
	vim.api.nvim_set_current_buf(buf)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].filetype = filetype
	return buf
end

local lua = open("lua", { "local value = 1" })
assert(vim.treesitter.highlighter.active[lua], "Lua highlighting did not attach")
assert(vim.bo[lua].indentexpr:find("nvim%-treesitter"), "Lua indentation missing")

-- JSON is outside the configured list: its first buffer must attach after the download.
local json = open("json", { '{"value": 1}' })
assert(
	vim.wait(120000, function()
		return vim.list_contains(ts.get_installed("parsers"), "json") and vim.treesitter.highlighter.active[json] ~= nil
	end, 100),
	"Automatic parser installation/highlighting failed"
)

local ruby = open("ruby", { "puts 'hello'" })
assert(
	vim.wait(120000, function()
		return vim.treesitter.highlighter.active[ruby] ~= nil
	end, 100),
	"Ruby highlighting missing"
)
assert(vim.bo[ruby].syntax == "ruby", "Ruby regex highlighting missing")
assert(not vim.bo[ruby].indentexpr:find("nvim%-treesitter"), "Ruby indentation was replaced")

local unsupported = open("environment-test-unsupported", { "hello" })
assert(not vim.treesitter.highlighter.active[unsupported], "Unsupported filetype enabled highlighting")
print("PASS: native matcher selection, parser installation, automatic highlighting, Ruby exceptions")
