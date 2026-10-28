--- Formatting and parsing of unified diffs (the `diff -u` / git format).
local lines_mod = require("luadiff.lines")
local text = require("luadiff.text")

local M = {}

local NO_EOL = "\\ No newline at end of file"

--- Group opcodes into hunks with `n` lines of context, like difflib's
-- get_grouped_opcodes. Returns a list of opcode lists.
function M.group(ops, n)
  n = n or 3
  if #ops == 0 then return {} end
  local codes = {}
  for i, op in ipairs(ops) do codes[i] = { op[1], op[2], op[3], op[4], op[5] } end
  if #codes == 1 and codes[1][1] == "equal" then return {} end
  -- trim leading and trailing context
  local first = codes[1]
  if first[1] == "equal" then
    first[2] = math.max(first[2], first[3] - n)
    first[4] = math.max(first[4], first[5] - n)
  end
  local last = codes[#codes]
  if last[1] == "equal" then
    last[3] = math.min(last[3], last[2] + n)
    last[5] = math.min(last[5], last[4] + n)
  end
  local groups, cur = {}, {}
  for _, c in ipairs(codes) do
    local tag, i1, i2, j1, j2 = c[1], c[2], c[3], c[4], c[5]
    if tag == "equal" and i2 - i1 > 2 * n then
      cur[#cur + 1] = { tag, i1, math.min(i2, i1 + n), j1, math.min(j2, j1 + n) }
      groups[#groups + 1] = cur
      cur = {}
      i1, j1 = math.max(i1, i2 - n), math.max(j1, j2 - n)
    end
    cur[#cur + 1] = { tag, i1, i2, j1, j2 }
  end
  if #cur > 0 and not (#cur == 1 and cur[1][1] == "equal") then groups[#groups + 1] = cur end
  return groups
end

local function range(start, stop)
  local len = stop - start
  local begin = start + 1
  if len == 1 then return tostring(begin) end
  if len == 0 then begin = begin - 1 end
  return begin .. "," .. len
end

--- Format a unified diff between two strings. Options: `context`
-- (default 3), `from_file`/`to_file` header names, and the line diff
-- options accepted by luadiff.lines (ignore_case, ...). Returns "" when
-- the inputs are equal.
function M.diff(old, new, opts)
  opts = opts or {}
  local ops, a, b = lines_mod.diff_text(old, new, opts)
  local groups = M.group(ops, opts.context or 3)
  if #groups == 0 then return "" end
  local out = {
    "--- " .. (opts.from_file or "a"),
    "+++ " .. (opts.to_file or "b"),
  }
  local na, nb = #a.lines, #b.lines
  local function emit(prefix, line, idx, side)
    out[#out + 1] = prefix .. line
    if idx == (side == a and na or nb) and side.eol == false then out[#out + 1] = NO_EOL end
  end
  for _, g in ipairs(groups) do
    local f, l = g[1], g[#g]
    out[#out + 1] = string.format("@@ -%s +%s @@", range(f[2], l[3]), range(f[4], l[5]))
    for _, op in ipairs(g) do
      local tag, i1, i2, j1, j2 = op[1], op[2], op[3], op[4], op[5]
      if tag == "equal" then
        for i = i1 + 1, i2 do
          -- context is printed from the new side; both sides are equal
          -- here, including their final-newline status
          emit(" ", a.lines[i], i, a)
        end
      else
        for i = i1 + 1, i2 do emit("-", a.lines[i], i, a) end
        for j = j1 + 1, j2 do emit("+", b.lines[j], j, b) end
      end
    end
  end
  return text.join(out, true)
end

local function parse_range(s)
  local start, len = s:match("^(%d+),(%d+)$")
  if start then return tonumber(start), tonumber(len) end
  return tonumber(s), 1
end

-- A "\ No newline at end of file" marker applies to the line before it.
local function mark_no_eol(h)
  local last = h.lines[#h.lines]
  if not last then error("no-newline marker before any hunk line", 0) end
  if last[1] ~= "+" then h.a_eol = false end
  if last[1] ~= "-" then h.b_eol = false end
end

--- Parse a unified diff (possibly covering several files, possibly with
-- git headers or commentary between them). Returns a list of file
-- patches: `{from = name, to = name, hunks = {...}}`, where each hunk is
-- `{a_start, a_len, b_start, b_len, lines = {{op, text}...}, a_eol, b_eol}`
-- with `op` one of " ", "-", "+". Raises on malformed hunks.
function M.parse(patch)
  local src = text.split(patch)
  local files = {}
  local i = 1
  local current
  while i <= #src do
    local line = src[i]
    local from = line:match("^%-%-%- (.*)$")
    if from and src[i + 1] and src[i + 1]:match("^%+%+%+ ") then
      current = {
        from = (from:gsub("\t.*$", "")),
        to = (src[i + 1]:sub(5):gsub("\t.*$", "")),
        hunks = {},
      }
      files[#files + 1] = current
      i = i + 2
    elseif line:match("^@@ ") then
      local ar, br = line:match("^@@ %-([%d,]+) %+([%d,]+) @@")
      if not ar then error(string.format("line %d: malformed hunk header: %s", i, line), 0) end
      if not current then
        current = { hunks = {} }
        files[#files + 1] = current
      end
      local h = { lines = {}, a_eol = true, b_eol = true }
      h.a_start, h.a_len = parse_range(ar)
      h.b_start, h.b_len = parse_range(br)
      local need_a, need_b = h.a_len, h.b_len
      i = i + 1
      while need_a > 0 or need_b > 0 do
        local l = src[i]
        if l == nil then error(string.format("line %d: hunk ends early", i), 0) end
        local op, body = l:sub(1, 1), l:sub(2)
        if l == "" then op, body = " ", "" end -- some tools strip the space on blank context
        if op == " " then
          need_a, need_b = need_a - 1, need_b - 1
        elseif op == "-" then
          need_a = need_a - 1
        elseif op == "+" then
          need_b = need_b - 1
        elseif op == "\\" then
          mark_no_eol(h)
          op = nil
        else
          error(string.format("line %d: unexpected line in hunk: %s", i, l), 0)
        end
        if need_a < 0 or need_b < 0 then
          error(string.format("line %d: hunk is longer than its header says", i), 0)
        end
        if op then h.lines[#h.lines + 1] = { op, body } end
        i = i + 1
      end
      -- an optional "\ No newline" marker may follow the last line
      if src[i] and src[i]:sub(1, 1) == "\\" then
        mark_no_eol(h)
        i = i + 1
      end
      current.hunks[#current.hunks + 1] = h
    else
      i = i + 1
    end
  end
  return files
end

return M
