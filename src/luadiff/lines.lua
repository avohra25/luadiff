--- Line-level diffing: interns lines to small integers (optionally
-- normalising whitespace or case first) and runs Myers on the result.
local myers = require("luadiff.myers")
local text = require("luadiff.text")

local M = {}

local function make_key(opts)
  opts = opts or {}
  if opts.key then return opts.key end
  local fns = {}
  if opts.ignore_all_space then
    fns[#fns + 1] = function(s) return (s:gsub("%s+", "")) end
  elseif opts.ignore_space_change then
    fns[#fns + 1] = function(s) return (s:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")) end
  end
  if opts.ignore_case then fns[#fns + 1] = string.lower end
  if #fns == 0 then return nil end
  return function(s)
    for _, f in ipairs(fns) do s = f(s) end
    return s
  end
end

--- Diff two arrays of lines. `a_eol` / `b_eol` say whether each file
-- ends with a newline; a final line that differs only in its newline
-- is reported as changed, like GNU diff does.
function M.diff(a, b, opts, a_eol, b_eol)
  local key = make_key(opts)
  local ids, next_id = {}, 0
  local function intern(lines, eol)
    local out = {}
    for i, line in ipairs(lines) do
      local k = key and key(line) or line
      if i == #lines and eol == false then k = k .. "\0<no-eol>" end
      local id = ids[k]
      if not id then next_id = next_id + 1; id = next_id; ids[k] = id end
      out[i] = id
    end
    return out
  end
  return myers.opcodes(intern(a, a_eol), intern(b, b_eol))
end

--- Diff two strings line by line. Returns the opcodes and the split
-- lines/eol flags of both sides for further formatting.
function M.diff_text(old, new, opts)
  local a, a_eol = text.split(old)
  local b, b_eol = text.split(new)
  return M.diff(a, b, opts, a_eol, b_eol), { lines = a, eol = a_eol }, { lines = b, eol = b_eol }
end

return M
