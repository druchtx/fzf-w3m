#!/usr/bin/env bash
set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

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

debug="${TMUX_W3M_DEBUG:-$(get_tmux_option "@fzf_w3m_debug" "0")}"
debug_log="${TMUX_W3M_DEBUG_LOG:-$(get_tmux_option "@fzf_w3m_debug_log" "/tmp/fzf-w3m.log")}"
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

open_mode="tmux"
target=""
mode="${TMUX_W3M_MODE:-pane}"
split="${TMUX_W3M_SPLIT:-$(get_tmux_option "@fzf_w3m_split" "h")}"
prompt="${TMUX_W3M_PROMPT:-$(get_tmux_option "@fzf_w3m_prompt" "search> ")}"
preview_width="${TMUX_W3M_PREVIEW_WIDTH:-$(get_tmux_option "@fzf_w3m_preview_width" "60%")}"
fzf_opts_str="${TMUX_W3M_FZF_OPTS:-$(get_tmux_option "@fzf_w3m_fzf_opts" "")}" 
bookmarks_file="${TMUX_W3M_BOOKMARKS_FILE:-$(get_tmux_option "@fzf_w3m_bookmarks_file" "$HOME/.w3m/bookmark.html")}"
search_template="${TMUX_W3M_SEARCH_URL:-$(get_tmux_option "@fzf_w3m_search_url" "https://duckduckgo.com/?q=%s")}"

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

vercomp() {
  local v1="$1"
  local v2="$2"

  IFS='.' read -r -a ver1 <<< "$v1"
  IFS='.' read -r -a ver2 <<< "$v2"

  for i in 0 1 2; do
    local num1="${ver1[i]:-0}"
    local num2="${ver2[i]:-0}"
    if (( num1 > num2 )); then
      return 1
    elif (( num1 < num2 )); then
      return 2
    fi
  done

  return 0
}

get_cols() {
  local cols="${COLUMNS:-}"
  if [[ -z "$cols" ]] && command -v tput >/dev/null 2>&1; then
    cols="$(tput cols 2>/dev/null || true)"
  fi
  if [[ -z "$cols" ]]; then
    cols=80
  fi
  printf '%s' "$cols"
}

expand_tilde() {
  local path="$1"
  case "$path" in
    "~")
      printf '%s' "$HOME"
      ;;
    "~/"*)
      printf '%s' "${path/#\~/$HOME}"
      ;;
    *)
      printf '%s' "$path"
      ;;
  esac
}

