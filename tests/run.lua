package.path = table.concat({
  "./lua/?.lua",
  "./lua/?/init.lua",
  "./tests/?.lua",
  package.path,
}, ";")

_G.vim = _G.vim or {
  notify = function() end,
  log = { levels = { ERROR = 1 } },
}

local tests = {
  "voyage_command_spec",
  "voyage_model_spec",
}

for _, t in ipairs(tests) do
  local ok, err = pcall(require, t)
  if not ok then
    io.stderr:write("FAILED: " .. t .. "\n" .. tostring(err) .. "\n")
    os.exit(1)
  end
end

print("ok")
