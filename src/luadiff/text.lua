--- Splitting text into lines and joining it back, preserving whether the
-- text ended with a newline.
local M = {}

--- Split `s` into an array of lines (without their "\n"). Returns the
-- lines and a boolean telling whether the final line was terminated.
-- An empty string has no lines and counts as terminated.
function M.split(s)
  local lines = {}
  if s == "" then return lines, true end
  local pos = 1
  while true do
    local nl = s:find("\n", pos, true)
    if not nl then
      lines[#lines + 1] = s:sub(pos)
      return lines, false
    end
    lines[#lines + 1] = s:sub(pos, nl - 1)
    pos = nl + 1
    if pos > #s then return lines, true end
  end
end

--- Join lines with "\n", adding a final newline unless `eol` is false.
function M.join(lines, eol)
  if #lines == 0 then return "" end
  local s = table.concat(lines, "\n")
  if eol ~= false then s = s .. "\n" end
  return s
end

--- Read a whole file, raising a readable error if it cannot be opened.
function M.read_file(path)
  local f, err = io.open(path, "rb")
  if not f then error(err, 0) end
  local data = f:read("a")
  f:close()
  return data
end

return M
