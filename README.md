# environment

This is a repository for managing my personal environment configurations, and includes both the configurations themselves and an installer that sensibly puts them in the right place. Many similar repositories are known as "dotfiles" repositories.

## Structure

These configs cover a few main tools

- Neovim
- tmux
- OpenCode
- Agent skills (shared by OpenCode and Claude Code)

On Linux/macOS, directories in this repo mirror where their contents land: `.config/` installs into `~/.config`, `agents/` installs into `~/.agents`, and `tmux/` is grouped by tool (its two files land in `~` and `~/.local/bin`). Native Windows destinations are listed below.

`.vimrc` is a legacy configuration for pure vim and is not deployed by `install.sh`. It's kept around in case somewhere vim is available but neovim isn't.

## Quickstart

```bash
./install.sh
```

With no arguments you get an interactive menu: toggle modules by number, `d` for a dry run, Enter to install. Defaults come from the last profile you used (or `personal`).

Non-interactive, e.g. on a fresh work machine:

```bash
./install.sh --profile work --yes
```

### Flags

| Flag | Effect |
| --- | --- |
| `--profile personal\|work` | select a profile (see below) |
| `--only a,b` | install only these modules |
| `--skip a,b` | install everything except these |
| `--dry-run` | print the full plan, touch nothing |
| `--copy` | copy files instead of symlinking (`--link` is the default) |
| `--yes` | no menu, no questions — take profile defaults |
| `--list` | show modules and current selection |

`--only` and `--skip` both take any comma-separated list of module names, so `--only opencode2` and `--skip nvim-ai,tmux` are equally valid. `./install.sh --list` prints the module names.

The modules are `tmux`, `nvim`, `nvim-ai`, `opencode`, `opencode2`, `agents-skills`, and `claude-skills`. The two OpenCode modules are mutually exclusive because both versions read `~/.config/opencode/opencode.jsonc`.

`./install.sh render opencode2 [--profile work]` prints a fully resolved OpenCode config to stdout without installing anything. Use `opencode` as the render target for v1.

### Profiles

Both profiles install all non-OpenCode modules and one OpenCode version:

- **personal** — OpenCode 2 base config only, Python formatting on.
- **work** — OpenCode 2 with the `work` overlay, Python formatting off.

Select the other version explicitly with `--only opencode` or `--only opencode2`. The selected profile still controls whether the work overlay is applied.

### Modes

How files get installed is independent of the profile:

- **link** (default) — files are symlinked into place, so edits in this repo are live and a `git pull` updates your config without re-installing.
- **copy** (`--copy`) — files are copied, giving a self-contained install that keeps working if you delete this checkout. Useful for a one-shot bootstrap on a machine where the repo won't stick around.

Mode isn't remembered between runs the way the profile is, so pass `--copy` every time you want it; a re-run without it converts the install back to symlinks (backing up each file first).

In both modes this repo is the source of truth: re-running the installer paves over whatever is on the machine, so nothing drifts. The one exception is the merged OpenCode config, which has no single source file and is therefore always generated rather than linked. Any file the installer replaces is first backed up to `~/.environment-backups/<timestamp>/`. Only the 5 most recent of those directories are kept — older ones are pruned on the next run that actually backs something up.

### Native Windows

Run from Windows PowerShell 5.1 or PowerShell 7:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

The execution-policy override applies only to this process. If your policy already permits scripts, use `.\install.ps1` directly. WSL uses `./install.sh` inside its Linux environment.

The Windows installer has the same menu and profiles, with these PowerShell parameters:

| Parameter | Effect |
| --- | --- |
| `-Profile personal\|work` | select a profile |
| `-Only nvim,nvim-ai` / `-Skip nvim-ai` | select or exclude modules |
| `-DryRun` | print the plan without writing files or requesting elevation |
| `-Copy` / `-Link` | copy or symlink (link is the default) |
| `-Yes` | use defaults without prompting |
| `-List` | show modules and selection |
| `-Render opencode2` | print the resolved config; also accepts `opencode` |

For example, `.\install.ps1 -Profile personal -Yes` installs all Windows modules. tmux is available through the Linux/WSL installer only. The two OpenCode modules remain mutually exclusive.

| Content | Default Windows destination |
| --- | --- |
| Neovim | `%LOCALAPPDATA%\nvim` |
| OpenCode (either version) | `%USERPROFILE%\.config\opencode` |
| Shared skills | `%USERPROFILE%\.agents\skills` |
| Claude skill links | `%USERPROFILE%\.claude\skills` |
| Installer state | `%LOCALAPPDATA%\environment` |
| Backups | `%USERPROFILE%\.environment-backups` |

`XDG_CONFIG_HOME` overrides the Neovim and OpenCode config roots; `NVIM_APPNAME` overrides the `nvim` directory name. `XDG_STATE_HOME` overrides the installer state root.

Link installs request the standard UAC prompt before installing unless PowerShell is already elevated. Developer Mode is not required. The elevated process retains your original user paths and module selection; cancelling UAC stops the install. Keep the checkout in place so the links remain valid.

Copy installs run without elevation. Claude's skill directories use junctions to the copied shared skills, so both consumers still share one copy. Replaced files/directories are moved into timestamped backups; reruns retain the five most recent backups. OpenCode work overlays are merged using PowerShell's JSON support, with the same permission-array behavior as `install.sh`.

## Neovim

Neovim configuration is stored at the canonical `.config/nvim/`. `init.lua` is the main entrypoint, and subsets of plugin configurations are stored at `.config/nvim/lua/plugins/<plugin>.lua`.

