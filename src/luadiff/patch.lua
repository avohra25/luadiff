--- Applying unified-diff hunks to text, with offset search and fuzz
-- (dropping outer context lines) in the spirit of GNU patch.
local text = require("luadiff.text")
local unified = require("luadiff.unified")

local M = {}

local function reversed(h)
  local r = {
    a_start = h.b_start, a_len = h.b_len, b_start = h.a_start, b_len = h.a_len,
    a_eol = h.b_eol, b_eol = h.a_eol, lines = {},
  }
  local swap = { [" "] = " ", ["-"] = "+", ["+"] = "-" }
  for i, l in ipairs(h.lines) do r.lines[i] = { swap[l[1]], l[2] } end
  return r
end

local function blocks(h)
  local old, new = {}, {}
  for _, l in ipairs(h.lines) do
    if l[1] ~= "+" then old[#old + 1] = l[2] end
    if l[1] ~= "-" then new[#new + 1] = l[2] end
  end
  local lead, trail = 0, 0
  while h.lines[lead + 1] and h.lines[lead + 1][1] == " " do lead = lead + 1 end
  if lead < #h.lines then
    while h.lines[#h.lines - trail][1] == " " do trail = trail + 1 end
  else
    trail = 0
  end
  return old, new, lead, trail
end

local function matches(lines, pos, blk, first, last)
  for k = first, last do
    if lines[pos + k - first] ~= blk[k] then return false end
  end
  return true
end

local function to_file_patch(patch, opts)
  if type(patch) == "string" then
    local files = unified.parse(patch)
    if #files == 0 then return { hunks = {} } end -- empty diff: nothing to do
    if #files ~= 1 and not opts.file then
      error(string.format("patch touches %d files; pass opts.file to pick one", #files), 0)
    end
    if opts.file then
      for _, f in ipairs(files) do
        if f.to == opts.file or f.from == opts.file then return f end
      end
      error("patch does not touch " .. opts.file, 0)
    end
    return files[1]
  end
  if patch.hunks then return patch end
  error("expected a unified diff string or a parsed file patch", 0)
end

--- Apply a patch to `old` (a string). `patch` is unified diff text or a
-- file patch from unified.parse. Options:
--   fuzz    max context lines that may be ignored per hunk end (default 2)
--   reverse undo the patch instead of applying it
--   partial apply the hunks that fit even if others fail
--   file    which file to use from a multi-file patch
-- Returns the new text and a report `{hunks = {...}, failed = n}`. When a
-- hunk fails and `partial` is not set, returns nil, message, report.
function M.apply(old, patch, opts)
  opts = opts or {}
  local maxfuzz = opts.fuzz or 2
  local fp = to_file_patch(patch, opts)
  local lines, eol = text.split(old)
  local out, pos, offset = {}, 1, 0
  local report = { hunks = {}, failed = 0 }
  local final_eol = eol

  for idx, raw in ipairs(fp.hunks) do
    local h = opts.reverse and reversed(raw) or raw
    local oldb, newb, lead, trail = blocks(h)
    local expected = (h.a_len == 0 and h.a_start + 1 or h.a_start) + offset
    local found
    for f = 0, maxfuzz do
      local dl, dt = math.min(f, lead), math.min(f, trail)
      if f > 0 and dl == 0 and dt == 0 then break end -- nothing left to drop
      local first, last = dl + 1, #oldb - dt
      local n = last - first + 1
      local want = expected + dl
      local lo, hi = pos, #lines - n + 1
      local d = 0
      while want - d >= lo or want + d <= hi do
        for _, p in ipairs(d == 0 and { want } or { want - d, want + d }) do
          if p >= lo and p <= hi and matches(lines, p, oldb, first, last) then
            found = { p = p, n = n, f = f, dl = dl, dt = dt, want = want }
            break
          end
        end
        if found then break end
        d = d + 1
      end
      if found then break end
    end
    if found then
      for k = pos, found.p - 1 do out[#out + 1] = lines[k] end
      for k = found.dl + 1, #newb - found.dt do out[#out + 1] = newb[k] end
      pos = found.p + found.n
      offset = offset + (found.p - found.want)
      if pos > #lines then final_eol = h.b_eol end
      report.hunks[idx] = { applied = true, offset = found.p - found.want, fuzz = found.f, line = found.p }
    else
      report.failed = report.failed + 1
      report.hunks[idx] = { applied = false }
    end
  end
  for k = pos, #lines do out[#out + 1] = lines[k] end
  if #out == 0 then final_eol = true end

  if report.failed > 0 and not opts.partial then
    local which = {}
    for i, r in ipairs(report.hunks) do if not r.applied then which[#which + 1] = "#" .. i end end
    return nil, string.format("%d of %d hunks failed (%s)", report.failed, #fp.hunks,
      table.concat(which, ", ")), report
  end
  return text.join(out, final_eol), report
end

return M
