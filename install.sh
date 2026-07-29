#!/usr/bin/env bash
#
# environment installer
#
#   ./install.sh                          interactive menu (defaults from last profile)
#   ./install.sh --profile work --yes     non-interactive fresh-machine setup
#   ./install.sh --only opencode          install only these modules
#   ./install.sh --skip nvim-ai,tmux      install everything but these
#   ./install.sh --list                   show modules and what's selected
#   ./install.sh --dry-run                show the full plan, touch nothing
#   ./install.sh render opencode          print the resolved opencode config
#
# Modules install from this repo to their canonical destinations. In link mode
# (personal default) files are symlinked so repo edits are live; in copy mode
# (work default) files are copied. Either way the repo is the source of truth;
# re-running paves over what's on the machine

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/environment"
BACKUP_DIR="$HOME/.environment-backups/$(date +%Y%m%d-%H%M%S)"

ALL_MODULES="tmux nvim nvim-ai opencode agents-skills claude-skills"

PROFILE=""
ENABLED=""
MODE=link             # link | copy
OPENCODE_OVERLAY=""   # "" = base only; "work" = merge work.jsonc on top
NVIM_PY_FMT=no        # yes | no — default answer for the python formatting question
DRY_RUN=0
ASSUME_YES=0
CHANGED=0
UNCHANGED=0
BACKUPS=0

if [ -t 1 ]; then
	C_GREEN=$'\033[32m' C_YELLOW=$'\033[33m' C_DIM=$'\033[2m' C_BOLD=$'\033[1m' C_RESET=$'\033[0m'
else
	C_GREEN="" C_YELLOW="" C_DIM="" C_BOLD="" C_RESET=""
fi

# ---------------------------------------------------------------- helpers ---

say()  { printf "%s\n" "$*"; }
warn() { printf "%s! %s%s\n" "$C_YELLOW" "$*" "$C_RESET" >&2; }
die()  { printf "error: %s\n" "$*" >&2; exit 1; }

# Execute a command, unless this is a dry run.
run() { [ "$DRY_RUN" = 1 ] && return 0; "$@"; }

ensure_dir() { [ -d "$1" ] || run mkdir -p "$1"; }

# record <status> <dest> [detail] — one aligned output line per action.
record() {
	local status="$1" dest="$2" detail="${3:-}" color="$C_GREEN"
	case "$status" in
		unchanged)
			color="$C_DIM"
			UNCHANGED=$((UNCHANGED + 1))
			;;
		backup) color="$C_YELLOW" ;;
		remove)
			color="$C_YELLOW"
			CHANGED=$((CHANGED + 1))
			;;
		link | copy | write) CHANGED=$((CHANGED + 1)) ;;
	esac
	printf "  %s%-10s%s %s%s\n" "$color" "$status" "$C_RESET" "${dest/#$HOME/~}" "${detail:+  ${C_DIM}($detail)$C_RESET}"
}

# Copy a file/dir into the timestamped backup tree before it gets replaced.
backup_file() {
	local f="$1" rel="${1#"$HOME"/}"
	BACKUPS=$((BACKUPS + 1))
	record backup "$f" "-> ${BACKUP_DIR/#$HOME/~}/$rel"
	[ "$DRY_RUN" = 1 ] && return 0
	mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
	cp -R "$f" "$BACKUP_DIR/$rel"
}

# confirm <question> <default:yes|no>
confirm() {
	local q="$1" def="${2:-no}" hint="[y/N]" ans=""
	[ "$def" = yes ] && hint="[Y/n]"
	read -rp "$q $hint " ans || true
	case "$ans" in
		[Yy]*) return 0 ;;
		[Nn]*) return 1 ;;
		"") [ "$def" = yes ] ;;
		*) return 1 ;;
	esac
}

# True when it's OK to ask the user questions.
can_prompt() { [ -t 0 ] && [ "$ASSUME_YES" = 0 ] && [ "$DRY_RUN" = 0 ]; }

