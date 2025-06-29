local prefix = "<Leader>a"
return {
	-- { -- Copilot
	--   'github/copilot.vim',
	-- },
	{
		"zbirenbaum/copilot.lua",
		cmd = "Copilot",
		event = "InsertEnter",
		config = function()
			require("copilot").setup({
				suggestion = { enabled = false, debounce = 200 },
				panel = { enabled = false },
			})
		end,
		--opts = function(_, opts)
		--  opts.suggestion = opts.suggestion or {}
		--  opts.suggestion.debounce = 200
		--  return opts
		--end,
	},
	{
		"yetone/avante.nvim",
		event = "VeryLazy",
		lazy = true,
		version = false, -- set this if you want to always pull the latest change
		opts = {
			-- add any opts here
			mappings = {
				ask = prefix .. "<CR>",
				edit = prefix .. "e",
				refresh = prefix .. "r",
				focus = prefix .. "f",
				toggle = {
					default = prefix .. "t",
					debug = prefix .. "d",
					hint = prefix .. "h",
					suggestion = prefix .. "s",
					repomap = prefix .. "R",
				},
				diff = {
					next = "]c",
					prev = "[c",
				},
				files = {
					add_current = prefix .. ".",
				},
			},
			behaviour = {
				auto_suggestions = false,
			},
			provider = "copilot",
			providers = {
				copilot = {
					-- model = "claude-3.7-sonnet",
					model = "claude-sonnet-4",
					disable_tools = false,
					extra_request_body = {
						temperature = 0.5,
						max_tokens = 65536,
						reasoning_effort = "medium",
					},
				},
			},
		},
		-- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
		-- dynamically build it, taken from astronvim
		build = vim.fn.has("win32") == 1
				and "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false"
			or "make",
		dependencies = {
			-- "stevearc/dressing.nvim",
			"nvim-lua/plenary.nvim",
			"MunifTanjim/nui.nvim",
			{
				-- support for image pasting
				"HakonHarnes/img-clip.nvim",
				event = "VeryLazy",
				opts = {
					-- recommended settings
					default = {
						embed_image_as_base64 = false,
						prompt_for_file_name = false,
						drag_and_drop = {
							insert_mode = true,
						},
						-- required for Windows users
						use_absolute_path = true,
					},
				},
			},
			{
				-- Make sure to set this up properly if you have lazy=true
				"MeanderingProgrammer/render-markdown.nvim",
				dependencies = {
					-- make sure rendering happens even without opening a markdown file first
					"yetone/avante.nvim",
				},
				opts = function(_, opts)
					opts.file_types = opts.file_types or { "markdown", "norg", "rmd", "org" }
					vim.list_extend(opts.file_types, { "Avante" })
				end,
			},
		},
	},
	{ -- Copilot Chat
		"CopilotC-Nvim/CopilotChat.nvim",
		dependencies = {
			-- { "github/copilot.vim" }, -- or zbirenbaum/copilot.lua
			{ "nvim-lua/plenary.nvim", branch = "master" }, -- for curl, log and async functions
		},
		branch = "main",
		config = function()
			require("CopilotChat").setup({
				context = "buffers",
				model = "claude-sonnet-4",
			})
			vim.api.nvim_create_user_command("CC", function(opts)
				-- vim.print(opts)
				local range_prefix = ""
				if opts.range > 0 then
					range_prefix = ("%d,%d"):format(opts.line1, opts.line2)
				end

				vim.cmd(range_prefix .. "CopilotChat " .. opts.args)
			end, { nargs = "*", range = true })
		end,
	},
	{
		"AndreM222/copilot-lualine",
		dependecies = {
			"nvim-lualine/lualine.nvim",
			"zbirenbaum/copilot.lua",
		},
	},
}
