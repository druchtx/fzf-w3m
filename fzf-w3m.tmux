#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

get_tmux_option() {
  local option="$1"
  local default="$2"
  local value
  value="$(tmux show-option -gqv "$option")"
  if [[ -n "$value" ]]; then
    printf '%s' "$value"
  else
    printf '%s' "$default"
  fi
}

pane_key="$(get_tmux_option "@fzf_w3m_pane_key" "b")"
window_key="$(get_tmux_option "@fzf_w3m_window_key" "B")"
split="$(get_tmux_option "@fzf_w3m_split" "h")"

open_cmd="$CURRENT_DIR/scripts/open-bookmark.sh --self"

if [[ "$split" == "v" ]]; then
  tmux bind-key "$pane_key" split-window -v -c "#{pane_current_path}" "$open_cmd"
else
  tmux bind-key "$pane_key" split-window -h -c "#{pane_current_path}" "$open_cmd"
fi

tmux bind-key "$window_key" new-window -c "#{pane_current_path}" "$open_cmd"
