-- This file was installed here by the environment installer and init.lua reads
-- it via require("local.overrides"); a missing file falls back to defaults.
-- Edit .config/nvim/overrides/<option>.lua in the source repo instead of this file
return {
	-- Formatters conform.nvim runs on Python buffers, in order.
	python_formatters = { "isort", "black" },
}