# install_file <repo-relative-src> <dest> — symlink or copy per $MODE.
# Idempotent: correct links / identical copies report "unchanged". Anything
# being replaced that isn't ours (a real file with different content) is
# backed up first.
install_file() {
	local rel="$1" src="$REPO_DIR/$1" dest="$2"
	ensure_dir "$(dirname "$dest")"
	if [ "$MODE" = link ]; then
		if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
			record unchanged "$dest" "link"
			return 0
		fi
		[ -e "$dest" ] && [ ! -L "$dest" ] && backup_file "$dest"
		run rm -f "$dest"
		run ln -s "$src" "$dest"
		record link "$dest" "-> $rel"
	else
		if [ -L "$dest" ]; then
			# never `cp` onto a symlink — it would write through into the repo
			run rm -f "$dest"
			run cp "$src" "$dest"
			record copy "$dest" "replaced symlink"
		elif [ -f "$dest" ] && cmp -s "$src" "$dest"; then
			record unchanged "$dest"
		else
			[ -f "$dest" ] && backup_file "$dest"
			run cp "$src" "$dest"
			record copy "$dest" "$rel"
		fi
	fi
}

# install_dir <repo-relative-src> <dest> — directory variant of install_file.
install_dir() {
	local rel="$1" src="$REPO_DIR/$1" dest="$2"
	ensure_dir "$(dirname "$dest")"
	if [ "$MODE" = link ]; then
		if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
			record unchanged "$dest" "link"
			return 0
		fi
		[ -e "$dest" ] && [ ! -L "$dest" ] && backup_file "$dest"
		run rm -rf "$dest"
		run ln -s "$src" "$dest"
		record link "$dest" "-> $rel"
	else
		if [ -L "$dest" ]; then
			run rm -f "$dest"
			run cp -R "$src" "$dest"
			record copy "$dest" "replaced symlink"
		elif [ -d "$dest" ] && diff -qr "$src" "$dest" >/dev/null 2>&1; then
			record unchanged "$dest"
		else
			[ -e "$dest" ] && backup_file "$dest"
			run rm -rf "$dest"
			run cp -R "$src" "$dest"
			record copy "$dest" "$rel"
		fi
	fi
}

# make_link <target> <link> — unconditional symlink (used for ~/.claude/skills,
# which links regardless of $MODE).
make_link() {
	local target="$1" link="$2"
	if [ -L "$link" ] && [ "$(readlink "$link")" = "$target" ]; then
		record unchanged "$link" "link"
		return 0
	fi
	[ -e "$link" ] && [ ! -L "$link" ] && backup_file "$link"
	run rm -rf "$link"
	run ln -s "$target" "$link"
	record link "$link" "-> ${target/#$HOME/~}"
}

# --- modules ---

module_desc() {
	case "$1" in
		tmux) echo "tmux config + tmux-dev launcher" ;;
		nvim) echo "Neovim core config (+ env-specific overrides)" ;;
		nvim-ai) echo "Neovim AI plugins (copilot)" ;;
		opencode) echo "OpenCode config (base${OPENCODE_OVERLAY:+ + $OPENCODE_OVERLAY overlay})" ;;
		agents-skills) echo "agent skills -> ~/.agents/skills" ;;
		claude-skills) echo "skill symlinks -> ~/.claude/skills (for Claude Code)" ;;
	esac
}

install_tmux() {
	install_file "tmux/.tmux.conf" "$HOME/.tmux.conf"
	install_file "tmux/tmux-dev" "$HOME/.local/bin/tmux-dev"
	[ "$MODE" = copy ] && run chmod +x "$HOME/.local/bin/tmux-dev"
	return 0
}

