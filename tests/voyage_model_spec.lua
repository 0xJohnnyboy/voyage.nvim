local model = require("voyage.model")

local payload = {
  root = {
    id = "root",
    label = "Root",
    path = "/root.md",
    dangling = false,
    children = {
      {
        id = "a",
        label = "Alpha",
        path = "/a.md",
        dangling = false,
        children = {
          { id = "x", label = "Target Child", path = "/x.md", dangling = false, children = {} },
        },
      },
      { id = "b", label = "Beta", path = "/b.md", dangling = false, children = {} },
    },
  },
}

local root = model.from_payload(payload)

local visible = model.visible_nodes(root, "target")
assert(#visible == 3, "expected root + alpha + target")
assert(visible[1].label == "Root", "ancestor root must be visible")
assert(visible[2].label == "Alpha", "ancestor alpha must be visible")
assert(visible[3].label == "Target Child", "target must be visible")

local only_beta = model.visible_nodes(root, "beta")
assert(#only_beta == 2, "expected root + beta only")
assert(only_beta[2].label == "Beta", "sibling filtering failed")
