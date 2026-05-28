local M = {}

local function norm(s)
  return string.lower(s or "")
end

local function mk_node(raw, parent, depth, key, max_depth)
  local node = {
    key = key,
    id = raw.id,
    label = raw.label,
    path = raw.path,
    dangling = raw.dangling,
    node_kind = raw.node_kind or "note",
    parent = parent,
    depth = depth,
    expanded = max_depth and (depth < max_depth) or (depth < 1),
    may_have_children = false,
    children_loaded = false,
    children = {},
  }
  for i, c in ipairs(raw.children or {}) do
    local ck = key .. "/" .. i
    table.insert(node.children, mk_node(c, node, depth + 1, ck, max_depth))
  end
  node.children_loaded = #node.children > 0
  node.may_have_children = #node.children > 0 or ((not node.dangling) and max_depth and depth >= max_depth)
  if node.parent == nil and #node.children == 0 and not node.dangling and node.node_kind == "note" then
    -- Fallback for schemas/flows where root is returned without preloaded children.
    node.may_have_children = true
  end
  return node
end

function M.from_payload(payload, max_depth)
  local root = mk_node(payload.root, nil, 0, "0", max_depth)
  root.mode = payload.mode or "links"
  return root
end

local function reindex_subtree(node, parent, depth, key)
  node.parent = parent
  node.depth = depth
  node.key = key
  for i, c in ipairs(node.children) do
    reindex_subtree(c, node, depth + 1, key .. "/" .. i)
  end
end

function M.replace_children(node, payload, max_depth)
  local root = mk_node(payload.root, nil, 0, "tmp", max_depth)
  node.children = {}
  for i, c in ipairs(root.children) do
    reindex_subtree(c, node, node.depth + 1, node.key .. "/" .. i)
    table.insert(node.children, c)
  end
  node.children_loaded = true
  node.may_have_children = #node.children > 0
end

local function include_tree(node, query)
  local q = norm(query)
  local self_match = q == "" or norm(node.label):find(q, 1, true) or norm(node.path):find(q, 1, true)
  local any_child = false
  local map = {}
  for _, c in ipairs(node.children) do
    local ok, sub = include_tree(c, query)
    if ok then
      any_child = true
    end
    for k, v in pairs(sub) do
      map[k] = v
    end
  end
  local keep = self_match or any_child
  if keep then
    map[node.key] = true
  end
  return keep, map
end

function M.filter_map(root, query)
  local _, map = include_tree(root, query or "")
  return map
end

local function flatten(root, filter, query, out)
  if not filter[root.key] then
    return
  end
  table.insert(out, root)
  local force_open = query ~= nil and query ~= ""
  if force_open or root.expanded then
    for _, c in ipairs(root.children) do
      flatten(c, filter, query, out)
    end
  end
end

function M.visible_nodes(root, query)
  local filter = M.filter_map(root, query)
  local out = {}
  flatten(root, filter, query or "", out)
  return out
end

return M
