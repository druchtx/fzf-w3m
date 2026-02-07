#!/usr/bin/env bash
set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

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

open_mode="tmux"
target=""
mode="${TMUX_W3M_MODE:-pane}"
split="${TMUX_W3M_SPLIT:-$(get_tmux_option "@fzf_w3m_split" "h")}"
browser="${TMUX_W3M_BOOKMARKS:-$(get_tmux_option "@fzf_w3m_bookmarks" "auto")}"
prompt="${TMUX_W3M_PROMPT:-$(get_tmux_option "@fzf_w3m_prompt" "search> ")}"
preview_width="${TMUX_W3M_PREVIEW_WIDTH:-$(get_tmux_option "@fzf_w3m_preview_width" "60%")}"
fzf_opts_str="${TMUX_W3M_FZF_OPTS:-$(get_tmux_option "@fzf_w3m_fzf_opts" "")}" 

fallback=""

w3m_opts=()
if [[ -n "${TMUX_W3M_OPTS:-}" ]]; then
  read -r -a w3m_opts <<< "$TMUX_W3M_OPTS"
else
  w3m_opts=(-o accept_encoding=identity -o auto_uncompress=0)
fi

fzf_opts=()
if [[ -n "$fzf_opts_str" ]]; then
  read -r -a fzf_opts <<< "$fzf_opts_str"
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -w|--window)
      mode="window"
      ;;
    -p|--pane)
      mode="pane"
      ;;
    -t|--target)
      target="${2:-}"
      shift
      ;;
    --self|--inplace)
      open_mode="self"
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
      break
      ;;
  esac
  shift
 done

if [[ $# -gt 0 ]]; then
  fallback="$*"
fi

if [[ -z "${TMUX:-}" ]]; then
  open_mode="self"
fi

script="$SCRIPT_DIR/open-url.sh"

open_url() {
  local url="$1"
  if [[ -z "$url" ]]; then
    return 0
  fi
  if [[ ! "$url" =~ ^https?:// ]]; then
    if [[ "$url" =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}(/.*)?$ ]]; then
      url="https://$url"
    fi
  fi
  if [[ "$open_mode" == "self" ]]; then
    exec w3m "${w3m_opts[@]}" "$url"
  fi
  if [[ "$mode" == "window" ]]; then
    if [[ -n "$target" ]]; then
      "$script" --target "$target" --window "$url"
    else
      "$script" --window "$url"
    fi
  else
    if [[ "$split" == "v" ]]; then
      if [[ -n "$target" ]]; then
        "$script" --target "$target" --pane --vertical "$url"
      else
        "$script" --pane --vertical "$url"
      fi
    else
      if [[ -n "$target" ]]; then
        "$script" --target "$target" --pane --horizontal "$url"
      else
        "$script" --pane --horizontal "$url"
      fi
    fi
  fi
}

if ! command -v fzf >/dev/null 2>&1; then
  if [[ -n "$fallback" ]]; then
    open_url "$fallback"
  else
    echo "fzf not found" >&2
  fi
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  if [[ -n "$fallback" ]]; then
    open_url "$fallback"
  else
    echo "jq not found" >&2
  fi
  exit 0
fi

declare -a sources

add_source() {
  local name="$1"
  local path="$2"
  if [[ -f "$path" ]]; then
    sources+=("${name}:${path}")
  fi
}

add_chromium_sources() {
  local name="$1"
  local base="$2"
  local profile
  add_source "${name}(Default)" "$base/Default/Bookmarks"
  for profile in "$base"/Profile*; do
    if [[ -d "$profile" ]]; then
      add_source "${name}($(basename "$profile"))" "$profile/Bookmarks"
    fi
  done
}

if [[ "$browser" == "auto" ]]; then
  add_chromium_sources "arc" "$HOME/Library/Application Support/Arc/User Data"
  add_chromium_sources "chrome" "$HOME/Library/Application Support/Google/Chrome"
  add_chromium_sources "brave" "$HOME/Library/Application Support/BraveSoftware/Brave-Browser"
  add_chromium_sources "edge" "$HOME/Library/Application Support/Microsoft Edge"
  add_source "safari" "$HOME/Library/Safari/Bookmarks.plist"
else
  case "$browser" in
    arc)
      add_chromium_sources "arc" "$HOME/Library/Application Support/Arc/User Data"
      ;;
    chrome)
      add_chromium_sources "chrome" "$HOME/Library/Application Support/Google/Chrome"
      ;;
    brave)
      add_chromium_sources "brave" "$HOME/Library/Application Support/BraveSoftware/Brave-Browser"
      ;;
    edge)
      add_chromium_sources "edge" "$HOME/Library/Application Support/Microsoft Edge"
      ;;
    safari)
      add_source "safari" "$HOME/Library/Safari/Bookmarks.plist"
      ;;
  esac
