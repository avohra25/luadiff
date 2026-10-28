--- Three-way merge (diff3). Both sides are diffed against the common
-- base; changes that overlap or touch in base coordinates form one
-- region, which is taken from whichever side changed it, or becomes a
-- conflict when both sides changed it differently.
local lines_mod = require("luadiff.lines")
local text = require("luadiff.text")

local M = {}

local function slice(t, i1, i2) -- 0-based half-open
  local out = {}
  for k = i1 + 1, i2 do out[#out + 1] = t[k] end
  return out
end

local function same(x, y)
  if #x ~= #y then return false end
  for i = 1, #x do if x[i] ~= y[i] then return false end end
  return true
end

-- Changed regions of `side` relative to `base`, in base coordinates.
local function hunks(base, side, tagname, opts)
  local out = {}
  for _, op in ipairs(lines_mod.diff(base, side, opts)) do
    if op[1] ~= "equal" then
      out[#out + 1] = { side = tagname, o1 = op[2], o2 = op[3], s1 = op[4], s2 = op[5] }
    end
  end
  return out
end

-- Map a base position to a side position when it lies outside the
-- side's changed regions (all of which are listed in `hs`).
local function shift(hs, o)
  local delta = 0
  for _, h in ipairs(hs) do
    if h.o1 < o and h.o2 <= o then
      delta = delta + (h.s2 - h.s1) - (h.o2 - h.o1)
    end
  end
  return o + delta
end

--- Merge arrays of lines. Returns a list of regions, each either
-- `{ok = lines}` or `{conflict = true, a = lines, base = lines, b = lines}`.
function M.regions(base, a, b, opts)
  local ha, hb = hunks(base, a, "a", opts), hunks(base, b, "b", opts)
  local all = {}
  for _, h in ipairs(ha) do all[#all + 1] = h end
  for _, h in ipairs(hb) do all[#all + 1] = h end
  table.sort(all, function(x, y)
    if x.o1 ~= y.o1 then return x.o1 < y.o1 end
    if x.side ~= y.side then return x.side < y.side end
    return x.o2 < y.o2
  end)

  local regions = {}
  local function ok(lines)
    if #lines == 0 then return end
    local last = regions[#regions]
    if last and last.ok then
      for _, l in ipairs(lines) do last.ok[#last.ok + 1] = l end
    else
      regions[#regions + 1] = { ok = lines }
    end
  end

  local o = 0 -- next base line not yet emitted
  local i = 1
  while i <= #all do
    local lo, hi = all[i].o1, all[i].o2
    local group = { all[i] }
    i = i + 1
    while i <= #all and all[i].o1 <= hi do
      group[#group + 1] = all[i]
      if all[i].o2 > hi then hi = all[i].o2 end
      i = i + 1
    end
    ok(slice(base, o, lo))
    -- compute each side's text for base range [lo, hi)
    local text_of = {}
    for _, name in ipairs({ "a", "b" }) do
      local side_lines, side_hunks = (name == "a" and a or b), (name == "a" and ha or hb)
      local s1, s2, o1, o2
      for _, h in ipairs(group) do
        if h.side == name then
          s1 = s1 and math.min(s1, h.s1) or h.s1
          s2 = s2 and math.max(s2, h.s2) or h.s2
          o1 = o1 and math.min(o1, h.o1) or h.o1
          o2 = o2 and math.max(o2, h.o2) or h.o2
        end
      end
      if s1 then
        text_of[name] = slice(side_lines, s1 - (o1 - lo), s2 + (hi - o2))
      else
        local start = shift(side_hunks, lo)
        text_of[name] = slice(side_lines, start, start + (hi - lo))
      end
    end
    local sides = {}
    for _, h in ipairs(group) do sides[h.side] = true end
    if not (sides.a and sides.b) then
      ok(sides.a and text_of.a or text_of.b)
    elseif same(text_of.a, text_of.b) then
      ok(text_of.a)
    else
      regions[#regions + 1] = { conflict = true, a = text_of.a, base = slice(base, lo, hi), b = text_of.b }
    end
    o = hi
  end
  ok(slice(base, o, #base))
  return regions
end

--- Merge three strings. Options:
--   labels  {a = "ours", base = "base", b = "theirs"} for conflict markers
--   style   "merge" (default) or "diff3" (also show the base text)
--   favor   "a" or "b" to resolve every conflict to one side
-- Returns the merged text, the number of conflicts and the regions.
function M.merge(base, a, b, opts)
  opts = opts or {}
  local labels = opts.labels or {}
  local bl, be = text.split(base)
  local al, ae = text.split(a)
  local blines, bbe = text.split(b)
  local regions = M.regions(bl, al, blines, opts)
  local out, conflicts = {}, 0
  local function add(ls) for _, l in ipairs(ls) do out[#out + 1] = l end end
  for _, r in ipairs(regions) do
    if r.ok then
      add(r.ok)
    elseif opts.favor == "a" or opts.favor == "b" then
      add(r[opts.favor])
    else
      conflicts = conflicts + 1
      out[#out + 1] = "<<<<<<< " .. (labels.a or "a")
      add(r.a)
      if opts.style == "diff3" then
        out[#out + 1] = "||||||| " .. (labels.base or "base")
        add(r.base)
      end
      out[#out + 1] = "======="
      add(r.b)
      out[#out + 1] = ">>>>>>> " .. (labels.b or "b")
    end
  end
  -- final newline: keep it if any side changed it, otherwise the base's
  local eol = be
  if ae ~= be then eol = ae elseif bbe ~= be then eol = bbe end
  if conflicts > 0 then eol = true end
  return text.join(out, eol), conflicts, regions
end

return M
