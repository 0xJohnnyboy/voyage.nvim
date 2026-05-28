local cmd = require("voyage.command")

local function VoyageCompletion(lead)
  local valid = cmd.public_functions(require("voyage"))
  local out = {}
  for _, v in ipairs(valid) do
    if v:sub(1, #lead) == lead then
      table.insert(out, v)
    end
  end
  if #out > 0 then
    return out
  end
  return valid
end

vim.api.nvim_create_user_command("Voyage", function(fargs)
  cmd.dispatch(require("voyage"), fargs.fargs)
end, { nargs = "*", complete = VoyageCompletion })
