#!/usr/bin/env bash
# Claude Code status line — inspired by Starship/Ayu Mirage theme
# Reads JSON from stdin and prints a single status line

input=$(cat)

# ── Extract fields from JSON ──────────────────────────────────────────────────
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "?"')
model=$(echo "$input" | jq -r '.model.display_name // "?"')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
total_in=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total_out=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
agent_name=$(echo "$input" | jq -r '.agent.name // empty')
worktree_name=$(echo "$input" | jq -r '.worktree.name // empty')

# ── ANSI colours (Ayu Mirage palette, terminal approximations) ────────────────
reset='\033[0m'
blue='\033[38;5;117m'   # ~#73D0FF
cyan='\033[38;5;122m'   # ~#95E6CB
purple='\033[38;5;183m' # ~#D4BFFF
orange='\033[38;5;215m' # ~#FFA759
green='\033[38;5;150m'  # ~#BAE67E
yellow='\033[38;5;222m' # ~#FFD580
red='\033[38;5;203m'    # ~#FF3333
dimmed='\033[38;5;242m' # ~#5C6773

# ── Directory: shorten home prefix ───────────────────────────────────────────
home="$HOME"
display_dir="${cwd/#$home/~}"

# ── Git info (skip lock to avoid blocking) ───────────────────────────────────
git_part=""
if git_branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" symbolic-ref --short HEAD 2> /dev/null); then
    git_status_flags=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" status --porcelain 2> /dev/null)
    dirty=""
    if [ -n "$git_status_flags" ]; then
        dirty=" ${orange}!${reset}"
    fi
    git_part=" ${dimmed}on${reset} ${purple} ${git_branch}${reset}${dirty}"
fi

# ── Context window ────────────────────────────────────────────────────────────
ctx_part=""
if [ -n "$used_pct" ]; then
    used_int=${used_pct%.*}
    if [ "$used_int" -ge 90 ] 2> /dev/null; then
        ctx_colour="$red"
    elif [ "$used_int" -ge 70 ] 2> /dev/null; then
        ctx_colour="$orange"
    elif [ "$used_int" -ge 50 ] 2> /dev/null; then
        ctx_colour="$yellow"
    else
        ctx_colour="$green"
    fi
    ctx_part=" ${dimmed}ctx${reset} ${ctx_colour}${used_int}%${reset}"
fi

# ── Token usage ──────────────────────────────────────────────────────────────
tokens_part=""
if [ "$total_in" != "0" ] || [ "$total_out" != "0" ]; then
    # Format tokens as "12.3k" for readability
    fmt_tokens() {
        local t=$1
        if [ "$t" -ge 1000000 ] 2> /dev/null; then
            printf "%.1fM" "$(echo "$t / 1000000" | bc -l)"
        elif [ "$t" -ge 1000 ] 2> /dev/null; then
            printf "%.1fk" "$(echo "$t / 1000" | bc -l)"
        else
            printf "%s" "$t"
        fi
    }
    in_fmt=$(fmt_tokens "$total_in")
    out_fmt=$(fmt_tokens "$total_out")
    tokens_part=" ${dimmed}tokens${reset} ${green}↑${in_fmt}${reset} ${cyan}↓${out_fmt}${reset}"
fi

# ── Cost ─────────────────────────────────────────────────────────────────────
cost_part=""
if [ "$cost" != "0" ] && [ -n "$cost" ]; then
    cost_fmt=$(printf "\$%.4f" "$cost")
    cost_part=" ${dimmed}cost${reset} ${yellow}${cost_fmt}${reset}"
fi

# ── Agent name ───────────────────────────────────────────────────────────────
agent_part=""
if [ -n "$agent_name" ]; then
    agent_part=" ${dimmed}agent${reset} ${orange}${agent_name}${reset}"
fi

# ── Worktree name ────────────────────────────────────────────────────────────
worktree_part=""
if [ -n "$worktree_name" ]; then
    worktree_part=" ${dimmed}wt${reset} ${cyan}${worktree_name}${reset}"
fi

# ── Effort level (read from settings, not in statusline JSON) ────────────────
effort_part=""
effort=$(jq -r '.effortLevel // empty' "$HOME/.claude/settings.json" 2> /dev/null)
if [ -n "$effort" ]; then
    effort_part=" ${dimmed}/${reset} ${purple}${effort}${reset}"
fi

# ── Assemble (two lines: path+git, then model+stats) ─────────────────────────
line1="${blue}${display_dir}${reset}${git_part}"
line2="${dimmed}[${reset}${cyan}${model}${reset}${effort_part}${ctx_part}${tokens_part}${cost_part}${agent_part}${worktree_part}${dimmed}]${reset}"
printf '%b\n%b\n' "$line1" "$line2"
