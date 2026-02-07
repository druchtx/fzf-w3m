#!/usr/bin/env bash
set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

mode="pane"
split="h"
args=()

w3m_opts=()
if [[ -n "${TMUX_W3M_OPTS:-}" ]]; then
  read -r -a w3m_opts <<< "$TMUX_W3M_OPTS"
else
  w3m_opts=(-o accept_encoding=identity -o auto_uncompress=0)
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -w|--window)
      mode="window"
      ;;
    -p|--pane)
      mode="pane"
      ;;
    -v|--vertical)
      split="v"
      ;;
    -h|--horizontal)
      split="h"
      ;;
    --)
      shift
      break
      ;;
    *)
      args+=("$1")
      ;;
  esac
  shift
 done

if [[ $# -gt 0 ]]; then
  args+=("$@")
fi

if [[ ${#args[@]} -gt 0 ]]; then
  input="${args[*]}"
else
  input="$(cat)"
fi

input="${input//$'\n'/ }"
url="$(printf '%s' "$input" | perl -ne 'if (m{(https?://[^\s<>"'"'"'\)]+)}) { print $1; exit }')"
if [[ -z "$url" ]]; then
  url="$(printf '%s' "$input" | perl -ne 'if (m{^([A-Za-z0-9.-]+\.[A-Za-z]{2,}(/.*)?)$}) { print "https://$1"; exit }')"
fi

if [[ -z "$url" ]]; then
  exit 0
fi

if [[ -z "${TMUX:-}" ]]; then
  exec w3m "${w3m_opts[@]}" "$url"
fi

cmd_parts=(w3m "${w3m_opts[@]}" "$url")
cmd=""
for part in "${cmd_parts[@]}"; do
  cmd+="${cmd:+ }$(printf %q "$part")"
 done

if [[ "$mode" == "window" ]]; then
  tmux new-window -n "w3m" "$cmd"
else
  if [[ "$split" == "v" ]]; then
    tmux split-window -v "$cmd"
  else
    tmux split-window -h "$cmd"
  fi
fi