looks_like_url() {
  local input="$1"
  if [[ "$input" =~ ^https?:// ]]; then
    return 0
  fi
  if [[ "$input" =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}(/.*)?$ ]]; then
    return 0
  fi
  return 1
}

urlencode() {
  local input="$1"
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$input" <<'PY'
import sys, urllib.parse
print(urllib.parse.quote_plus(sys.argv[1]))
PY
  else
    printf '%s' "$input" | sed 's/ /+/g'
  fi
}

normalize_input() {
  local input="$1"
  input="$(printf '%s' "$input" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  if [[ -z "$input" ]]; then
    return 1
  fi
  if looks_like_url "$input"; then
    if [[ "$input" =~ ^https?:// ]]; then
      printf '%s' "$input"
    else
      printf 'https://%s' "$input"
    fi
  else
    printf "$search_template" "$(urlencode "$input")"
  fi
}

open_url() {
  local input="$1"
  local url
  url="$(normalize_input "$input" || true)"
  if [[ "$debug" == "1" ]]; then
    printf 'open_url input=%s url=%s mode=%s open_mode=%s target=%s\n' "$input" "$url" "$mode" "$open_mode" "$target" >&3
  fi
  if [[ -z "$url" ]]; then
    return 0
  fi
  if [[ "$open_mode" == "self" ]]; then
    exec w3m "${w3m_opts[@]}" "$url"
  fi
  if [[ "$mode" == "window" ]]; then
    if [[ -n "$target" ]]; then
      [[ "$debug" == "1" ]] && printf 'open_url: %s --target %s --window %s\n' "$script" "$target" "$url" >&3
      "$script" --target "$target" --window "$url"
    else
      [[ "$debug" == "1" ]] && printf 'open_url: %s --window %s\n' "$script" "$url" >&3
      "$script" --window "$url"
    fi
  else
    if [[ "$split" == "v" ]]; then
      if [[ -n "$target" ]]; then
        [[ "$debug" == "1" ]] && printf 'open_url: %s --target %s --pane --vertical %s\n' "$script" "$target" "$url" >&3
        "$script" --target "$target" --pane --vertical "$url"
      else
        [[ "$debug" == "1" ]] && printf 'open_url: %s --pane --vertical %s\n' "$script" "$url" >&3
        "$script" --pane --vertical "$url"
      fi
    else
      if [[ -n "$target" ]]; then
        [[ "$debug" == "1" ]] && printf 'open_url: %s --target %s --pane --horizontal %s\n' "$script" "$target" "$url" >&3
        "$script" --target "$target" --pane --horizontal "$url"
      else
        [[ "$debug" == "1" ]] && printf 'open_url: %s --pane --horizontal %s\n' "$script" "$url" >&3
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

title_width="${TMUX_W3M_TITLE_WIDTH:-$(get_tmux_option "@fzf_w3m_title_width" "20")}"
if [[ ! "$title_width" =~ ^[0-9]+$ ]]; then
  title_width=20
fi
if (( title_width < 5 )); then
  title_width=5
fi

build_items() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$file" "$title_width" <<'PY'
import sys
import unicodedata
from html.parser import HTMLParser
from urllib.parse import urlparse

path = sys.argv[1]
try:
    title_width = int(sys.argv[2])
except Exception:
    title_width = 24

def width(s: str) -> int:
    w = 0
    for ch in s:
        w += 2 if unicodedata.east_asian_width(ch) in ("W", "F") else 1
    return w

def pad(s: str, maxw: int) -> str:
    w = width(s)
    if w >= maxw:
        return s
    return s + (" " * (maxw - w))

def truncate(s: str, maxw: int) -> str:
    if maxw <= 0:
        return ""
    if width(s) <= maxw:
        return pad(s, maxw)
    if maxw <= 3:
        return s[:maxw]
    target = maxw - 3
    out = []
    w = 0
    for ch in s:
        cw = 2 if unicodedata.east_asian_width(ch) in ("W", "F") else 1
        if w + cw > target:
            break
        out.append(ch)
        w += cw
    out.append("...")
    return pad("".join(out), maxw)

def host(url: str) -> str:
    try:
        parsed = urlparse(url)
        host = parsed.netloc
        if not host and "://" not in url:
            parsed = urlparse("http://" + url)
            host = parsed.netloc
        return host or url
    except Exception:
        return url

class W3mBookmarks(HTMLParser):
    def __init__(self):
        super().__init__()
        self.in_a = False
        self.href = ""
        self.text = []

    def handle_starttag(self, tag, attrs):
        if tag.lower() == "a":
            for k, v in attrs:
                if k.lower() == "href":
                    self.in_a = True
                    self.href = v or ""
                    self.text = []
                    break

    def handle_data(self, data):
        if self.in_a:
            self.text.append(data)

    def handle_endtag(self, tag):
        if tag.lower() == "a" and self.in_a:
            url = (self.href or "").strip()
            title = "".join(self.text).strip()
            if url:
                domain = host(url)
                display_title = truncate(title or domain, title_width)
                display = f"{display_title} | {domain}"
                print(f"{display}\t{title}\t{url}")
            self.in_a = False
            self.href = ""
            self.text = []

parser = W3mBookmarks()
with open(path, "r", encoding="utf-8", errors="ignore") as f:
    parser.feed(f.read())
PY
  fi
}

items=""
bookmarks_file="$(expand_tilde "$bookmarks_file")"
if [[ -f "$bookmarks_file" ]]; then
  if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 not found; cannot parse $bookmarks_file" >&2
  else
    items="$(build_items "$bookmarks_file" || true)"
  fi
fi

if [[ "$debug" == "1" ]]; then
  {
    printf 'bookmarks_file=%s\n' "$bookmarks_file"
    printf 'items_count=%s\n' "$(printf '%s\n' "$items" | grep -c '.*')"
  } >&3
fi

border_opts=()
fzf_version="$(fzf --version | awk '{print $1}')"
set +e
vercomp '0.58.0' "$fzf_version"
vercmp_rc=$?
set -e
if [[ $vercmp_rc -ne 1 ]]; then
  border_opts+=(--input-border --input-label=" Search " --info=inline-right)
  border_opts+=(--list-border --list-label=" Bookmarks ")
  border_opts+=(--preview-border --preview-label=" Preview ")
fi
set +e
vercomp '0.61.0' "$fzf_version"
vercmp_rc=$?
set -e
if [[ $vercmp_rc -ne 1 ]]; then
  border_opts+=(--ghost "type to search...")
fi

fzf_cmd=(
  fzf
  --prompt="$prompt"
  --delimiter=$'\t'
  --with-nth=1
  --nth=1,2,3
  --preview 'printf "Title: %s\nURL: %s\n" {2} {3}'
  --preview-window="right,${preview_width},nowrap,border-left"
  --print-query
  --reverse
)

if [[ ${#border_opts[@]} -gt 0 ]]; then
  fzf_cmd+=("${border_opts[@]}")
fi
if [[ -z "$items" ]]; then
  fzf_cmd+=(--header "No bookmarks found in $bookmarks_file. Type URL or search and press Enter")
fi
if [[ -n "$fzf_opts_str" ]]; then
  fzf_cmd+=("${fzf_opts[@]}")
fi

if [[ -n "$fallback" ]]; then
  fzf_cmd+=(--query "$fallback")
fi

set +e
selection="$(
  if [[ -n "$items" ]]; then
    printf '%s\n' "$items" | FZF_DEFAULT_OPTS="" "${fzf_cmd[@]}"
  else
    FZF_DEFAULT_OPTS="" "${fzf_cmd[@]}" < /dev/null
  fi
)"
fzf_rc=$?
set -e

if [[ "$debug" == "1" ]]; then
  printf 'fzf_rc=%s\n' "$fzf_rc" >&3
fi

query="$(printf '%s\n' "$selection" | sed -n '1p')"
picked="$(printf '%s\n' "$selection" | sed -n '2p')"

if [[ -n "$picked" ]]; then
  url="$(printf '%s' "$picked" | awk -F'\t' '{print $3}')"
else
  url="$query"
fi

if [[ -z "$url" ]]; then
  exit 0
fi

open_url "$url"
