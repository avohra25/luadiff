--- luadiff: Myers diff, unified patches and three-way merge in pure Lua.
local M = {
  _VERSION = "0.1.0",
  myers = require("luadiff.myers"),
  text = require("luadiff.text"),
  lines = require("luadiff.lines"),
  unified = require("luadiff.unified"),
  patch = require("luadiff.patch"),
}

--- Diff any two arrays of comparable values (characters, tokens...).
M.diff_sequences = M.myers.opcodes

--- Diff two strings line by line; returns difflib-style opcodes.
function M.diff_lines(old, new, opts)
  return (M.lines.diff_text(old, new, opts))
end

--- Unified diff text between two strings ("" when equal).
M.unified_diff = M.unified.diff

--- Parse unified diff text into file patches.
M.parse_patch = M.unified.parse

--- Apply unified diff text to a string.
M.apply_patch = M.patch.apply

return M
