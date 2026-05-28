local M = {}

local function decode_or_error(stdout)
  local ok, payload = pcall(vim.json.decode, stdout)
  if not ok then
    return nil, { code = "invalid_json", message = "voyage returned invalid json" }
  end
  if payload.error then
    return nil, payload.error
  end
  if payload.schema_version ~= "1.0.0" then
    return nil, { code = "unsupported_schema", message = "unsupported schema_version: " .. tostring(payload.schema_version) }
  end
  return payload, nil
end

function M.fetch(opts, target, cb, depth)
  local use_depth = depth or opts.depth
  local cmd = {
    opts.vo_bin,
    "--format",
    "json",
    "--tree",
    "--depth",
    tostring(use_depth),
    target,
  }

  vim.system(cmd, { text = true }, function(res)
    if res.code ~= 0 then
      local payload, parse_err = decode_or_error(res.stdout or "")
      if payload then
        cb(nil, payload.error)
        return
      end
      cb(nil, parse_err or { code = "vo_failed", message = vim.trim(res.stderr or "vo failed") })
      return
    end

    local payload, err = decode_or_error(res.stdout or "")
    if err then
      cb(nil, err)
      return
    end
    cb(payload, nil)
  end)
end

return M
