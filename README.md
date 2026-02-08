# fzf-w3m

Browse w3m bookmarks inside tmux with fzf and open in w3m.

## Features
- Fuzzy search by bookmark name or URL
- Title + domain list with URL preview on the right (title width is configurable)
- Picker UI styled with fzf borders/labels (similar to `fzf-pane-switch`)
- Open selected bookmark in a new pane or window
- If there is no match, pressing Enter opens the typed URL or searches DuckDuckGo
- Uses `~/.w3m/bookmark.html`

## Requirements
- tmux
- fzf
- w3m
- python3 (for parsing `bookmark.html`)

## Install (TPM)
GitHub:

```
set -g @plugin 'druchtx/fzf-w3m'
```

Local repo:

```
set -g @plugin '/Users/druchtx/Workspace/projects/fzf-w3m'
```

Then reload tmux and install plugins with `prefix + I`.

## Default key bindings
- `prefix + b` : open picker, then open in split pane
- `prefix + B` : open picker, then open in new window

## Options
```
# Key bindings
set -g @fzf_w3m_pane_key 'b'
set -g @fzf_w3m_window_key 'B'

# Split direction: h or v
set -g @fzf_w3m_split 'h'

# Picker UI: popup or pane
set -g @fzf_w3m_picker 'popup'

# Popup size (when picker = popup)
set -g @fzf_w3m_popup_width '70%'
set -g @fzf_w3m_popup_height '80%'

# w3m bookmarks file
set -g @fzf_w3m_bookmarks_file '~/.w3m/bookmark.html'

# Search engine template (must include %s). Query is URL-encoded.
set -g @fzf_w3m_search_url 'https://duckduckgo.com/?q=%s'

# Prompt text
set -g @fzf_w3m_prompt 'search> '

# Title column width (characters, default 20)
set -g @fzf_w3m_title_width '20'

# Preview width
set -g @fzf_w3m_preview_width '60%'

# Extra fzf options
set -g @fzf_w3m_fzf_opts '--ansi'
```
