#!/usr/bin/env bash
# Claude Code statusline: cwd · git branch · model · ctx bar · 5h/7d rate limits

GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
CYAN='\033[1;36m'
RESET='\033[0m'

color_for_pct() {
  local pct=$1
  if [ "$pct" -ge 80 ]; then printf '%s' "$RED"
  elif [ "$pct" -ge 50 ]; then printf '%s' "$YELLOW"
  else printf '%s' "$GREEN"
  fi
}

payload=$(cat)

raw_cwd=$(printf '%s' "$payload" | jq -r '.workspace.current_dir // .cwd // empty')
model=$(printf '%s' "$payload" | jq -r '.model.display_name // empty')
ctx_pct=$(printf '%s' "$payload" | jq -r '.context_window.used_percentage // empty')
lim5h=$(printf '%s' "$payload" | jq -r '.rate_limits.five_hour.used_percentage // empty')
lim7d=$(printf '%s' "$payload" | jq -r '.rate_limits.seven_day.used_percentage // empty')

parts=()

# cwd: replace $HOME with ~, keep last 3 path segments
if [ -n "$raw_cwd" ]; then
  cwd="${raw_cwd/#$HOME/~}"
  IFS='/' read -ra path_segs <<< "$cwd"
  n=${#path_segs[@]}
  if [ "$n" -le 3 ]; then
    short_cwd="$cwd"
  else
    short_cwd="${path_segs[$((n-3))]}/${path_segs[$((n-2))]}/${path_segs[$((n-1))]}"
    [[ "$cwd" == "/"* ]] && short_cwd="/$short_cwd"
  fi
  parts+=("$short_cwd")
fi

# git branch (silent if not a repo)
if [ -n "$raw_cwd" ]; then
  branch=$(git -C "$raw_cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
  [ -n "$branch" ] && parts+=(" $branch")
fi

# model
if [ -n "$model" ]; then
  parts+=("${CYAN}🤖 ${model}${RESET}")
fi

# context window bar
if [ -n "$ctx_pct" ]; then
  pct_int=$(printf '%.0f' "$ctx_pct" 2>/dev/null || printf '%s' "$ctx_pct" | cut -d. -f1)
  [ -z "$pct_int" ] && pct_int=0
  filled=$(( pct_int / 10 ))
  [ "$filled" -gt 10 ] && filled=10
  empty=$(( 10 - filled ))
  bar=""
  for ((i=0; i<filled; i++)); do bar="${bar}█"; done
  for ((i=0; i<empty; i++)); do bar="${bar}░"; done
  col=$(color_for_pct "$pct_int")
  parts+=("${col}ctx ${bar} ${pct_int}%${RESET}")
fi

# 5h rate limit
if [ -n "$lim5h" ]; then
  pct_int=$(printf '%.0f' "$lim5h" 2>/dev/null || printf '%s' "$lim5h" | cut -d. -f1)
  col=$(color_for_pct "$pct_int")
  parts+=("${col}5h ${pct_int}%${RESET}")
fi

# 7d rate limit
if [ -n "$lim7d" ]; then
  pct_int=$(printf '%.0f' "$lim7d" 2>/dev/null || printf '%s' "$lim7d" | cut -d. -f1)
  col=$(color_for_pct "$pct_int")
  parts+=("${col}7d ${pct_int}%${RESET}")
fi

# join with two-space separator
line=""
for part in "${parts[@]}"; do
  if [ -z "$line" ]; then
    line="$part"
  else
    line="${line}  ${part}"
  fi
done

printf '%b\n' "$line"
