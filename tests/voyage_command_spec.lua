local command = require("voyage.command")

local called = nil
local api = {
  setup = function() end,
  search_links = function() called = "search_links" end,
  other = function() called = "other" end,
  _private = function() end,
}

local pub = command.public_functions(api)
assert(#pub == 2, "expected other and search_links")
assert(pub[1] == "other" and pub[2] == "search_links", "unexpected function list")

command.dispatch(api, {})
assert(called == "search_links", "default dispatch should call search_links")
