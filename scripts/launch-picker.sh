#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

get_tmux_option() {
  local option="$1"
  local default="$2"
  local value
  value="$(tmux show-option -gqv "$option" 2>/dev/null || true)"
  if [[ -n "$value" ]]; then
    printf '%s' "$value"
  else
    printf '%s' "$default"
  fi
}

debug="$(get_tmux_option "@fzf_w3m_debug" "0")"
debug_log="$(get_tmux_option "@fzf_w3m_debug_log" "/tmp/fzf-w3m.log")"
if [[ "$debug" == "1" ]]; then
  mkdir -p "$(dirname "$debug_log")" 2>/dev/null || true
  exec 3>>"$debug_log"
  exec 2>>"$debug_log"
  printf '\n--- %s ---\n' "$(date '+%F %T')" >&3
  printf 'cmd: %s\n' "$0 $*" >&3
  printf 'TMUX=%s TMUX_PANE=%s\n' "${TMUX:-}" "${TMUX_PANE:-}" >&3
  export PS4='+${BASH_SOURCE}:${LINENO}: '
  export BASH_XTRACEFD=3
  set -x
fi

mode="pane"
cwd=""
target=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --window)
      mode="window"
      ;;
    --pane)
      mode="pane"
      ;;
    --cwd)
      cwd="${2:-}"
      shift
      ;;
    --target)
      target="${2:-}"
      shift
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
  esac
  shift
 done

picker="${TMUX_W3M_PICKER:-$(get_tmux_option "@fzf_w3m_picker" "popup")}"
split="${TMUX_W3M_SPLIT:-$(get_tmux_option "@fzf_w3m_split" "h")}"
popup_w="${TMUX_W3M_POPUP_WIDTH:-$(get_tmux_option "@fzf_w3m_popup_width" "70%")}"
popup_h="${TMUX_W3M_POPUP_HEIGHT:-$(get_tmux_option "@fzf_w3m_popup_height" "80%")}"

open_cmd=("$SCRIPT_DIR/open-bookmark.sh")

if [[ -n "$target" ]]; then
  open_cmd+=(--target "$target")
fi

if [[ "$mode" == "window" ]]; then
  open_cmd+=(--window)
else
  open_cmd+=(--pane)
fi

has_popup=0
if tmux list-commands 2>/dev/null | grep -q '^display-popup'; then
  has_popup=1
fi

if [[ "$picker" == "popup" && $has_popup -eq 1 ]]; then
  if tmux display-popup -E -w "$popup_w" -h "$popup_h" "${open_cmd[@]}"; then
    exit 0
  fi
fi

# Fallback: open picker in a split (so selection can open window if requested)
if [[ "$split" == "v" ]]; then
  tmux split-window -v -c "$cwd" "${open_cmd[@]}" --self
else
  tmux split-window -h -c "$cwd" "${open_cmd[@]}" --self
fi
