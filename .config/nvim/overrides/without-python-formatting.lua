-- This file was installed here by the environment installer and init.lua reads
-- it via require("local.overrides"); a missing file falls back to defaults.
-- Edit .config/nvim/overrides/<option>.lua in the source repo instead of this file
return {
	-- No Python formatters — conform falls back to the LSP on Python buffers.
	-- Uncomment to run isort + black on save:
	-- python_formatters = { "isort", "black" },
}