The config requires Neovim 0.12+. Clipboard integration keeps the scheduled `clipboard=unnamedplus` setting and selects OSC 52 only after the attached terminal advertises an OSC 52 `Ms` capability, using `vim.tty.query`. Unsupported or unanswered queries leave provider selection alone; a positive response reloads the provider even if a plugin initialized it earlier.

Install these prerequisites separately and make their executables available on Neovim's `PATH`:

- Git (plugin downloads), ripgrep (`rg`, Telescope searches), Node.js (Copilot and Pyright), and curl 8+ (Copilot Chat).
- Tree-sitter CLI 0.26.1+ from a package manager or upstream release, a supported C compiler, and `tar`/`curl` for parser downloads and builds. The Tree-sitter plugin installs an explicit parser list, including Python and JavaScript. Use `:TSInstall <language>` for additional languages; reopen the file after installation finishes to enable highlighting and indentation. Ruby retains Vim regex highlighting and its existing indentation.
- Optional formatters: `black` and `isort` for the personal Python profile, and `prettierd` or `prettier` for JavaScript. Mason installs LuaLS, Pyright, and StyLua on first use.
- A Nerd Font selected in your terminal for the configured icons.

On Windows, Telescope's optional native fuzzy matcher builds when both GNU Make (`make` or `mingw32-make`) and MinGW-w64 `gcc` are available. For example, an MSYS2 UCRT64 installation can provide the `mingw-w64-ucrt-x86_64-gcc` and `mingw-w64-ucrt-x86_64-make` packages; add its `ucrt64\bin` directory to your Windows `PATH`. The compiler can also build Tree-sitter parsers. If Make or GCC is absent, Telescope uses its built-in matcher. LuaSnip's optional regex build is already disabled on Windows.

The terminal must implement the advertisement as well as clipboard handling. For Feltcode, that requires its terminal-support update. `Ms` advertises copying, not clipboard reads; this config does not add fallback after a failed operation.

Environment-specific choices (currently: whether conform runs `isort` + `black` on Python) live in `~/.config/nvim/lua/local/overrides.lua`, read by `init.lua` via `require("local.overrides")`. A missing file falls back to defaults.

That file is installed from one of the tracked variants in `.config/nvim/overrides/`:

- `with-python-formatting.lua` — conform runs `isort` + `black` on Python buffers.
- `without-python-formatting.lua` — no Python formatters; conform falls back to the LSP.

The installer picks one based on the question it asks (or the profile default with `--yes`) and installs it like any other file — linked or copied per mode, and replaced on every run. Edit the variants here, not the installed copy; changes reach a machine on the next install, and switching your answer switches the file.

## tmux

tmux configuration is stored at `tmux/`. `.tmux.conf` is the standard tmux config file that gets installed to `~/`. `tmux-dev [work_dir] [session_name]` is a custom launch script that launches tmux in a specified directory with a specified session name and sets up the session with two windows where the first window is split into top-bottom panes. This gets installed to `~/.local/bin`.

Through tmux 3.5a, Neovim retains its tmux provider. The `Ms` override emits the clipboard selector required by mosh 1.4 while consuming both string parameters expected by tmux. Mosh does not forward the capability query, so direct mosh sessions cannot opt in this way; use tmux for copying to the frontend clipboard and pasting its yank buffer. For text copied in a local application, use the terminal's paste shortcut: mosh 1.4 does not reliably forward repeated clipboard-read requests.

## OpenCode

OpenCode 1 configuration is stored at `.config/opencode/`, and its native OpenCode 2 conversion is stored in parallel at `.config/opencode2/`. Each has two layers:

- `base.jsonc` — machine-agnostic config (generic permissions and agent settings; v1 also keeps its theme here).
- `work.jsonc` — work overlay: the bedrock provider, the Asana MCP server and its permission gates, and work-project permission rules.

Both versions install to `~/.config/opencode/opencode.jsonc`, the global path shared by the two CLIs, so the installer does not allow both modules in one run. With no overlay (personal profile) the selected `base.jsonc` is installed directly, so it can be a symlink like everything else. With the work profile the selected version's two layers are deep-merged with `jq` and written as a real file, headed by a `// GENERATED by ...` comment - edit the repo files, not the generated one; the installer detects and backs up hand-edits on the next run.

OpenCode 2 terminal settings moved out of the server config. Its converted theme lives at `.config/opencode2/cli.json` and installs to `~/.config/opencode/cli.json` with the `opencode2` module.

Merging in `install.sh` requires `jq`; `install.ps1` uses built-in PowerShell JSON support. Comments in the source files must be full-line `//` comments, since both installers strip them line-wise before parsing.

The Asana MCP client secret is **not** stored in this repo. `work.jsonc` references it as `{env:ASANA_CLIENT_SECRET}`, which OpenCode substitutes at runtime — export it in your work shell profile.

## Agent skills

Skills are stored at `agents/skills/`, one directory per skill following the [Agent Skills](https://agentskills.io/home) specification. They install to `~/.agents/skills/`, which OpenCode reads natively. Claude Code doesn't read `~/.agents`, so the `claude-skills` module symlinks each skill into `~/.claude/skills/<name>` pointing back at `~/.agents/skills/<name>` — one source of truth, two consumers.

Each skill includes `agents/openai.yaml` with a display name, short description, and default prompt for OpenAI/Codex interfaces. Keep this metadata alongside the skill's `SKILL.md`.