fi

if [[ ${#sources[@]} -eq 0 ]]; then
  if [[ -n "$fallback" ]]; then
    open_url "$fallback"
  else
    echo "no bookmark files found" >&2
  fi
  exit 0
fi

parse_chromium() {
  local name="$1"
  local file="$2"
  if ! jq -r --arg source "$name" '
    def host($u):
      ($u | sub("^https?://";"") | sub("/.*$";""));
    .. | objects | select(.type? == "url") |
    (.url // "") as $u |
    (.name // "") as $n |
    ($n | length > 0) as $has_name |
    ($u | length > 0) as $has_url |
    (if $has_name then $n else (if $has_url then host($u) else "" end) end) as $display |
    [$display, $u, $source] | @tsv
  ' "$file" 2>/dev/null; then
    echo "skip $name bookmarks (permission or parse error)" >&2
    return 0
  fi
}

parse_safari() {
  local name="$1"
  local file="$2"
  if ! python3 - "$name" "$file" <<'PY' 2>/dev/null; then
import plistlib, sys
source = sys.argv[1]
path = sys.argv[2]
with open(path, "rb") as f:
    data = plistlib.load(f)

def walk(node):
    if isinstance(node, dict):
        url = node.get("URLString")
        if url:
            title = node.get("Title") or ""
            if not title:
                uri = node.get("URIDictionary") or {}
                title = uri.get("title") or ""
            if not title:
                from urllib.parse import urlparse
                host = urlparse(url).netloc
                title = host or url
            print(f"{title}\t{url}\t{source}")
        for v in node.values():
            walk(v)
    elif isinstance(node, list):
        for v in node:
            walk(v)

walk(data)
PY
    echo "skip $name bookmarks (permission or parse error)" >&2
    return 0
  fi
}

items="$(
  for entry in "${sources[@]}"; do
    name="${entry%%:*}"
    file="${entry#*:}"
    if [[ "$name" == "safari" ]]; then
      parse_safari "$name" "$file"
    else
      parse_chromium "$name" "$file"
    fi
  done
)"

fzf_cmd=(
  fzf
  --prompt="$prompt"
  --delimiter=$'\t'
  --with-nth=1
  --nth=1,2
  --preview 'printf "URL: %s\nSource: %s\n" {2} {3}'
  --preview-window="right,${preview_width},wrap,border-left"
  --print-query
)

if [[ -z "$items" ]]; then
  fzf_cmd+=(--header "No bookmarks found. Type URL and press Enter")
fi
if [[ -n "$fzf_opts_str" ]]; then
  fzf_cmd+=("${fzf_opts[@]}")
fi

if [[ -n "$fallback" ]]; then
  fzf_cmd+=(--query "$fallback")
fi

selection="$(
  if [[ -n "$items" ]]; then
    printf '%s\n' "$items" | FZF_DEFAULT_OPTS="" "${fzf_cmd[@]}"
  else
    FZF_DEFAULT_OPTS="" "${fzf_cmd[@]}" < /dev/null
  fi
)" || true

query="$(printf '%s\n' "$selection" | sed -n '1p')"
picked="$(printf '%s\n' "$selection" | sed -n '2p')"

if [[ -n "$picked" ]]; then
  url="$(printf '%s' "$picked" | awk -F'\t' '{print $2}')"
else
  url="$query"
fi

if [[ -z "$url" ]]; then
  exit 0
fi

open_url "$url"