install_nvim() {
	install_file ".config/nvim/init.lua" "$HOME/.config/nvim/init.lua"

	# Environment-specific overrides, installed like everything else: the repo is
	# the source of truth, so re-running paves over whatever is on the machine.
	# Which template gets installed is the only choice here.
	local fmt="$NVIM_PY_FMT"
	if can_prompt; then
		if confirm "Enable personal Python formatting (isort + black)?" "$fmt"; then fmt=yes; else fmt=no; fi
	fi
	local tmpl=".config/nvim/overrides/without-python-formatting.lua"
	if [ "$fmt" = yes ]; then
		tmpl=".config/nvim/overrides/with-python-formatting.lua"
	fi
	install_file "$tmpl" "$HOME/.config/nvim/lua/local/overrides.lua"
}

install_nvim_ai() {
	install_file ".config/nvim/lua/plugins/ai.lua" "$HOME/.config/nvim/lua/plugins/ai.lua"
}

strip_jsonc() { grep -vE '^[[:space:]]*//' "$1"; }

# Print the resolved opencode config: base.jsonc as-is when no overlay,
# otherwise a jq deep-merge of base + overlay with a generated-file marker.
render_opencode() {
	local base="$REPO_DIR/.config/opencode/base.jsonc"
	if [ -z "$OPENCODE_OVERLAY" ]; then
		cat "$base"
		return 0
	fi
	local overlay="$REPO_DIR/.config/opencode/$OPENCODE_OVERLAY.jsonc"
	[ -f "$overlay" ] || die "unknown opencode overlay '$OPENCODE_OVERLAY' (no $overlay)"
	command -v jq >/dev/null || die "jq is required to merge opencode config overlays"
	jq -s --arg note "GENERATED by environment/install.sh from base.jsonc + $OPENCODE_OVERLAY.jsonc — edit those repo files, not this one" \
		'{"//": $note} + (.[0] * .[1])' \
		<(strip_jsonc "$base") <(strip_jsonc "$overlay")
}

install_opencode() {
	ensure_dir "$HOME/.config/opencode"
	local dest_json="$HOME/.config/opencode/opencode.json"
	local dest_jsonc="$HOME/.config/opencode/opencode.jsonc"

	if [ -z "$OPENCODE_OVERLAY" ]; then
		install_file ".config/opencode/base.jsonc" "$dest_jsonc"
		# retire a generated opencode.json from a previous overlay install
		if [ -f "$dest_json" ] && grep -q '"//": "GENERATED' "$dest_json"; then
			backup_file "$dest_json"
			run rm -f "$dest_json"
			record remove "$dest_json" "stale generated config"
		fi
	else
		local tmp last="$STATE_DIR/rendered-opencode.json"
		tmp="$(mktemp)"
		render_opencode >"$tmp"
		if [ -f "$dest_json" ] && cmp -s "$tmp" "$dest_json"; then
			record unchanged "$dest_json" "base + $OPENCODE_OVERLAY"
		else
			if [ -f "$dest_json" ]; then
				if [ -f "$last" ] && ! cmp -s "$dest_json" "$last"; then
					warn "opencode.json differs from the last render — it was hand-edited. Backing it up; make config edits in the repo's jsonc files."
				fi
				backup_file "$dest_json"
			fi
			run cp "$tmp" "$dest_json"
			record write "$dest_json" "merged base + $OPENCODE_OVERLAY"
		fi
		if [ "$DRY_RUN" = 0 ]; then
			mkdir -p "$STATE_DIR"
			cp "$tmp" "$last"
		fi
		rm -f "$tmp"
		# a leftover opencode.jsonc would fight with the generated json
		if [ -e "$dest_jsonc" ] || [ -L "$dest_jsonc" ]; then
			[ -L "$dest_jsonc" ] || backup_file "$dest_jsonc"
			run rm -f "$dest_jsonc"
			record remove "$dest_jsonc" "superseded by generated opencode.json"
		fi
	fi

	# Migration: skills used to be installed here; they now live in
	# ~/.agents/skills (OpenCode reads that natively).
	local sdir="$HOME/.config/opencode/skills" src name old
	for src in "$REPO_DIR"/agents/skills/*/; do
		name="$(basename "$src")"
		old="$sdir/$name"
		if [ -d "$old" ] || [ -L "$old" ]; then
			[ -L "$old" ] || backup_file "$old"
			run rm -rf "$old"
			record remove "$old" "moved to ~/.agents/skills"
		fi
	done
	if [ -d "$sdir" ] && [ -z "$(ls -A "$sdir" 2>/dev/null)" ]; then
		run rmdir "$sdir"
	fi
}

install_agents_skills() {
	ensure_dir "$HOME/.agents/skills"
	# Migration: "humanize" was the old untracked name for humanizer.
	if [ -d "$HOME/.agents/skills/humanize" ]; then
		backup_file "$HOME/.agents/skills/humanize"
		run rm -rf "$HOME/.agents/skills/humanize"
		record remove "$HOME/.agents/skills/humanize" "renamed to humanizer"
	fi
	local src name
	for src in "$REPO_DIR"/agents/skills/*/; do
		name="$(basename "$src")"
		install_dir "agents/skills/$name" "$HOME/.agents/skills/$name"
	done
}

