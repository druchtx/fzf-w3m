# fzf-w3m

Browse bookmarks inside tmux with fzf and open in w3m.

## Features
- Fuzzy search by bookmark name or URL
- Name-only list with URL preview on the right
- Open selected bookmark in a new pane or window
- If there is no match, pressing Enter opens the typed URL
- Supports Safari and Chromium-based browsers (Arc, Chrome, Brave, Edge) including profiles

## Requirements
- tmux
- fzf
- w3m
- jq
- python3 (for Safari bookmarks)

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
- `prefix + b` : open in split pane
- `prefix + B` : open in new window

## Options
```
# Key bindings
set -g @fzf_w3m_pane_key 'b'
set -g @fzf_w3m_window_key 'B'

# Split direction: h or v
set -g @fzf_w3m_split 'h'

# Bookmark source: auto|safari|chrome|arc|brave|edge
set -g @fzf_w3m_bookmarks 'auto'

# Prompt text
set -g @fzf_w3m_prompt 'open> '

# Preview width
set -g @fzf_w3m_preview_width '60%'

# Extra fzf options
set -g @fzf_w3m_fzf_opts '--ansi'
```

## Troubleshooting
- Safari bookmarks require Terminal to have Full Disk Access.
