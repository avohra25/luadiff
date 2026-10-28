local H = require("harness")
local unified = require("luadiff.unified")
local patch = require("luadiff.patch")
local test, eq = H.test, H.eq

local function nums(n, f)
  local t = {}
  for i = 1, n do t[i] = f and f(i) or ("line " .. i) end
  return table.concat(t, "\n") .. "\n"
end

test("apply reproduces the new text", function()
  local old, new = nums(30), nums(30, function(i) return i % 7 == 0 and "changed" or ("line " .. i) end)
  local out, rep = patch.apply(old, unified.diff(old, new))
  eq(out, new)
  eq(rep.failed, 0)
end)

test("reverse undoes a patch", function()
  local old, new = "a\nb\nc\n", "a\nc\nd\n"
  eq(patch.apply(new, unified.diff(old, new), { reverse = true }), old)
end)

test("hunks still apply when the file has shifted", function()
  local old = nums(20)
  local new = nums(20, function(i) return i == 10 and "ten" or ("line " .. i) end)
  local d = unified.diff(old, new)
  local shifted_old = "extra 1\nextra 2\nextra 3\n" .. old
  local out, rep = patch.apply(shifted_old, d)
  eq(out, "extra 1\nextra 2\nextra 3\n" .. new)
  eq(rep.hunks[1].offset, 3)
  eq(rep.hunks[1].fuzz, 0)
end)

test("fuzz ignores changed outer context", function()
  local old = nums(10)
  local new = nums(10, function(i) return i == 5 and "five" or ("line " .. i) end)
  local d = unified.diff(old, new)
  local drifted = nums(10, function(i) return i == 2 and "two (edited)" or ("line " .. i) end)
  local out, rep = patch.apply(drifted, d)
  eq(out, nums(10, function(i)
    if i == 2 then return "two (edited)" elseif i == 5 then return "five" end
    return "line " .. i
  end))
  eq(rep.hunks[1].fuzz, 1)
  local strict = patch.apply(drifted, d, { fuzz = 0 })
  eq(strict, nil)
end)

test("failing hunks are reported, partial mode keeps the rest", function()
  local old = nums(30)
  local new = nums(30, function(i) return (i == 3 or i == 27) and "X" or ("line " .. i) end)
  local d = unified.diff(old, new)
  local broken = nums(30, function(i) return (i >= 1 and i <= 7) and "zzz" or ("line " .. i) end)
  local out, msg, rep = patch.apply(broken, d)
  eq(out, nil)
  eq(msg, "1 of 2 hunks failed (#1)")
  eq(rep.hunks[2].applied, true)
  local part, rep2 = patch.apply(broken, d, { partial = true })
  eq(rep2.failed, 1)
  H.truthy(part:find("\nX\n", 1, true))
end)

test("final newline changes are applied", function()
  eq(patch.apply("a\nb\n", unified.diff("a\nb\n", "a\nb")), "a\nb")
  eq(patch.apply("a\nb", unified.diff("a\nb", "a\nb\n")), "a\nb\n")
  eq(patch.apply("a\nb", unified.diff("a\nb", "a\nc")), "a\nc")
end)

test("insert into and delete everything from a file", function()
  eq(patch.apply("", unified.diff("", "x\ny\n")), "x\ny\n")
  eq(patch.apply("x\ny\n", unified.diff("x\ny\n", "")), "")
end)

test("multi-file patches need a file choice", function()
  local p = "--- a/one\n+++ b/one\n@@ -1 +1 @@\n-x\n+y\n--- a/two\n+++ b/two\n@@ -1 +1 @@\n-p\n+q\n"
  H.raises(function() patch.apply("x\n", p) end, "2 files")
  eq(patch.apply("p\n", p, { file = "b/two" }), "q\n")
end)
