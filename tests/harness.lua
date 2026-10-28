--- A tiny dependency-free test harness: `test(name, fn)` plus assertions.
local H = { passed = 0, failed = 0, failures = {} }

local function serialize(v, seen)
  seen = seen or {}
  if type(v) == "string" then return string.format("%q", v) end
  if type(v) ~= "table" then return tostring(v) end
  if seen[v] then return "<cycle>" end
  seen[v] = true
  local parts, n = {}, #v
  for i = 1, n do parts[#parts + 1] = serialize(v[i], seen) end
  local keys = {}
  for k in pairs(v) do
    if not (math.type(k) == "integer" and k >= 1 and k <= n) then keys[#keys + 1] = k end
  end
  table.sort(keys, function(x, y) return tostring(x) < tostring(y) end)
  for _, k in ipairs(keys) do parts[#parts + 1] = tostring(k) .. "=" .. serialize(v[k], seen) end
  seen[v] = nil
  return "{" .. table.concat(parts, ", ") .. "}"
end
H.serialize = serialize

local function deep_eq(x, y)
  if x == y then return true end
  if type(x) ~= "table" or type(y) ~= "table" then return false end
  for k, v in pairs(x) do if not deep_eq(v, y[k]) then return false end end
  for k in pairs(y) do if x[k] == nil then return false end end
  return true
end
H.deep_eq = deep_eq

function H.eq(actual, expected, msg)
  if not deep_eq(actual, expected) then
    error(string.format("%sexpected %s\n     got %s", msg and (msg .. ": ") or "",
      serialize(expected), serialize(actual)), 2)
  end
end

function H.truthy(v, msg)
  if not v then error(msg or "expected a truthy value", 2) end
end

function H.raises(fn, pattern)
  local ok, err = pcall(fn)
  if ok then error("expected an error", 2) end
  if pattern and not tostring(err):find(pattern) then
    error("error " .. tostring(err) .. " does not match " .. pattern, 2)
  end
end

function H.test(name, fn)
  local ok, err = xpcall(fn, debug.traceback)
  if ok then
    H.passed = H.passed + 1
  else
    H.failed = H.failed + 1
    H.failures[#H.failures + 1] = name .. "\n  " .. tostring(err)
  end
end

return H
