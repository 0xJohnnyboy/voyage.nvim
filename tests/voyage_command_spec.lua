local command = require("voyage.command")

local called = nil
local api = {
  setup = function() end,
  search_links = function() called = "search_links" end,
  search_tags = function() called = "search_tags" end,
  search_categories = function() called = "search_categories" end,
  _private = function() end,
}

local pub = command.public_functions(api)
assert(#pub == 3, "expected search_categories/search_links/search_tags")
assert(pub[1] == "search_categories", "unexpected first function")
assert(pub[2] == "search_links", "unexpected second function")
assert(pub[3] == "search_tags", "unexpected third function")

command.dispatch(api, {})
assert(called == "search_links", "default dispatch should call search_links")
