# environment

This is a repository for managing my personal environment configurations, and includes both the configurations themselves and an installer that sensibly puts them in the right place. Many similar repositories are known as "dotfiles" repositories.

## Structure

These configs cover a few main tools

- Neovim
- tmux
- OpenCode
- Agent skills (shared by OpenCode and Claude Code)

Directories in this repo mirror where their contents land: `.config/` installs into `~/.config`, `agents/` installs into `~/.agents`, and `tmux/` is grouped by tool (its two files land in `~` and `~/.local/bin`).

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

`--only` and `--skip` both take any comma-separated list of module names, so `--only opencode` and `--skip nvim-ai,tmux` are equally valid. `./install.sh --list` prints the module names.

The modules are `tmux`, `nvim`, `nvim-ai`, `opencode`, `agents-skills`, and `claude-skills`.

`./install.sh render opencode [--profile work]` prints the fully resolved OpenCode config to stdout without installing anything.

### Profiles

Both profiles install all modules; they differ only in *content*:

- **personal** — OpenCode base config only, Python formatting on.
- **work** — merges the `work` OpenCode overlay, Python formatting off.

### Modes

How files get installed is independent of the profile:

- **link** (default) — files are symlinked into place, so edits in this repo are live and a `git pull` updates your config without re-installing.
- **copy** (`--copy`) — files are copied, giving a self-contained install that keeps working if you delete this checkout. Useful for a one-shot bootstrap on a machine where the repo won't stick around.

Mode isn't remembered between runs the way the profile is, so pass `--copy` every time you want it; a re-run without it converts the install back to symlinks (backing up each file first).

In both modes this repo is the source of truth: re-running the installer paves over whatever is on the machine, so nothing drifts. The one exception is the merged OpenCode config, which has no single source file and is therefore always generated rather than linked. Any file the installer replaces is first backed up to `~/.environment-backups/<timestamp>/`. Only the 5 most recent of those directories are kept — older ones are pruned on the next run that actually backs something up.

## Neovim

Neovim configuration is stored at the canonical `.config/nvim/`. `init.lua` is the main entrypoint, and subsets of plugin configurations are stored at `.config/nvim/lua/plugins/<plugin>.lua`.

Environment-specific choices (currently: whether conform runs `isort` + `black` on Python) live in `~/.config/nvim/lua/local/overrides.lua`, read by `init.lua` via `require("local.overrides")`. A missing file falls back to defaults.

That file is installed from one of the tracked variants in `.config/nvim/overrides/`:

- `with-python-formatting.lua` — conform runs `isort` + `black` on Python buffers.
- `without-python-formatting.lua` — no Python formatters; conform falls back to the LSP.

The installer picks one based on the question it asks (or the profile default with `--yes`) and installs it like any other file — linked or copied per mode, and replaced on every run. Edit the variants here, not the installed copy; changes reach a machine on the next install, and switching your answer switches the file.

## tmux

tmux configuration is stored at `tmux/`. `.tmux.conf` is the standard tmux config file that gets installed to `~/`. `tmux-dev [work_dir] [session_name]` is a custom launch script that launches tmux in a specified directory with a specified session name and sets up the session with two windows where the first window is split into top-bottom panes. This gets installed to `~/.local/bin`.

## OpenCode

OpenCode configuration is stored at `.config/opencode/` as two layers:

- `base.jsonc` — machine-agnostic config (theme, generic permissions, agent settings).
- `work.jsonc` — work overlay: the bedrock provider, the Asana MCP server and its permission gates, and work-project permission rules.

Both cases install to `~/.config/opencode/opencode.jsonc`. With no overlay (personal profile) that's `base.jsonc` installed directly, so it can be a symlink like everything else. With the work profile the two layers are deep-merged with `jq` and written as a real file, headed by a `// GENERATED by …` comment — edit the repo files, not the generated one; the installer detects and backs up hand-edits on the next run.

Merging requires `jq`. Comments in the source files must be full-line `//` comments, since the merge strips them line-wise before handing the JSON to `jq`.

The Asana MCP client secret is **not** stored in this repo. `work.jsonc` references it as `{env:ASANA_CLIENT_SECRET}`, which OpenCode substitutes at runtime — export it in your work shell profile.

## Agent skills

Skills are stored at `agents/skills/`, one directory per skill following the [Agent Skills](https://agentskills.io/home) specification. They install to `~/.agents/skills/`, which OpenCode reads natively. Claude Code doesn't read `~/.agents`, so the `claude-skills` module symlinks each skill into `~/.claude/skills/<name>` pointing back at `~/.agents/skills/<name>` — one source of truth, two consumers.
