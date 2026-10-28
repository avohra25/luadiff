local H = require("harness")
local myers = require("luadiff.myers")
local lines = require("luadiff.lines")
local test, eq = H.test, H.eq

local function chars(s)
  local t = {}
  for c in s:gmatch(".") do t[#t + 1] = c end
  return t
end

-- Rebuild b from a and the opcodes; used to check every result.
local function apply(a, b, ops)
  local out = {}
  for _, op in ipairs(ops) do
    if op[1] == "equal" then
      for k = 1, op[3] - op[2] do
        assert(a[op[2] + k] == b[op[4] + k], "equal opcode covers different items")
        out[#out + 1] = a[op[2] + k]
      end
    else
      for k = op[4] + 1, op[5] do out[#out + 1] = b[k] end
    end
  end
  return out
end

test("identical sequences give one equal opcode", function()
  eq(myers.opcodes(chars("abc"), chars("abc")), { { "equal", 0, 3, 0, 3 } })
end)

test("empty inputs", function()
  eq(myers.opcodes({}, {}), {})
  eq(myers.opcodes({}, chars("ab")), { { "insert", 0, 0, 0, 2 } })
  eq(myers.opcodes(chars("ab"), {}), { { "delete", 0, 2, 0, 0 } })
end)

test("disjoint sequences become a single replace", function()
  eq(myers.opcodes(chars("abc"), chars("xyz")), { { "replace", 0, 3, 0, 3 } })
end)

test("classic Myers paper example has distance 5", function()
  local a, b = chars("ABCABBA"), chars("CBABAC")
  local ops = myers.opcodes(a, b)
  eq(myers.distance(ops), 5)
  eq(apply(a, b, ops), b)
end)

test("insertion in the middle", function()
  eq(myers.opcodes(chars("abef"), chars("abcdef")),
    { { "equal", 0, 2, 0, 2 }, { "insert", 2, 2, 2, 4 }, { "equal", 2, 4, 4, 6 } })
end)

test("deletion at both ends", function()
  eq(myers.opcodes(chars("xabcy"), chars("abc")),
    { { "delete", 0, 1, 0, 0 }, { "equal", 1, 4, 0, 3 }, { "delete", 4, 5, 3, 3 } })
end)

test("longer sequences reconstruct correctly", function()
  local a = chars("the quick brown fox jumps over the lazy dog")
  local b = chars("a quick brown cat leaps over two lazy dogs")
  eq(apply(a, b, myers.opcodes(a, b)), b)
end)

test("line diff marks a final line whose newline changed", function()
  local ops = lines.diff({ "a", "b" }, { "a", "b" }, nil, true, false)
  eq(ops, { { "equal", 0, 1, 0, 1 }, { "replace", 1, 2, 1, 2 } })
end)

test("ignore_all_space and ignore_case options", function()
  eq(lines.diff({ "a b", "C" }, { "ab", "c" }, { ignore_all_space = true, ignore_case = true }),
    { { "equal", 0, 2, 0, 2 } })
  eq(lines.diff({ "  x   y " }, { "x y" }, { ignore_space_change = true }), { { "equal", 0, 1, 0, 1 } })
  eq(lines.diff({ "x y" }, { "xy" }, { ignore_space_change = true }), { { "replace", 0, 1, 0, 1 } })
end)
