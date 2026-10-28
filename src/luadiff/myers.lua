--- Myers O(ND) difference algorithm, linear-space "middle snake" variant.
--
-- Works on any two arrays whose elements can be compared with `==`
-- (the line-level API interns lines to integers first, so comparisons
-- are cheap). The result is a list of opcodes in the style of Python's
-- difflib: `{tag, i1, i2, j1, j2}` where `tag` is one of "equal",
-- "delete", "insert" or "replace" and the ranges are 0-based half-open,
-- i.e. the opcode covers `a[i1+1 .. i2]` and `b[j1+1 .. j2]`.
local M = {}

local floor = math.floor

-- Append a run of `n` primitive operations ("=", "-", "+") to `runs`,
-- merging with the previous run when it has the same kind.
local function push(runs, kind, n)
  if n <= 0 then return end
  local last = runs[#runs]
  if last and last[1] == kind then
    last[2] = last[2] + n
  else
    runs[#runs + 1] = { kind, n }
  end
end

-- Find the middle snake of a[aLo+1 .. aLo+n] versus b[bLo+1 .. bLo+m] and
-- return the split point (x, y) relative to the sub-ranges. Assumes the
-- ranges have no common prefix or suffix and both are non-empty.
local function bisect(a, aLo, n, b, bLo, m)
  local maxD = floor((n + m + 1) / 2)
  local off = maxD + 1 -- index of diagonal k = 0 in the v arrays (1-based)
  local vlen = 2 * maxD + 2
  local v1, v2 = {}, {}
  for i = 1, vlen do v1[i] = -1; v2[i] = -1 end
  v1[off + 1] = 0
  v2[off + 1] = 0
  local delta = n - m
  local front = (delta % 2) ~= 0
  local k1start, k1end, k2start, k2end = 0, 0, 0, 0

  for d = 0, maxD - 1 do
    -- forward search
    for k1 = -d + k1start, d - k1end, 2 do
      local k1o = off + k1
      local x1
      if k1 == -d or (k1 ~= d and v1[k1o - 1] < v1[k1o + 1]) then
        x1 = v1[k1o + 1]
      else
        x1 = v1[k1o - 1] + 1
      end
      local y1 = x1 - k1
      while x1 < n and y1 < m and a[aLo + x1 + 1] == b[bLo + y1 + 1] do
        x1 = x1 + 1; y1 = y1 + 1
      end
      v1[k1o] = x1
      if x1 > n then
        k1end = k1end + 2
      elseif y1 > m then
        k1start = k1start + 2
      elseif front then
        local k2o = off + delta - k1
        if k2o >= 1 and k2o <= vlen and v2[k2o] ~= -1 then
          if x1 >= n - v2[k2o] then return x1, y1 end
        end
      end
    end
    -- reverse search
    for k2 = -d + k2start, d - k2end, 2 do
      local k2o = off + k2
      local x2
      if k2 == -d or (k2 ~= d and v2[k2o - 1] < v2[k2o + 1]) then
        x2 = v2[k2o + 1]
      else
        x2 = v2[k2o - 1] + 1
      end
      local y2 = x2 - k2
      while x2 < n and y2 < m and a[aLo + n - x2] == b[bLo + m - y2] do
        x2 = x2 + 1; y2 = y2 + 1
      end
      v2[k2o] = x2
      if x2 > n then
        k2end = k2end + 2
      elseif y2 > m then
        k2start = k2start + 2
      elseif not front then
        local k1o = off + delta - k2
        if k1o >= 1 and k1o <= vlen and v1[k1o] ~= -1 then
          local x1 = v1[k1o]
          local y1 = off + x1 - k1o
          if x1 >= n - x2 then return x1, y1 end
        end
      end
    end
  end
  return nil -- no overlap: the ranges share nothing
end

local function diff_range(a, aLo, n, b, bLo, m, runs)
  -- strip common prefix
  local p = 0
  while p < n and p < m and a[aLo + p + 1] == b[bLo + p + 1] do p = p + 1 end
  -- strip common suffix
  local s = 0
  while s < n - p and s < m - p and a[aLo + n - s] == b[bLo + m - s] do s = s + 1 end
  push(runs, "=", p)
  aLo, bLo, n, m = aLo + p, bLo + p, n - p - s, m - p - s
  if n == 0 then
    push(runs, "+", m)
  elseif m == 0 then
    push(runs, "-", n)
  else
    local x, y = bisect(a, aLo, n, b, bLo, m)
    if x == nil then
      push(runs, "-", n); push(runs, "+", m)
    else
      diff_range(a, aLo, x, b, bLo, y, runs)
      diff_range(a, aLo + x, n - x, b, bLo + y, m - y, runs)
    end
  end
  push(runs, "=", s)
end

--- Diff two arrays. Returns a list of opcodes `{tag, i1, i2, j1, j2}`.
-- Adjacent deletions and insertions are combined into one "replace".
function M.opcodes(a, b)
  local runs = {}
  diff_range(a, 0, #a, b, 0, #b, runs)
  local ops = {}
  local i, j = 0, 0
  local k = 1
  while k <= #runs do
    local kind, cnt = runs[k][1], runs[k][2]
    if kind == "=" then
      ops[#ops + 1] = { "equal", i, i + cnt, j, j + cnt }
      i, j = i + cnt, j + cnt
      k = k + 1
    else
      local del, ins = 0, 0
      while k <= #runs and runs[k][1] ~= "=" do
        if runs[k][1] == "-" then del = del + runs[k][2] else ins = ins + runs[k][2] end
        k = k + 1
      end
      local tag = (del > 0 and ins > 0) and "replace" or (del > 0 and "delete" or "insert")
      ops[#ops + 1] = { tag, i, i + del, j, j + ins }
      i, j = i + del, j + ins
    end
  end
  return ops
end

--- Number of deleted plus inserted elements in an opcode list (edit distance).
function M.distance(ops)
  local d = 0
  for _, op in ipairs(ops) do
    if op[1] ~= "equal" then d = d + (op[3] - op[2]) + (op[5] - op[4]) end
  end
  return d
end

return M