install_claude_skills() {
	# Claude Code doesn't read ~/.agents, so mirror each skill as a symlink.
	ensure_dir "$HOME/.claude/skills"
	local src name
	for src in "$REPO_DIR"/agents/skills/*/; do
		name="$(basename "$src")"
		make_link "$HOME/.agents/skills/$name" "$HOME/.claude/skills/$name"
	done
}

# --- profiles ---

apply_profile() {
	case "$1" in
		personal)
			ENABLED="$ALL_MODULES"
			MODE=link
			OPENCODE_OVERLAY=""
			NVIM_PY_FMT=yes
			;;
		work)
			# Same modules as personal; differs only in how they're installed:
			# copied rather than linked, with the work opencode overlay and no
			# personal Python formatting.
			ENABLED="$ALL_MODULES"
			MODE=copy
			OPENCODE_OVERLAY=work
			NVIM_PY_FMT=no
			;;
		*) die "unknown profile: $1 (available: personal, work)" ;;
	esac
	PROFILE="$1"
}

# --- selection & menu ---

enabled() { case " $ENABLED " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

toggle() {
	if enabled "$1"; then
		ENABLED="$(printf "%s" " $ENABLED " | sed "s/ $1 / /")"
	else
		ENABLED="$ENABLED $1"
	fi
}

valid_module() { case " $ALL_MODULES " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

# claude-skills links into ~/.agents/skills, so it needs agents-skills.
resolve_deps() {
	if enabled claude-skills && ! enabled agents-skills; then
		say "note: claude-skills requires agents-skills — enabling it"
		ENABLED="$ENABLED agents-skills"
	fi
}

nth_module() {
	local i=0 m
	for m in $ALL_MODULES; do
		i=$((i + 1))
		[ "$i" = "$1" ] && { echo "$m"; return 0; }
	done
	return 1
}

run_menu() {
	local i m mark choice
	while true; do
		echo
		say "${C_BOLD}environment installer${C_RESET} — profile: $PROFILE, mode: $MODE"
		i=0
		for m in $ALL_MODULES; do
			i=$((i + 1))
			mark=" "
			enabled "$m" && mark="x"
			printf "  %d) [%s] %-14s %s%s%s\n" "$i" "$mark" "$m" "$C_DIM" "$(module_desc "$m")" "$C_RESET"
		done
		echo
		read -rp "toggle 1-$i · (a)ll · (n)one · (d)ry-run · Enter=install · (q)uit > " choice || exit 0
		case "$choice" in
			"") return 0 ;;
			q) exit 0 ;;
			a) ENABLED="$ALL_MODULES" ;;
			n) ENABLED="" ;;
			d) (DRY_RUN=1 run_install) || true ;;
			*)
				if [[ "$choice" =~ ^[0-9]+$ ]] && m="$(nth_module "$choice")"; then
					toggle "$m"
				else
					say "unrecognized: $choice"
				fi
				;;
		esac
	done
}

# --- main ---

run_install() {
	local m
	resolve_deps
	[ -n "$ENABLED" ] || die "nothing selected"
	echo
	[ "$DRY_RUN" = 1 ] && say "${C_BOLD}DRY RUN${C_RESET} — nothing will be modified"
	say "installing (mode: $MODE):"
	for m in $ALL_MODULES; do
		enabled "$m" || continue
		say "${C_BOLD}[$m]${C_RESET}"
		"install_$(printf "%s" "$m" | tr '-' '_')"
	done
	echo
	if [ "$DRY_RUN" = 1 ]; then
		say "dry run complete — $CHANGED pending change(s), $UNCHANGED unchanged"
	else
		say "🎉 done — $CHANGED change(s), $UNCHANGED unchanged"
		[ "$BACKUPS" -gt 0 ] && say "replaced files were backed up to ${BACKUP_DIR/#$HOME/~}"
		mkdir -p "$STATE_DIR"
		printf "%s\n" "$PROFILE" >"$STATE_DIR/profile"
	fi
	return 0
}

list_modules() {
	local m mark
	say "profile: $PROFILE (mode: $MODE)"
	for m in $ALL_MODULES; do
		mark=" "
		enabled "$m" && mark="x"
		printf "  [%s] %-14s %s\n" "$mark" "$m" "$(module_desc "$m")"
	done
}

# Print the header comment block (everything from line 2 to the first
# non-comment line), so help text can't drift out of sync with line numbers.
usage() {
	awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
}

main() {
	local cmd=install render_target="" opt_profile="" opt_mode="" only="" skip="" m

	if [ "${1:-}" = render ]; then
		cmd=render
		render_target="${2:-}"
		shift 2 2>/dev/null || die "usage: ./install.sh render opencode [--profile NAME]"
	fi

	while [ $# -gt 0 ]; do
		case "$1" in
			--profile) opt_profile="${2:-}"; shift 2 || die "--profile needs a value" ;;
			--only) only="${2:-}"; shift 2 || die "--only needs a value" ;;
			--skip) skip="${2:-}"; shift 2 || die "--skip needs a value" ;;
			--yes | -y) ASSUME_YES=1; shift ;;
			--dry-run) DRY_RUN=1; shift ;;
			--link) opt_mode=link; shift ;;
			--copy) opt_mode=copy; shift ;;
			--list) cmd=list; shift ;;
			-h | --help) usage; exit 0 ;;
			*) die "unknown option: $1 (see --help)" ;;
		esac
	done

	# Profile: flag > last used > personal. Flags override profile defaults.
	if [ -z "$opt_profile" ] && [ -f "$STATE_DIR/profile" ]; then
		opt_profile="$(cat "$STATE_DIR/profile")"
	fi
	apply_profile "${opt_profile:-personal}"
	[ -n "$opt_mode" ] && MODE="$opt_mode"

	if [ -n "$only" ]; then
		ENABLED=""
		for m in ${only//,/ }; do
			valid_module "$m" || die "unknown module: $m (available: $ALL_MODULES)"
			ENABLED="$ENABLED $m"
		done
	fi
	for m in ${skip//,/ }; do
		valid_module "$m" || die "unknown module: $m (available: $ALL_MODULES)"
		enabled "$m" && toggle "$m"
	done

	case "$cmd" in
		render)
			[ "$render_target" = opencode ] || die "only 'render opencode' is supported"
			render_opencode
			;;
		list)
			list_modules
			;;
		install)
			if [ -t 0 ] && [ "$ASSUME_YES" = 0 ] && [ "$DRY_RUN" = 0 ] && [ -z "$only" ] && [ -z "$skip" ]; then
				run_menu
			fi
			run_install
			;;
	esac
}

main "$@"
