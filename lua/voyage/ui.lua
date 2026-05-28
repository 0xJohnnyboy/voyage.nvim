local model = require("voyage.model")

local M = {}

local ns = vim.api.nvim_create_namespace("voyage")
vim.api.nvim_set_hl(0, "VoyageDangling", { default = true, link = "DiagnosticWarn" })
vim.api.nvim_set_hl(0, "VoyageHasChildren", { default = true, bold = true })
vim.api.nvim_set_hl(0, "VoyageTag", { default = true, link = "Special" })
vim.api.nvim_set_hl(0, "VoyageCategory", { default = true, link = "Type" })

local function make_float(width, height, row, col, enter, border, title)
  local buf = vim.api.nvim_create_buf(false, true)
  local cfg = {
    relative = "editor",
    style = "minimal",
    border = border and "rounded" or "none",
    width = width,
    height = height,
    row = row,
    col = col,
  }
  if title and title ~= "" then
    cfg.title = title
    cfg.title_pos = "left"
  end
  local win = vim.api.nvim_open_win(buf, enter or false, cfg)
  if not border and title and title ~= "" then
    vim.wo[win].winbar = "%#Title#" .. title
  end
  return buf, win
end

local function configure_locked_buffer(buf)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true
end

local function configure_preview_buffer(buf)
  vim.bo[buf].buftype = ""
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true
end

local function set_lines_locked(buf, lines)
  vim.bo[buf].modifiable = true
  vim.bo[buf].readonly = false
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true
end

local function read_preview(path, max_bytes)
  local st = vim.loop.fs_stat(path)
  if not st then
    return nil, "file not found"
  end
  if st.size > max_bytes then
    return nil, "file too large"
  end
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return nil, "cannot read file"
  end
  return lines, nil
end

local function node_matches_query(node, query)
  if not query or query == "" then
    return false
  end
  local q = string.lower(query)
  local label = string.lower(node.label or "")
  local path = string.lower(node.path or "")
  return label:find(q, 1, true) ~= nil or path:find(q, 1, true) ~= nil
end

local function normalize_query(line)
  local q = line or ""
  q = q:gsub("^%s*Search%s*>%s*", "")
  q = q:gsub("^%s*>%s*", "")
  return q
end

local function build_layout(opts)
  local width = math.max(60, math.floor(vim.o.columns * opts.win.width))
  local height = math.max(12, math.floor(vim.o.lines * opts.win.height))
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  local gap = 1
  local border_size = opts.ui.border and 2 or 0
  local frame_sep = gap + border_size
  local query_h = 1
  local query_frame_h = query_h + border_size

  -- horizontal => left/right panes
  if opts.ui.layout == "horizontal" then
    local preview_w = math.floor((width - frame_sep) * opts.win.preview_width)
    local results_w = (width - frame_sep) - preview_w
    -- Left column behaves like: flex-col gap-1 with query fixed and results flex-grow.
    -- We compute in "frame space" (content + 2 border rows) to avoid overlap/ghost gaps.
    local col_frame_h = height + border_size
    local results_frame_h = col_frame_h - query_frame_h - gap
    local results_h = results_frame_h - border_size
    local results_row = row + ((opts.ui.search_position == "top") and (query_frame_h + gap) or 0)
    local query_row = ((opts.ui.search_position == "top") and row) or (row + results_frame_h + gap)
    return {
      query = { width = results_w, height = query_h, row = query_row, col = col },
      results = { width = results_w, height = results_h, row = results_row, col = col },
      preview = { width = preview_w, height = height, row = row, col = col + results_w + frame_sep },
    }
  end

  -- vertical => top/bottom panes
  -- Global column: gap-1 between blocks, query fixed, results fixed, preview grows.
  local col_frame_h = height + border_size
  local body_frame_h = col_frame_h - query_frame_h - gap
  local duo_frame_h = body_frame_h - gap -- preview + results
  local duo_content_h = math.max(6, duo_frame_h - (2 * border_size)) -- remove both borders

  -- results fixed from ratio, preview gets the remaining grow space.
  local results_h = math.max(3, math.floor(duo_content_h * (1 - opts.win.preview_height)))
  local preview_h = math.max(3, duo_content_h - results_h)

  if opts.ui.search_position == "bottom" then
    local preview_row = row
    local results_row = preview_row + (preview_h + border_size) + gap
    local query_row = results_row + (results_h + border_size) + gap
    return {
      query = { width = width, height = query_h, row = query_row, col = col },
      results = { width = width, height = results_h, row = results_row, col = col },
      preview = { width = width, height = preview_h, row = preview_row, col = col },
    }
  end

  local query_row = row
  local preview_row = query_row + query_frame_h + gap
  local results_row = preview_row + (preview_h + border_size) + gap
  return {
    query = { width = width, height = query_h, row = query_row, col = col },
    results = { width = width, height = results_h, row = results_row, col = col },
    preview = { width = width, height = preview_h, row = preview_row, col = col },
  }
