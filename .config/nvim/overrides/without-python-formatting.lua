-- Machine-local Neovim overrides.
--
-- install.sh copies this template to ~/.config/nvim/lua/local/overrides.lua on
-- first install and never overwrites it afterwards, so edits to the installed
-- copy are safe and stay on this machine. init.lua reads it via
-- require("local.overrides"); a missing file falls back to defaults.
return {
	-- No Python formatters — conform falls back to the LSP on Python buffers.
	-- Uncomment to run isort + black on save:
	-- python_formatters = { "isort", "black" },
}
