local M = {}

function M.public_functions(api)
  local out = {}
  for k, v in pairs(api) do
    if type(v) == "function" and k ~= "setup" and k:sub(1, 1) ~= "_" then
      table.insert(out, k)
    end
  end
  table.sort(out)
  return out
end

function M.dispatch(api, args)
  local fn = args[1] or "search_links"
  if type(api[fn]) ~= "function" then
    vim.notify("Voyage: unknown function '" .. fn .. "'", vim.log.levels.ERROR)
    return
  end
  api[fn]()
end

return M
