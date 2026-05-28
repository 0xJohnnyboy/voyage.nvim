local config = require("voyage.config")
local command = require("voyage.command")
local vo = require("voyage.vo")
local model = require("voyage.model")
local ui = require("voyage.ui")

local M = {}

M._config = config.build()

function M.setup(opts)
  M._config = config.build(opts)
end

function M.search_links()
  local target = vim.api.nvim_buf_get_name(0)
  if target == "" then
    vim.notify("Voyage: current buffer has no file", vim.log.levels.ERROR)
    return
  end
  vo.fetch(M._config, target, function(payload, err)
    vim.schedule(function()
      if err then
        vim.notify("Voyage: " .. (err.code or "error") .. " - " .. (err.message or "unknown"), vim.log.levels.ERROR)
        return
      end
      ui.open(M._config, model.from_payload(payload, M._config.depth), function(path, cb)
        vo.fetch(M._config, path, cb, 1)
      end)
    end)
  end)
end

-- Backward-compatible alias
M.new = M.search_links

function M.functions()
  return command.public_functions(M)
end

return M
