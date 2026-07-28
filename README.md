# environment

This is a respository for managing my personal environment configurations, and includes both the configurations themselves and an installer that sensibly puts them in the right place. Many similar repositories are known as "dotfiles" repositories.

## Structure
These configs cover a few main tools
- Neovim
- tmux
- OpenCode

Many tools place their configurations in $XDG_CONFIG_HOME which defaults to $HOME/.config. For this reason, those configurations are stored in .config in this repo as well.

This repo also contains an installer, `./install`, that will sensibly copy configurations to the correct locations, with opportunities to guide the install (e.g. optionally exclude `black` python formatting on a work machine)

## Quickstart
```./install.sh```

## Neovim
Neovim configuration is stored at the canonical `.config/nvim/`. `init.lua` is the main entrypoint, and subsets of plugin configurations are stored at `.config/nvim/lua/plugins/<plugin>.lua`.

## tmux
tmux configuration is stored at `tmux/`. `.tmux.conf` is the standard tmux config file that gets copied to `~/`. `tmux-dev` is a custom launch script that launches tmux in a specified directory with a specified session name and sets up the session with two windows where the first window is split into top-bottom panes. This gets installed to `~/.local/bin`.

## OpenCode
OpenCode configuration is stored at the canonical `.config/opencode/`. There are two main pieces of this configuration: the config file and skills

### Configuration file
This is stored directly in `./config/opencode/` and holds the overall JSON configuration for the OpenCode agent harness.

### Skills
These are stored at `.config/opencode/skills`. Each folder is an Agent Skill - specific documentation of the Skills specification can be found at [AgentSkills.io](https://agentskills.io/home)

