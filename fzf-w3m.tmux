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
picker="$(get_tmux_option "@fzf_w3m_picker" "popup")"
popup_w="$(get_tmux_option "@fzf_w3m_popup_width" "80%")"
popup_h="$(get_tmux_option "@fzf_w3m_popup_height" "60%")"

open_cmd="$CURRENT_DIR/scripts/open-bookmark.sh --target #{pane_id}"

has_popup=0
if tmux list-commands 2>/dev/null | grep -q '^display-popup'; then
  has_popup=1
fi

if [[ "$picker" == "popup" && $has_popup -eq 1 ]]; then
  tmux bind-key "$pane_key" display-popup -E -w "$popup_w" -h "$popup_h" "$open_cmd --pane"
  tmux bind-key "$window_key" display-popup -E -w "$popup_w" -h "$popup_h" "$open_cmd --window"
else
  if [[ "$split" == "v" ]]; then
    tmux bind-key "$pane_key" split-window -v -c "#{pane_current_path}" "$open_cmd --pane --self"
  else
    tmux bind-key "$pane_key" split-window -h -c "#{pane_current_path}" "$open_cmd --pane --self"
  fi

  tmux bind-key "$window_key" new-window -c "#{pane_current_path}" "$open_cmd --window --self"
fi
