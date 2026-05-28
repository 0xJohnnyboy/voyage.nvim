# Voyage.nvim

Voyage.nvim is a lightweight Neovim plugin to navigate wikilink relations between notes using [`vo`](https://github.com/0xJohnnyboy/voyage).

It opens a popup UI with:
- a search field,
- a relations tree,
- a file preview pane.

## Features

- Tree navigation from Voyage JSON output (`vo --format json --tree`)
- Parent nodes remain visible when a child matches search
- Fold/unfold nodes (`h` / `l`)
- Dangling links highlighted with warning style
- Syntax-highlighted preview
- Configurable layouts:
  - `horizontal` (left/right panes)
  - `vertical` (top/bottom panes)
- Search bar position configurable (`top` or `bottom`)

## Requirements

- Neovim >= 0.10
- [`vo`](https://github.com/0xJohnnyboy/voyage) `v0.1.1+` available in `$PATH`

## Installation

### lazy.nvim

```lua
{
  "0xJohnnyboy/voyage.nvim",
  config = function()
    require("voyage").setup()
  end,
}
```

## Configuration

Default config:

```lua
require("voyage").setup({
  depth = 2,
  vo_bin = "vo",
  ui = {
    layout = "horizontal",    -- "horizontal" (left/right) | "vertical" (top/bottom)
    search_position = "top",  -- "top" | "bottom"
    border = true,            -- true | false
  },
  win = {
    width = 0.9,
    height = 0.8,
    preview_width = 0.5,   -- used in horizontal layout (left/right)
    preview_height = 0.45, -- used in vertical layout (top/bottom)
  },
  preview = {
    max_bytes = 1024 * 1024,
  },
})
```

## Usage

Command interface follows the same style as Scretch:

```vim
:Voyage <function>
```

Without argument, `search_links` is used:

```vim
:Voyage
:Voyage search_links
```

## Interaction

On open:
- focus starts in search input (insert mode),
- typing filters results live.

`<Esc>` in search:
- if search is empty: close popup,
- otherwise: switch to tree navigation mode.

## Default Mappings

Results pane:
- `j` / `k`: move selection
- `h` / `l`: fold/unfold
- `/` or `i`: go back to search input
- `<Tab>` / `<S-Tab>`: cycle focus
- `<CR>`: open selected note
- `q`: close

Preview pane:
- `j` / `k`: scroll
- `i` or `<Tab>`: go to search
- `<CR>`: open selected note
- `q`: close

## Help

```vim
:h voyage
```

## Development

Run unit tests:

```bash
nvim --headless -u NONE -c 'luafile tests/run.lua' -c 'qa!'
```

## License

AGPL-3.0. See the [LICENSE](./LICENSE) file.
