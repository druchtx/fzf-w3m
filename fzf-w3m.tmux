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
copy_pane_key="$(get_tmux_option "@fzf_w3m_copy_pane_key" "o")"
copy_window_key="$(get_tmux_option "@fzf_w3m_copy_window_key" "O")"
split="$(get_tmux_option "@fzf_w3m_split" "h")"
picker="$(get_tmux_option "@fzf_w3m_picker" "popup")"
popup_w="$(get_tmux_option "@fzf_w3m_popup_width" "80%")"
popup_h="$(get_tmux_option "@fzf_w3m_popup_height" "60%")"

open_cmd="$CURRENT_DIR/scripts/launch-picker.sh --target '#{pane_id}' --cwd '#{pane_current_path}'"
open_url_cmd="$CURRENT_DIR/scripts/open-url.sh"

tmux bind-key "$pane_key" run-shell "$open_cmd --pane"
tmux bind-key "$window_key" run-shell "$open_cmd --window"

tmux bind-key -T copy-mode-vi "$copy_pane_key" send -X copy-pipe-and-cancel "$open_url_cmd --pane"
tmux bind-key -T copy-mode-vi "$copy_window_key" send -X copy-pipe-and-cancel "$open_url_cmd --window"