end

function M.open(opts, root, load_node_cb)
  local origin_win = vim.api.nvim_get_current_win()
  local geo = build_layout(opts)

  local query_title = opts.ui.border and " Search " or nil
  local query_buf, query_win = make_float(geo.query.width, geo.query.height, geo.query.row, geo.query.col, true, opts.ui.border, query_title)
  local results_buf, results_win = make_float(geo.results.width, geo.results.height, geo.results.row, geo.results.col, false, opts.ui.border, " Results ")
  local preview_buf, preview_win = make_float(geo.preview.width, geo.preview.height, geo.preview.row, geo.preview.col, false, opts.ui.border, " Preview ")

  configure_locked_buffer(results_buf)
  configure_preview_buffer(preview_buf)
  vim.bo[query_buf].buftype = "prompt"
  vim.bo[query_buf].bufhidden = "wipe"
  vim.bo[query_buf].swapfile = false
  vim.bo[query_buf].filetype = "VoyageSearch"
  vim.bo[query_buf].omnifunc = ""
  vim.bo[query_buf].completefunc = ""
  vim.bo[query_buf].tagfunc = ""
  vim.bo[query_buf].keywordprg = ""
  vim.b[query_buf].completion = false
  vim.b[query_buf].blink_cmp_enabled = false

  vim.wo[query_win].number = false
  vim.wo[query_win].relativenumber = false
  vim.wo[query_win].cursorline = false
  vim.wo[results_win].cursorline = false

  vim.fn.prompt_setprompt(query_buf, opts.ui.border and "> " or "Search > ")
  vim.api.nvim_buf_set_lines(query_buf, 0, -1, false, { "" })

  local state = {
    root = root,
    query = "",
    prev_query = "",
    selected = 1,
    visible = {},
    closing = false,
    loading = false,
  }

  local function render_results()
    state.visible = model.visible_nodes(state.root, state.query)
    if #state.visible == 0 then
      set_lines_locked(results_buf, { "(no result)" })
      state.selected = 1
      return
    end

    state.selected = math.max(1, math.min(state.selected, #state.visible))
    local lines = {}
    local meta = {}
    for _, n in ipairs(state.visible) do
      local expandable = (#n.children > 0) or n.may_have_children
      local mark = (n.expanded and "▾ ") or (expandable and "▸ " or "  ")
      local pfx = string.rep("  ", n.depth)
      local kind_prefix = ""
      if n.node_kind == "tag" then
        kind_prefix = (opts.ui.kind_symbols and opts.ui.kind_symbols.tag) or " "
      elseif n.node_kind == "category" then
        kind_prefix = (opts.ui.kind_symbols and opts.ui.kind_symbols.category) or "󰠱 "
      end
      local suffix = n.dangling and "  " or ""
      local rendered = pfx .. mark .. kind_prefix .. n.label .. suffix
      table.insert(lines, rendered)
      table.insert(meta, {
        kind = n.node_kind,
        kind_start = #pfx + #mark,
        kind_end = #pfx + #mark + #kind_prefix,
        has_children = (#n.children > 0) or n.may_have_children,
        dangling = n.dangling,
        line_len = #rendered,
      })
    end
    set_lines_locked(results_buf, lines)

    vim.api.nvim_buf_clear_namespace(results_buf, ns, 0, -1)
    vim.api.nvim_buf_add_highlight(results_buf, ns, "Visual", state.selected - 1, 0, -1)

    for i, m in ipairs(meta) do
      if m.kind == "tag" and m.kind_end > m.kind_start then
        vim.api.nvim_buf_add_highlight(results_buf, ns, "VoyageTag", i - 1, m.kind_start, m.kind_end)
      elseif m.kind == "category" and m.kind_end > m.kind_start then
        vim.api.nvim_buf_add_highlight(results_buf, ns, "VoyageCategory", i - 1, m.kind_start, m.kind_end)
      end
      if m.has_children then
        local end_col = m.line_len - (m.dangling and 4 or 0)
        vim.api.nvim_buf_add_highlight(results_buf, ns, "VoyageHasChildren", i - 1, 0, math.max(0, end_col))
      end
      if m.dangling then
        vim.api.nvim_buf_add_highlight(results_buf, ns, "VoyageDangling", i - 1, math.max(0, m.line_len - 3), -1)
      end
    end
  end

  local function render_preview()
    local n = state.visible[state.selected]
    if not n or n.dangling or not n.path or n.path == "" then
      set_lines_locked(preview_buf, { "No preview" })
      vim.bo[preview_buf].filetype = "text"
      return
    end

    local lines, err = read_preview(n.path, opts.preview.max_bytes)
    if err then
      vim.notify("Voyage preview: " .. err, vim.log.levels.WARN)
      set_lines_locked(preview_buf, { "Preview error: " .. err })
      vim.bo[preview_buf].filetype = "text"
      return
    end

    set_lines_locked(preview_buf, lines)
    local ft = vim.filetype.match({ filename = n.path }) or "text"
    vim.bo[preview_buf].filetype = ft
    pcall(vim.treesitter.start, preview_buf, ft)
  end

  local function refresh()
    local line = vim.api.nvim_buf_get_lines(query_buf, 0, 1, false)[1] or ""
    state.query = normalize_query(line)
    render_results()
    if state.query ~= state.prev_query and state.query ~= "" then
      for i, n in ipairs(state.visible) do
        if node_matches_query(n, state.query) then
          state.selected = i
          break
        end
      end
      render_results()
    end
    state.prev_query = state.query
    render_preview()
  end

  local function focus_query_insert()
    vim.api.nvim_set_current_win(query_win)
    vim.cmd.startinsert()
    local last_col = #(vim.api.nvim_buf_get_lines(query_buf, 0, 1, false)[1] or "")
    vim.api.nvim_win_set_cursor(query_win, { 1, last_col })
  end

  local function focus_results()
    vim.api.nvim_set_current_win(results_win)
  end

  local function focus_preview()
    vim.api.nvim_set_current_win(preview_win)
  end

  local function close_all()
    state.closing = true
    for _, w in ipairs({ query_win, results_win, preview_win }) do
      if vim.api.nvim_win_is_valid(w) then
        vim.api.nvim_win_close(w, true)
      end
    end
    if vim.api.nvim_win_is_valid(origin_win) then
      vim.api.nvim_set_current_win(origin_win)
    end
  end

  local function move(delta)
    if #state.visible == 0 then
      return
    end
    state.selected = math.max(1, math.min(#state.visible, state.selected + delta))
    render_results()
    render_preview()
  end

  local function toggle_expand(expand)
    local n = state.visible[state.selected]
    if not n or (not n.may_have_children and #n.children == 0) then
      return
    end
    if expand and n.may_have_children and #n.children == 0 and n.path and n.path ~= "" and load_node_cb and (not state.loading) then
      state.loading = true
      load_node_cb(n.path, function(payload, err)
        vim.schedule(function()
          state.loading = false
          if err then
            vim.notify("Voyage: " .. (err.message or "failed to expand node"), vim.log.levels.WARN)
            return
          end
          model.replace_children(n, payload, 1)
          n.expanded = true
          refresh()
        end)
      end)
      return
    end
    n.expanded = expand
    refresh()
  end

  local function open_selected()
    local n = state.visible[state.selected]
    if not n or n.dangling or not n.path or n.path == "" then
      vim.notify("Voyage: cannot open dangling node", vim.log.levels.WARN)
      return
    end
    close_all()
    if vim.api.nvim_win_is_valid(origin_win) then
      vim.api.nvim_set_current_win(origin_win)
    end
    vim.cmd.edit(vim.fn.fnameescape(n.path))
  end

  local function query_esc_behavior()
    local q = vim.api.nvim_buf_get_lines(query_buf, 0, 1, false)[1] or ""
    if q == "" then
      close_all()
    else
      focus_results()
    end
  end

  local refresh_scheduled = false
  vim.api.nvim_buf_attach(query_buf, false, {
    on_lines = function()
      if refresh_scheduled then
        return
      end
      refresh_scheduled = true
      vim.schedule(function()
        refresh_scheduled = false
        if vim.api.nvim_buf_is_valid(query_buf) then
          refresh()
        end
      end)
    end,
  })

  local group = vim.api.nvim_create_augroup("VoyageFocusLock" .. tostring(query_win), { clear = true })
  vim.api.nvim_create_autocmd("WinEnter", {
    group = group,
    callback = function()
      if state.closing then
        return
      end
      local w = vim.api.nvim_get_current_win()
      if w ~= query_win and w ~= results_win and w ~= preview_win then
        if vim.api.nvim_win_is_valid(results_win) then
          vim.api.nvim_set_current_win(results_win)
        end
      end
    end,
  })

  local function map(modes, buf, lhs, rhs)
    vim.keymap.set(modes, lhs, rhs, { buffer = buf, silent = true, nowait = true })
  end

  local blocked = { "i", "a", "A", "I", "o", "O", "c", "C", "s", "S", "R" }
  for _, k in ipairs(blocked) do
    map("n", results_buf, k, "<Nop>")
    map("n", preview_buf, k, "<Nop>")
  end

  map("n", results_buf, "j", function() move(1) end)
  map("n", results_buf, "k", function() move(-1) end)
  map("n", results_buf, "h", function() toggle_expand(false) end)
  map("n", results_buf, "l", function() toggle_expand(true) end)
  map("n", results_buf, "<CR>", open_selected)
  map("n", results_buf, "<Tab>", focus_preview)
  map("n", results_buf, "<S-Tab>", focus_query_insert)
  map("n", results_buf, "i", focus_query_insert)
  map("n", results_buf, "/", focus_query_insert)
  map("n", results_buf, "q", close_all)

  map("n", preview_buf, "j", function() vim.cmd("normal! j") end)
  map("n", preview_buf, "k", function() vim.cmd("normal! k") end)
  map("n", preview_buf, "<CR>", open_selected)
  map("n", preview_buf, "<Tab>", focus_query_insert)
  map("n", preview_buf, "<S-Tab>", focus_results)
  map("n", preview_buf, "i", focus_query_insert)
  map("n", preview_buf, "q", close_all)

  map("i", query_buf, "<Esc>", function()
    vim.cmd.stopinsert()
    query_esc_behavior()
  end)
  map("i", query_buf, "<CR>", open_selected)
  map("n", query_buf, "<Esc>", query_esc_behavior)
  map("n", query_buf, "<CR>", open_selected)
  map("n", query_buf, "<Tab>", focus_results)
  map("n", query_buf, "<S-Tab>", focus_preview)
  map("n", query_buf, "q", close_all)

  refresh()
  focus_query_insert()
end

return M
